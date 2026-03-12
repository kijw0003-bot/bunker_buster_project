`timescale 1ns / 1ps
`include "define.vh"

module HSV_object_scanner #(
    parameter logic [7:0] P_S_MIN = 8'd200,
    parameter logic [7:0] P_V_MIN = 8'd100,
    parameter logic [7:0] P_H_RED_HI1 = 8'd15,
    parameter logic [7:0] P_H_RED_LO2 = 8'd230,
    parameter logic [7:0] P_H_GRN_LO = 8'd70,
    parameter logic [7:0] P_H_GRN_HI = 8'd130,
    parameter logic [7:0] P_H_BLU_LO = 8'd155,
    parameter logic [7:0] P_H_BLU_HI = 8'd200,
    parameter logic [15:0] P_DETECT_THR = 16'd500,  // 노이즈 최소 임계
    parameter logic [15:0] P_THR_SQ = 16'd1500,  // 삼각형/사각형 경계
    parameter logic [15:0] P_THR_CI = 16'd3000,  // 사각형/원 경계
    parameter logic [2:0] P_RUN_THR = 3'd3,
    parameter logic [28:0] CLK_CNT_3S = 300_000_000
) (
    input  logic       clk,
    input  logic       reset,
    input  logic       DE,
    input  logic [9:0] x_pixel,
    input  logic [9:0] y_pixel,
    input  logic [7:0] H,
    input  logic [7:0] S,
    input  logic [7:0] V,
    output logic [9:0] debug_led,
    output logic [7:0] hint_data,
    output logic       data_done,
    output logic       bunker_detected,
    output logic       frame_done,
    output logic       game_ing
);

    localparam SHAPE_TR = 2'd0;  // 삼각형 (가장 작음)
    localparam SHAPE_SQ = 2'd1;  // 사각형 (중간)
    localparam SHAPE_CI = 2'd2;  // 원     (가장 큼)
    localparam SHAPE_ERR = 2'd3;

    // =========================================================
    // 1단계: HSV 색상 판별
    // =========================================================
    logic is_red, is_grn, is_blu, sat_val_ok;
    always_comb begin
        sat_val_ok = (S >= P_S_MIN) && (V >= P_V_MIN);
        is_red     = sat_val_ok && ((H <= P_H_RED_HI1) || (H >= P_H_RED_LO2));
        is_grn     = sat_val_ok && (H >= P_H_GRN_LO) && (H <= P_H_GRN_HI);
        is_blu     = sat_val_ok && (H >= P_H_BLU_LO) && (H <= P_H_BLU_HI);
    end

    // =========================================================
    // 섹션 번호 계산
    // =========================================================
    logic [3:0] cur_sec;
    logic [2:0] cur_sx, cur_sy;
    always_comb begin
        cur_sx = (x_pixel < 10'd128) ? 3'd0 :
                 (x_pixel < 10'd256) ? 3'd1 :
                 (x_pixel < 10'd384) ? 3'd2 :
                 (x_pixel < 10'd512) ? 3'd3 : 3'd4;
        cur_sy = (y_pixel < 10'd160) ? 3'd0 : (y_pixel < 10'd320) ? 3'd1 : 3'd2;
        cur_sec = {1'b0, cur_sy} * 4'd5 + {1'b0, cur_sx};
    end

    // =========================================================
    // 2단계: Run-length 수평 노이즈 필터
    // =========================================================
    logic [2:0] red_run, grn_run, blu_run;
    logic red_valid, grn_valid, blu_valid;
    logic [9:0] prev_y_run;

    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            red_run <= 0;
            grn_run <= 0;
            blu_run <= 0;
            prev_y_run <= 10'h3FF;
        end else if (DE) begin
            if (y_pixel != prev_y_run) begin
                red_run    <= is_red ? 3'd1 : 3'd0;
                grn_run    <= is_grn ? 3'd1 : 3'd0;
                blu_run    <= is_blu ? 3'd1 : 3'd0;
                prev_y_run <= y_pixel;
            end else begin
                red_run <= is_red ? (red_run < 3'd7 ? red_run + 3'd1 : 3'd7) : 3'd0;
                grn_run <= is_grn ? (grn_run < 3'd7 ? grn_run + 3'd1 : 3'd7) : 3'd0;
                blu_run <= is_blu ? (blu_run < 3'd7 ? blu_run + 3'd1 : 3'd7) : 3'd0;
            end
        end
    end

    assign red_valid = is_red && (red_run >= P_RUN_THR);
    assign grn_valid = is_grn && (grn_run >= P_RUN_THR);
    assign blu_valid = is_blu && (blu_run >= P_RUN_THR);

    // =========================================================
    // 섹션 경계 ±4픽셀 제외 (비트 슬라이싱)
    // x[9:2] = x/4, y[9:2] = y/4
    // =========================================================
    logic is_border;
    assign is_border = (y_pixel[9:2] == 8'd39) || (y_pixel[9:2] == 8'd40) ||  // y=156~163
        (y_pixel[9:2] == 8'd79) || (y_pixel[9:2] == 8'd80) ||  // y=316~323
        (x_pixel[9:2] == 8'd31) || (x_pixel[9:2] == 8'd32) ||  // x=124~131
        (x_pixel[9:2] == 8'd63) || (x_pixel[9:2] == 8'd64) ||  // x=252~259
        (x_pixel[9:2] == 8'd95) || (x_pixel[9:2] == 8'd96) ||  // x=380~387
        (x_pixel[9:2] == 8'd127) || (x_pixel[9:2] == 8'd128);  // x=508~515

    // =========================================================
    // 3단계: 섹션 객체 누적 (cnt만)
    // =========================================================
    logic [15:0] red_cnt[0:14];
    logic [15:0] grn_cnt[0:14];
    logic [15:0] blu_cnt[0:14];
    logic [15:0] max_cnt[0:14];

    logic frame_start, frame_end;
    assign frame_start = DE && (x_pixel == 10'd0) && (y_pixel == 10'd0);
    assign frame_end   = DE && (x_pixel == 10'd639) && (y_pixel == 10'd479);

    integer i;
    always_ff @(posedge clk or posedge reset) begin
        if (reset || frame_start) begin
            for (i = 0; i < 15; i = i + 1) begin
                red_cnt[i] <= 0;
                grn_cnt[i] <= 0;
                blu_cnt[i] <= 0;
            end
        end else if (DE && !is_border) begin
            if (red_valid) red_cnt[cur_sec] <= red_cnt[cur_sec] + 1;
            if (grn_valid) grn_cnt[cur_sec] <= grn_cnt[cur_sec] + 1;
            if (blu_valid) blu_cnt[cur_sec] <= blu_cnt[cur_sec] + 1;
        end
    end


    // =========================================================
    // 4단계: FSM → 섹션별 판정
    // cnt 크기로 도형 판별: 원 > 사각형 > 삼각형
    // =========================================================
    typedef enum {
        ST_IDLE  = 2'd0,
        ST_JUDGE = 2'd1,
        ST_COLOR = 2'd2,
        ST_DONE  = 2'd3
    } state_t;

    state_t                          state;
    logic   [                   3:0] fsm_sec;

    logic   [                   1:0] result_shape          [0:14];
    logic   [                   1:0] result_color          [0:14];
    logic                            result_valid          [0:14];

    logic                            frame_done_flag;
    logic   [$clog2(CLK_CNT_3S)-1:0] red_square_detect_cnt;

    // LED용 combinational 출력
    logic                            any_red_valid;
    logic   [                   3:0] first_red_sec;
    logic   [                   1:0] first_red_shape;


    always_comb begin
        any_red_valid   = 1'b0;
        first_red_sec   = 4'd0;
        first_red_shape = `SHAPE_ERR;
        for (int m = 0; m < 15; m++) begin
            if (result_valid[m] && !any_red_valid) begin
                any_red_valid   = 1'b1;
                first_red_sec   = m[3:0];
                first_red_shape = result_shape[m];
            end
        end
    end

    integer k;
    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            state <= ST_IDLE;
            fsm_sec <= 0;
            hint_data <= 0;
            data_done <= 0;
            bunker_detected <= 0;
            game_ing <= 0;
            for (k = 0; k < 15; k = k + 1) begin
                result_shape[k] <= `SHAPE_ERR;
                result_valid[k] <= 1'b0;
            end
        end else begin
            data_done <= 0;
            bunker_detected <= 0;
            frame_done_flag <= 0;
            case (state)

                ST_IDLE: begin
                    if (frame_end) begin
                        fsm_sec <= 0;
                        state   <= ST_COLOR;
                    end
                end

                ST_COLOR: begin

                    if (red_cnt[fsm_sec] >= grn_cnt[fsm_sec] && 
                            red_cnt[fsm_sec] >= blu_cnt[fsm_sec]) begin
                        max_cnt[fsm_sec] <= red_cnt[fsm_sec];
                        result_color[fsm_sec] <= `RED;
                    end else if (grn_cnt[fsm_sec] >= blu_cnt[fsm_sec]) begin
                        max_cnt[fsm_sec] <= grn_cnt[fsm_sec];
                        result_color[fsm_sec] <= `GREEN;
                    end else begin
                        max_cnt[fsm_sec] <= blu_cnt[fsm_sec];
                        result_color[fsm_sec] <= `BLUE;
                    end

                    state <= ST_JUDGE;
                end

                ST_JUDGE: begin

                    if (max_cnt[fsm_sec] >= P_DETECT_THR) begin
                        result_valid[fsm_sec] <= 1'b1;
                        if (max_cnt[fsm_sec] >= P_THR_CI)
                            result_shape[fsm_sec] <= `CIRCLE;
                        else if (max_cnt[fsm_sec] >= P_THR_SQ)
                            result_shape[fsm_sec] <= `SQUARE;
                        else result_shape[fsm_sec] <= `TRIANGLE;
                    end else begin
                        result_valid[fsm_sec] <= 1'b0;
                        result_shape[fsm_sec] <= `SHAPE_ERR;
                    end

                    state <= ST_DONE;
                end

                ST_DONE: begin
                    if (result_valid[fsm_sec]) begin
                        if ((result_shape[fsm_sec] == `SQUARE) && (result_color[fsm_sec] == `RED)) begin
                            if (game_ing) begin
                                bunker_detected <= 1;
                                game_ing <= 0;
                            end else begin
                                if (red_square_detect_cnt == CLK_CNT_3S - 1) begin
                                    game_ing <= 1;
                                    red_square_detect_cnt <= 0;
                                end else begin
                                    red_square_detect_cnt <= red_square_detect_cnt + 1;
                                end
                            end
                        end



                        if (game_ing  /* && camera_start */) begin
                            hint_data <= {
                                result_shape[fsm_sec],
                                result_color[fsm_sec],
                                fsm_sec
                            };
                            data_done <= 1;
                        end
                    end

                    if (fsm_sec == 4'd14) begin
                        state <= ST_IDLE;
                        fsm_sec <= 0;
                        frame_done_flag <= 1;
                    end else begin
                        fsm_sec <= fsm_sec + 1;
                        state   <= ST_COLOR;
                    end
                end

                default: state <= ST_IDLE;
            endcase
        end
    end


    logic [1:0] frame_done_delay;
    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            frame_done_delay <= 0;
            frame_done       <= 0;
        end else begin
            frame_done_delay[0] <= frame_done_flag;
            frame_done_delay[1] <= frame_done_delay[0];
            frame_done          <= frame_done_delay[1];
        end
    end

    // =========================================================
    // LED
    // [0] is_red       현재픽셀 빨강
    // [1] is_grn       현재픽셀 초록
    // [2] is_blu       현재픽셀 파랑
    // [3] RED 감지됨
    // [4] 섹션 bit0   ┐
    // [5] 섹션 bit1   ├ RED 섹션번호 0~14
    // [6] 섹션 bit2   │
    // [7] 섹션 bit3   ┘
    // [8] 모양 bit0   ┐ 00=TR 01=SQ
    // [9] 모양 bit1   ┘ 10=CI 11=ERR
    // =========================================================
    assign debug_led[0] = is_red;
    assign debug_led[1] = is_grn;
    assign debug_led[2] = is_blu;
    assign debug_led[3] = any_red_valid;
    assign debug_led[4] = first_red_sec[0];
    assign debug_led[5] = first_red_sec[1];
    assign debug_led[6] = first_red_sec[2];
    assign debug_led[7] = first_red_sec[3];
    assign debug_led[8] = first_red_shape[0];
    assign debug_led[9] = first_red_shape[1];

endmodule

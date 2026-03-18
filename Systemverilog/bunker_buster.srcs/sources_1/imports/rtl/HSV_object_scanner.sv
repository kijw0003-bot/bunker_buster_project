`timescale 1ns / 1ps
`include "define.vh"
//++++++++++++++++++++++++++++++
// 디버깅용 코드 
// 합성시 아래 코드 사용
//+++++++++++++++++++++++++++++++
module HSV_object_scanner #(
    parameter logic [7:0] P_S_MIN = 8'd180,
    parameter logic [7:0] P_V_MIN = 8'd70,
    parameter logic [7:0] P_H_RED_HI1 = 8'd15,
    parameter logic [7:0] P_H_RED_LO2 = 8'd235,
    parameter logic [7:0] P_H_GRN_LO = 8'd68,
    parameter logic [7:0] P_H_GRN_HI = 8'd105,
    parameter logic [7:0] P_H_BLU_LO = 8'd148,
    parameter logic [7:0] P_H_BLU_HI = 8'd190,
    parameter logic [15:0] P_DETECT_THR = 16'd900,  // 노이즈 최소 임계
    parameter logic [15:0] P_THR_SQ = 16'd6000,  // 삼각형/사각형 경계
    parameter logic [15:0] P_THR_CI = 16'd15000,  // 사각형/원 경계
    parameter logic [2:0] P_RUN_THR = 3'd6,
    parameter logic [28:0] CLK_CNT_3S = 10_000
) (
    input  logic        clk,
    input  logic        reset,
    input  logic        DE,
    input  logic [ 9:0] x_pixel,
    input  logic [ 9:0] y_pixel,
    input  logic [ 7:0] H,
    input  logic [ 7:0] S,
    input  logic [ 7:0] V,
    input  logic        camera_start,
    input  logic        o_mode_btn,
    output logic        one_red_undetected,
    output logic [15:0] debug_led,
    output logic [ 7:0] hint_data,
    output logic        data_done,
    output logic        bunker_detected,
    output logic        frame_done,
    output logic        game_ing,
    output logic        signal_data
);

    localparam SHAPE_TR = 2'd0;  // 삼각형 (가장 작음)
    localparam SHAPE_SQ = 2'd1;  // 사각형 (중간)
    localparam SHAPE_CI = 2'd2;  // 원     (가장 큼)
    localparam SHAPE_ERR = 2'd3;




    logic [7:0] hint_data_reg;
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

    logic [7:0] sample_H_red, sample_S_red, sample_V_red;
    logic [7:0] sample_H_grn, sample_S_grn, sample_V_grn;
    logic [7:0] sample_H_blu, sample_S_blu, sample_V_blu;

    always_ff @(posedge clk) begin
        if (DE) begin
            if (is_red) begin
                sample_H_red <= H;
                sample_S_red <= S;
                sample_V_red <= V;
            end
            if (is_grn) begin
                sample_H_grn <= H;
                sample_S_grn <= S;
                sample_V_grn <= V;
            end
            if (is_blu) begin
                sample_H_blu <= H;
                sample_S_blu <= S;
                sample_V_blu <= V;
            end
        end
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
        if (reset || o_mode_btn) begin
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
        if (reset || frame_start || o_mode_btn) begin
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
        ST_IDLE,
        WAIT_FRAME_END,
        ST_JUDGE,
        ST_COLOR,
        ST_DONE,
        WAIT_4SEC,

        WAIT_1SEC
    } state_t;

    state_t                          state;
    logic   [                   3:0] fsm_sec;

    logic   [                   3:0] result_color          [0:14];
    logic                            result_valid          [0:14];

    logic                            frame_done_flag;
    logic   [$clog2(CLK_CNT_3S)-1:0] red_square_detect_cnt;
    logic                            red_sqr_detect;
    logic red_detected, red_detected_2;
    logic red_detected_3, red_detected_4;

    integer k;

    localparam CLK_5S = 500_000_000;
    localparam CLK_1_SEC = 100_000_000;
    localparam CLK_4_SEC = 400_000_000;

    logic [$clog2(CLK_5S)-1:0] count_5s;
    logic [$clog2(CLK_4_SEC)-1:0] count_4sec;
    logic [$clog2(CLK_1_SEC)-1:0] count_1sec;
    logic tick_5s;

    typedef enum {
        IDLE_5S,
        COUNT_5S
    } state_5s_t;
    state_5s_t       state_5s;

    logic      [3:0] red_sec;  // 빨강 섹션 기억하는 로직 추가하기


    always_ff @(posedge clk or posedge reset) begin
        if (reset || o_mode_btn) begin
            tick_5s  <= 1;
            count_5s <= 0;
            state_5s <= IDLE_5S;
        end else begin
            case (state_5s)
                IDLE_5S: begin
                    tick_5s <= 1;
                    if (bunker_detected || frame_done) begin
                        state_5s <= COUNT_5S;
                        count_5s <= 0;
                    end
                end
                COUNT_5S: begin
                    tick_5s <= 0;
                    if (count_5s == CLK_5S - 1) begin
                        count_5s <= 0;
                        state_5s <= IDLE_5S;
                    end else begin
                        count_5s <= count_5s + 1;
                    end

                end
            endcase

        end
    end

    always_ff @(posedge clk or posedge reset) begin
        if (reset || o_mode_btn) begin
            state <= ST_IDLE;
            fsm_sec <= 0;
            hint_data_reg <= 0;
            data_done <= 0;
            bunker_detected <= 0;
            game_ing <= 0;
            red_sec <= 0;
            for (k = 0; k < 15; k = k + 1) begin
                result_valid[k] <= 1'b0;
            end
        end else begin
            data_done <= 0;
            bunker_detected <= 0;
            frame_done_flag <= 0;
            case (state)

                ST_IDLE: begin
                    if (frame_end && camera_start) begin
                        fsm_sec <= 0;
                        state   <= WAIT_FRAME_END;

                    end
                end
                WAIT_FRAME_END: begin
                    if (frame_end) begin

                        state <= ST_COLOR;
                    end
                end

                ST_COLOR: begin

                    if (red_cnt[fsm_sec] >= grn_cnt[fsm_sec] && red_cnt[fsm_sec] >= blu_cnt[fsm_sec]) begin
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

                    end else begin
                        result_valid[fsm_sec] <= 1'b0;
                        result_color[fsm_sec] <= 2'b00;

                    end

                    state <= ST_DONE;
                end

                ST_DONE: begin
                    if (fsm_sec == 4'd14) begin
                        count_1sec <= 0;
                        fsm_sec <= 0;
                        if (!red_detected_4 || !red_detected_2) begin
                            frame_done_flag <= 1;
                        end
                        state <= WAIT_1SEC;
                    end else begin
                        fsm_sec <= fsm_sec + 1;
                        state   <= ST_COLOR;
                    end

                    if (result_valid[fsm_sec]) begin

                        hint_data_reg <= {result_color[fsm_sec], fsm_sec};

                        if (result_color[fsm_sec] == `RED) begin
                            if (game_ing) begin
                                red_detected_3 <= 1;
                                state <= WAIT_1SEC;
                                if (red_detected_4) begin
                                    game_ing <= 0;
                                    red_detected_3 <= 0;
                                    data_done <= 1;
                                    bunker_detected <= 1;
                                    count_4sec <= 0;
                                    state <= WAIT_4SEC;
                                end

                            end else begin
                                red_detected <= 1;
                                if (red_detected_2) begin
                                    game_ing <= 1;
                                    red_detected <= 0;
                                    data_done <= 1;
                                    bunker_detected <= 1;
                                    count_4sec <= 0;
                                    state <= WAIT_4SEC;
                                end
                            end
                        end else begin
                            if (game_ing) begin
                                data_done <= 1;
                            end
                        end

                    end else begin
                        hint_data_reg <= 0;
                    end


                end

                WAIT_4SEC: begin
                    if (count_4sec == CLK_4_SEC - 1) begin
                        count_4sec <= 0;
                        state <= ST_IDLE;

                    end else begin
                        count_4sec <= count_4sec + 1;
                    end
                end

                WAIT_1SEC: begin
                    if (count_1sec == CLK_1_SEC - 1) begin
                        count_1sec <= 0;
                        state <= ST_IDLE;

                    end else begin
                        count_1sec <= count_1sec + 1;
                    end
                end

                default: state <= ST_IDLE;
            endcase
        end
    end

    typedef enum {
        BF_RED,
        AFTER_RED,
        WAIT_RED
    } red_state_t;

    red_state_t red_state, red_state_2;

    localparam CLK_SIZE_3S = 300_000_000;

    logic [$clog2(CLK_SIZE_3S)-1:0] clk_count;


    always_ff @(posedge clk or posedge reset) begin
        if (reset || o_mode_btn) begin
            red_state <= BF_RED;
            red_detected_2 <= 0;
            clk_count <= 0;
        end else begin
            case (red_state)
                BF_RED: begin
                    if (red_detected) begin
                        red_state <= AFTER_RED;
                        clk_count <= 0;
                        red_detected_2 <= 0;
                    end
                end
                AFTER_RED: begin
                    if (clk_count == CLK_SIZE_3S - 1) begin
                        clk_count <= 0;
                        red_detected_2 <= 1;
                        red_state <= WAIT_RED;
                    end else begin
                        clk_count <= clk_count + 1;
                    end
                end

                WAIT_RED: begin
                    if (bunker_detected) begin
                        red_detected_2 <= 0;

                        red_state <= BF_RED;
                    end
                end

            endcase
        end
    end

    localparam CLK_SIZE_900MS = 90_000_000;

    logic [$clog2(CLK_SIZE_900MS)-1:0] clk_count2;

    always_ff @(posedge clk or posedge reset) begin
        if (reset || o_mode_btn) begin
            red_state_2 <= BF_RED;
            red_detected_4 <= 0;
            clk_count2 <= 0;
        end else begin
            case (red_state_2)
                BF_RED: begin
                    if (red_detected_3) begin
                        red_state_2 <= AFTER_RED;
                        red_detected_4 <= 0;
                        clk_count2 <= 0;
                    end
                end
                AFTER_RED: begin
                    if (clk_count2 == CLK_SIZE_900MS - 1) begin
                        clk_count2 <= 0;
                        red_detected_4 <= 1;
                        red_state_2 <= WAIT_RED;
                    end else begin
                        clk_count2 <= clk_count2 + 1;
                    end
                end

                WAIT_RED: begin
                    if (bunker_detected) begin
                        red_detected_4 <= 0;
                        red_state_2 <= BF_RED;
                    end
                end

            endcase
        end
    end

    assign hint_data = signal_data ? {4'b0100,hint_data_reg[3:0] }  : hint_data_reg;

    assign signal_data = ~game_ing && bunker_detected && !red_detected_3 && red_detected_4;
    // uart_cnt_sender u_uart_cnt_sender (
    //     .clk(clk),
    //     .reset(reset),
    //     .frame_done(frame_done),
    //     .max_cnt(max_cnt[fsm_sec]),
    //     .H(H),
    //     .S(S),
    //     .V(V),
    //     .hint_data(hint_data),
    //     .data_done(data_done),
    //     .uart_txd(uart_txd)
    // );

    // uart_cnt_sender U_u (
    //     .clk         (clk),
    //     .reset       (reset),
    //     .frame_done  (frame_done_flag),  // 프레임 끝 펄스
    //     .red_cnt     (red_cnt),
    //     .grn_cnt     (grn_cnt),
    //     .blu_cnt     (blu_cnt),
    //     .sample_H_red(/* sample_H_red */8'h45),
    //     .sample_S_red(sample_S_red),
    //     .sample_V_red(sample_V_red),
    //     .sample_H_grn(sample_H_grn),
    //     .sample_S_grn(sample_S_grn),
    //     .sample_V_grn(sample_V_grn),
    //     .sample_H_blu(sample_H_blu),
    //     .sample_S_blu(sample_S_blu),
    //     .sample_V_blu(sample_V_blu),
    //     .hint_data   (hint_data_reg),
    //     .data_done   (data_done),
    //     .uart_txd    (RsTx_UI)
    // );

    logic [7:0] hint_data_reg_f;
    always_ff @(posedge clk or posedge reset) begin
        if (reset || o_mode_btn) hint_data_reg_f <= 0;
        else if (data_done) hint_data_reg_f <= hint_data_reg;
    end

    logic data_done_latch;
    always_ff @(posedge clk or posedge reset) begin
        if (reset || o_mode_btn) data_done_latch <= 0;
        else if (data_done) data_done_latch <= 1;  // 한번 뜨면 유지
    end



    logic [1:0] frame_done_delay;
    always_ff @(posedge clk or posedge reset) begin
        if (reset || o_mode_btn) begin
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

    // LED용 combinational 출력
    logic       any_red_valid;
    logic       any_red_shape;
    logic [3:0] first_red_sec;
    logic [1:0] first_red_shape;

    always_comb begin
        any_red_valid = 1'b0;
        any_red_shape = 1'b0;
        first_red_sec = 4'd0;
        for (int m = 0; m < 15; m++) begin
            if (result_valid[m] && (result_color[m] == `RED) && !any_red_valid) begin
                any_red_shape = 1'b1;
                any_red_valid = 1'b1;
                first_red_sec = m[3:0];
            end
        end
    end

    assign one_red_undetected = !red_detected_4 || !red_detected_2;

    logic       any_blu_valid;
    logic [3:0] first_blu_sec;
    logic [1:0] first_blu_shape;

    always_comb begin
        any_blu_valid = 1'b0;
        first_blu_sec = 4'd0;
        for (int m = 0; m < 15; m++) begin
            if (result_valid[m] && (result_color[m] == `BLUE) && !any_blu_valid) begin
                any_blu_valid = 1'b1;
                first_blu_sec = m[3:0];
            end
        end
    end


    logic       any_grn_valid;
    logic [3:0] first_grn_sec;
    logic [1:0] first_grn_shape;

    always_comb begin
        any_grn_valid = 1'b0;
        first_grn_sec = 4'd0;
        for (int m = 0; m < 15; m++) begin
            if (result_valid[m] && (result_color[m] == `GREEN) && !any_grn_valid) begin
                any_grn_valid = 1'b1;
                first_grn_sec = m[3:0];
            end
        end
    end

    localparam CLK_10S = 1_000_000_000;
    logic [$clog2(CLK_10S)-1:0] counter_10s;


    logic frame_done_reg, bunker_detected_reg;
    logic data_done_reg;
    always_ff @(posedge clk or posedge reset) begin
        if (reset || o_mode_btn) begin
            counter_10s         <= 0;
            frame_done_reg      <= 0;
            bunker_detected_reg <= 0;
            data_done_reg       <= 0;
        end else begin
            if (counter_10s == CLK_10S - 1) begin
                counter_10s         <= 0;
                frame_done_reg      <= 0;
                bunker_detected_reg <= 0;
                data_done_reg       <= 0;
            end else begin
                if (frame_done) frame_done_reg <= 1;
                if (bunker_detected) bunker_detected_reg <= 1;
                if (data_done) data_done_reg <= 1;
                counter_10s <= counter_10s + 1;
            end
        end
    end



    // =========================================================
    //   assign debug_led[0] = any_red_valid;
    //   assign debug_led[1] = hint_data_reg_f[0];
    //   assign debug_led[2] = hint_data_reg_f[1];
    //   assign debug_led[3] = hint_data_reg_f[2];
    //   assign debug_led[4] = hint_data_reg_f[3];
    //   assign debug_led[5] = hint_data_reg_f[4];
    //   assign debug_led[6] = hint_data_reg_f[5];
    //   assign debug_led[7] = hint_data_reg_f[6];
    //   assign debug_led[8] = hint_data_reg_f[7];
    //   assign debug_led[9] = any_red_shape;
    // assign debug_led[3:0] = hint_data_reg_f[3:0];  // sec 번호
    // assign debug_led[5:4] = hint_data_reg_f[5:4];  // color
    // assign debug_led[7:6] = hint_data_reg_f[7:6];  // shape
    // assign debug_led[8]   = data_done_latch;  // hint 출력 됐는지
    // assign debug_led[9]   = game_ing;  // game_ing 상태
    // assign debug_led[10]  = red_sqr_detect;  // 3초 카운트 중인지
    // assign debug_led[11]  = bunker_detected;  // 벙커 감지


    assign debug_led[0]  = any_blu_valid;
    assign debug_led[1]  = any_grn_valid;
    assign debug_led[2]  = any_red_shape;

    assign debug_led[7]  = signal_data;

    assign debug_led[12] = game_ing;
    assign debug_led[13] = data_done_reg;
    assign debug_led[14] = bunker_detected_reg;
    assign debug_led[15] = frame_done_reg;




endmodule

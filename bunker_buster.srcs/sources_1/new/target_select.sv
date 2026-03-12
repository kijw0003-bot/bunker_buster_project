`timescale 1ns / 1ps
`include "define.vh"

module target_select (
    input  logic       clk,
    input  logic       reset,
    // 모양 식별 모듈과의 signals
    input  logic [7:0] hint_data,
    input  logic [3:0] hint_count,
    input  logic       data_done,
    input  logic       frame_done,
    input  logic       bunker_detected,
    // 출력
    output logic [7:0] target_data
);

    // port 이름

    // [3:0] hint_count : 힌트의 개수   ( 이 신호가 들어오면 힌트의 개수가 확정됨)

    // [7:0] hint_data  : 힌트 데이터  모양(2 bit), 색(2 bit), 위치 (4bit) 순서대로

    //  data_done : 한 바이트가 완성 되었을때 1 tick 1이 되었다가 다시 끈다. -> hint_data 를 입력 받음

    // frame_done : 1 프레임 안에 있는 모든 모양, 색 위치를 파악 완료하면 1 tick 생성 후에 다시 0
    //              -> hint_count 를 저장 시작

    // GREEN :  거리 0 ~ 1
    // BLUE :   거리 0 ~ 3
    // YELLOW : 거리 0 ~ 4    


    // -------------function 정의--------------------------
    function automatic void idx_to_xy(
        input logic [3:0] idx, output logic [2:0] x, output logic [1:0] y);

        case (idx)

            `SECTION_0: begin
                x = 0;
                y = 0;
            end
            `SECTION_1: begin
                x = 1;
                y = 0;
            end
            `SECTION_2: begin
                x = 2;
                y = 0;
            end
            `SECTION_3: begin
                x = 3;
                y = 0;
            end
            `SECTION_4: begin
                x = 4;
                y = 0;
            end

            `SECTION_5: begin
                x = 0;
                y = 1;
            end
            `SECTION_6: begin
                x = 1;
                y = 1;
            end
            `SECTION_7: begin
                x = 2;
                y = 1;
            end
            `SECTION_8: begin
                x = 3;
                y = 1;
            end
            `SECTION_9: begin
                x = 4;
                y = 1;
            end

            `SECTION_10: begin
                x = 0;
                y = 2;
            end
            `SECTION_11: begin
                x = 1;
                y = 2;
            end
            `SECTION_12: begin
                x = 2;
                y = 2;
            end
            `SECTION_13: begin
                x = 3;
                y = 2;
            end
            `SECTION_14: begin
                x = 4;
                y = 2;
            end

            default: begin
                x = 0;
                y = 0;
            end

        endcase

    endfunction

    function automatic [2:0] abs_diff(input [2:0] a, input [2:0] b);

        if (a > b) abs_diff = a - b;
        else abs_diff = b - a;

    endfunction

    function automatic [2:0] manhattan(input [3:0] a, input [3:0] b);

        logic [2:0] ax, bx;
        logic [1:0] ay, by;

        idx_to_xy(a, ax, ay);
        idx_to_xy(b, bx, by);

        manhattan = abs_diff(ax, bx) + abs_diff(ay, by);

    endfunction

    // wire, logic 추가
    logic [1:0] color;
    logic [1:0] shape;
    logic [3:0] section;

    assign {shape, color, section} = hint_data;

    logic [4:0] n_score[0:14];
    logic [4:0] c_score[0:14];
    logic [4:0] c_max_score, n_max_score;

    logic [14:0] c_valid, n_valid;
    logic [2:0] distance;

    logic [3:0] c_max_index, n_max_index;

    logic [3:0] c_clk_count, n_clk_count;
    logic [3:0] c_hint_count_reg, n_hint_count_reg;

    assign target_data = {4'b1111, c_max_index};

    typedef enum {
        IDLE,
        RECEIVE_DATA
    } state_t;
    state_t c_state, n_state;


    // 데이터 및 개수 초기화
    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            for (int i = 0; i < 15; i++) begin
                c_score[i] <= 2;
                c_valid[i] <= 1;
            end
            c_max_score <= 16;
            c_max_index <= 0;
            c_clk_count <= 0;
            c_hint_count_reg <= 0;
            c_state <= IDLE;
        end else begin
            for (int i = 0; i < 15; i++) begin
                c_score[i] <= n_score[i];
                c_valid[i] <= n_valid[i];
            end
            c_max_index <= n_max_index;
            c_max_score <= n_max_score;
            c_clk_count <= n_clk_count;
            c_hint_count_reg <= n_hint_count_reg;
            c_state <= n_state;
        end
    end

    // data_done 발생 시  score 계산 
    always_comb begin
        for (int i = 0; i < 15; i++) begin
            n_score[i] = c_score[i];
            n_valid[i] = c_valid[i];
        end
        n_state = c_state;
        distance = 0;
        n_clk_count = c_clk_count;
        n_hint_count_reg = c_hint_count_reg;

        case (c_state)
            IDLE: begin
                if (frame_done) begin
                    for (int i = 0; i < 15; i++) begin
                        n_score[i] = 16;
                        n_valid[i] = 1;
                    end
                    n_hint_count_reg = hint_count;
                    n_clk_count = 0;
                end else if (~bunker_detected & data_done) begin // 벙커는 아니고 도형 식별
                    n_state = RECEIVE_DATA;
                    n_clk_count = 0;
                end
            end

            RECEIVE_DATA: begin
                case (color)
                    `GREEN:  distance = 1;
                    `BLUE:   distance = 3;
                    `YELLOW: distance = 4;
                endcase

                case (shape)
                    `CIRCLE: begin
                        for (int i = 0; i < 15; i++) begin
                            if (manhattan(section, i) <= distance) begin
                                if (c_valid[i]) begin
                                    n_score[i] = c_score[i] + 1;
                                end
                            end else begin
                                n_valid[i] = 0;
                            end
                        end
                    end
                    `TRIANGLE: begin
                        for (int i = 0; i < 15; i++) begin
                            if (manhattan(section, i) > distance) begin
                                if (c_valid[i]) begin
                                    n_score[i] = c_score[i] + 1;
                                end
                            end else begin
                                n_valid[i] = 0;
                            end
                        end

                    end
                endcase
                n_state = IDLE;
            end
        endcase
    end

    always_comb begin  // score 최댓값 및 최댓값의 위치 저장
        n_max_index = c_max_index;
        n_max_score = c_max_score;

        if (frame_done) begin
            n_max_score = 16;
            n_max_index = 0;
        end else begin
            for (int i = 0; i < 15; i++) begin
                if (c_valid[i]) begin
                    if (!c_valid[c_max_index]) begin
                        n_max_index = i;
                        n_max_score = c_score[i];
                    end else begin
                        if (c_max_score < c_score[i]) begin
                            n_max_index = i;
                            n_max_score = c_score[i];
                        end
                    end
                end
            end
        end


    end

endmodule

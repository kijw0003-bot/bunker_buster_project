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

    logic [1:0] color;
    logic [1:0] shape;
    logic [3:0] section;

    assign {shape, color, section} = hint_data;

    logic [8:0] n_score[0:14];
    logic [8:0] c_score[0:14];
    logic [8:0] c_max_score, n_max_score;
    logic [7:0] unsigned_score;
    logic [7:0] signed_score;

    logic [3:0] c_max_index, n_max_index;

    logic [3:0] c_clk_count, n_clk_count;
    logic [3:0] c_hint_count_reg, n_hint_count_reg;

    assign target_data = {
        4'b1111, c_max_index
    };  // frame_done 에 따라 출력 끊기를 안해도 되나? 생각

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
            end
            c_max_score <= 256;
            c_max_index <= 0;
            c_clk_count = 0;
            c_hint_count_reg <= 0;
            c_state <= IDLE;
        end else begin
            for (int i = 0; i < 15; i++) begin
                c_score[i] <= n_score[i];
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
        end
        n_state = c_state;
        unsigned_score = 0;
        signed_score = 0;
        n_clk_count = c_clk_count;
        n_hint_count_reg = c_hint_count_reg;
        case (c_state)
            IDLE: begin
                if (frame_done) begin
                    for (int i = 0; i < 15; i++) begin
                        n_score[i] = 256;
                    end
                    n_hint_count_reg = hint_count;
                    n_clk_count = 0;
                end else if (~bunker_detected & data_done) begin // 벙커는 아니고 도형 식별
                    n_state = RECEIVE_DATA;
                    n_clk_count = 0;
                end
            end
            RECEIVE_DATA: begin
                if (c_clk_count == 6 - 1) begin
                    case (color)  // 색에 따른 확률
                        `GREEN:  unsigned_score = 80;
                        `BLUE:   unsigned_score = 50;
                        `YELLOW: unsigned_score = 30;
                    endcase

                    case (shape)  // 모양에 따른 부호 설정
                        `CIRCLE: begin
                            signed_score = unsigned_score;
                        end
                        `TRIANGLE: begin
                            signed_score = ~unsigned_score + 1;
                        end
                    endcase

                    case (section)  // 위치에 따른 계산

                        `SECTION_0: begin  // 왼쪽 위 구석
                            n_score[section+1] += {
                                signed_score[7], signed_score
                            };
                            n_score[section+5] += {
                                signed_score[7], signed_score
                            };
                        end
                        `SECTION_4: begin  // 오른쪽 위 구석
                            n_score[section-1] += {
                                signed_score[7], signed_score
                            };
                            n_score[section+5] += {
                                signed_score[7], signed_score
                            };
                        end
                        `SECTION_10: begin  // 왼쪽 아래 구석
                            n_score[section+1] += {
                                signed_score[7], signed_score
                            };
                            n_score[section-5] += {
                                signed_score[7], signed_score
                            };
                        end
                        `SECTION_14: begin  // 오른쪽 아래 구석
                            n_score[section-1] += {
                                signed_score[7], signed_score
                            };
                            n_score[section-5] += {
                                signed_score[7], signed_score
                            };
                        end
                        `SECTION_1, `SECTION_2, `SECTION_3: begin  // 맨 윗줄
                            n_score[section+1] += {
                                signed_score[7], signed_score
                            };
                            n_score[section-1] += {
                                signed_score[7], signed_score
                            };
                            n_score[section+5] += {
                                signed_score[7], signed_score
                            };
                        end
                        `SECTION_11, `SECTION_12, `SECTION_13: begin  // 맨 아랫줄
                            n_score[section+1] += {
                                signed_score[7], signed_score
                            };
                            n_score[section-1] += {
                                signed_score[7], signed_score
                            };
                            n_score[section-5] += {
                                signed_score[7], signed_score
                            };
                        end
                        `SECTION_5: begin  // 맨 왼쪽 줄
                            n_score[section+1] += {
                                signed_score[7], signed_score
                            };
                            n_score[section+5] += {
                                signed_score[7], signed_score
                            };
                            n_score[section-5] += {
                                signed_score[7], signed_score
                            };
                        end
                        `SECTION_9: begin  //  맨 오른쪽 줄
                            n_score[section-1] += {
                                signed_score[7], signed_score
                            };
                            n_score[section+5] += {
                                signed_score[7], signed_score
                            };
                            n_score[section-5] += {
                                signed_score[7], signed_score
                            };
                        end
                        default: begin  // 나머지 가운데 부분
                            n_score[section+1] += {
                                signed_score[7], signed_score
                            };
                            n_score[section-1] += {
                                signed_score[7], signed_score
                            };
                            n_score[section+5] += {
                                signed_score[7], signed_score
                            };
                            n_score[section-5] += {
                                signed_score[7], signed_score
                            };
                        end
                    endcase
                    n_clk_count = 0;
                    n_state = IDLE;
                end else begin
                    n_clk_count = n_clk_count + 1;
                end
            end
        endcase


    end


    always_comb begin  // score 최댓값 및 최댓값의 위치 저장
        n_max_index = c_max_index;
        n_max_score = c_max_score;

        if (frame_done) begin
            n_max_score = 256;
            n_max_index = 0;
        end else begin
            for (int i = 0; i < 15; i++) begin
                if (c_max_score < c_score[i]) begin
                    n_max_index = i;
                    n_max_score = c_score[i];
                end
            end
        end


    end

endmodule

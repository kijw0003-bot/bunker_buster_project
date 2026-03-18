`timescale 1ns / 1ps

module receive_done_signal (
    input  logic       clk,
    input  logic       reset,
    input  logic       game_mode,
    input  logic       game_ing,
    input  logic       bunker_detected,
    input  logic [7:0] UI_pc_rx_data,
    input  logic       UI_pc_rx_done,
    input  logic [7:0] hint_pc_rx_data,
    input  logic       hint_pc_rx_done,
    input  logic       frame_done,
    input  logic       o_mode_btn,
    output logic       camera_start
);
    localparam CLK_SIZE = 600_000_000;

    logic [$clog2(CLK_SIZE)-1:0] c_clk_count, n_clk_count;



    localparam FRAME_ACTION = 8'h7E;

    typedef enum {
        IDLE,
        TARGET_SELECT,
        RECEIVE
    } state_t;

    state_t c_state, n_state;

    logic c_hint_action_done, n_hint_action_done;
    logic c_UI_action_done, n_UI_action_done;

    logic camera_start_next;

    always_ff @(posedge clk or posedge reset) begin
        if (reset || o_mode_btn) begin
            c_state <= IDLE;
            c_clk_count <= 0;
            camera_start <= 0;
        end else begin
            c_state <= n_state;
            c_clk_count <= n_clk_count;
            camera_start <= camera_start_next;
        end
    end




    always_comb begin
        n_state = c_state;
        n_clk_count = c_clk_count;
        camera_start_next = camera_start;
        case (c_state)
            IDLE: begin
                camera_start_next = 1;
                if ((frame_done && game_ing) || bunker_detected) begin
                    n_clk_count = 0;
                    camera_start_next = 0;
                    n_state = RECEIVE;
                end
            end

            TARGET_SELECT: begin
                if (bunker_detected || (frame_done && game_ing)) begin
                    camera_start_next = 0;
                    n_clk_count = 0;
                    n_state = RECEIVE;
                end
            end
            RECEIVE: begin
                if (c_clk_count == CLK_SIZE - 1) begin
                    n_clk_count = 0;
                    if (!game_mode) begin
                        camera_start_next = 1;
                        n_state = TARGET_SELECT;
                    end
                end else begin
                    n_clk_count = c_clk_count + 1;

                    if (game_mode) begin
                        if (c_hint_action_done & c_UI_action_done) begin
                            camera_start_next = 1;
                            n_state = TARGET_SELECT;
                        end
                    end else begin
                        if (c_hint_action_done) begin
                            camera_start_next = 1;
                            n_state = TARGET_SELECT;
                        end

                    end
                end
            end
        endcase
    end

    //-------------------------------------------------------------
    //----------------- 힌트,UI PC 신호 ----------------------------
    //-------------------------------------------------------------

    always_ff @(posedge clk or posedge reset) begin
        if (reset || o_mode_btn) begin
            c_hint_action_done <= 0;
            c_UI_action_done   <= 0;
        end else begin
            c_hint_action_done <= n_hint_action_done;
            c_UI_action_done   <= n_UI_action_done;
        end
    end

    always_comb begin
        n_hint_action_done = c_hint_action_done;
        n_UI_action_done   = c_UI_action_done;
        case (c_state)
            IDLE: begin
                n_hint_action_done = 1;
                n_UI_action_done   = 1;
                if (frame_done || bunker_detected) begin
                    n_hint_action_done = 0;
                    n_UI_action_done   = 0;
                end
            end

            TARGET_SELECT: begin
                if (frame_done || bunker_detected) begin
                    n_hint_action_done = 0;
                    n_UI_action_done   = 0;
                end
            end
            RECEIVE: begin
                if (c_clk_count == CLK_SIZE - 1) begin
                    n_hint_action_done = 1;
                    n_UI_action_done   = 1;
                end else begin

                    if ((hint_pc_rx_data == FRAME_ACTION) && hint_pc_rx_done) begin
                        n_hint_action_done = 1;
                    end

                    if ((UI_pc_rx_data == FRAME_ACTION) && UI_pc_rx_done) begin
                        n_UI_action_done = 1;
                    end

                end


            end
        endcase
    end

endmodule

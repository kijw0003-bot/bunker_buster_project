`timescale 1ns / 1ps

module receive_done_signal (
    input  logic       clk,
    input  logic       reset,
    input  logic       game_mode,
    input  logic       bunker_detected,
    input  logic [7:0] UI_pc_rx_data,
    input  logic       UI_pc_rx_done,
    input  logic [7:0] hint_pc_rx_data,
    input  logic       hint_pc_rx_done,
    input  logic       frame_done,
    output logic       camera_start
);

    localparam FRAME_ACTION = 8'hFF;

    typedef enum {
        IDLE,
        TARGET_SELECT,
        RECEIVE
    } state_t;

    state_t c_state, n_state;

    logic c_hint_action_done, n_hint_action_done;
    logic c_UI_action_done, n_UI_action_done;

    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            c_state <= IDLE;
        end else begin
            c_state <= n_state;
        end
    end

    always_comb begin
        n_state = c_state;
        camera_start = 0;

        case (c_state)
            IDLE: begin
                camera_start = 1;
                if (frame_done) begin
                    n_state = RECEIVE;
                end
            end

            TARGET_SELECT: begin
                if (bunker_detected) begin
                    n_state = IDLE;
                end else if (frame_done) begin
                    camera_start = 0;
                    n_state = TARGET_SELECT;
                end
            end
            RECEIVE: begin
                if (game_mode) begin
                    if (c_hint_action_done & c_UI_action_done) begin
                        camera_start = 1;
                        n_state = TARGET_SELECT;
                    end
                end else begin
                    if (c_hint_action_done) begin
                        camera_start = 1;
                        n_state = TARGET_SELECT;
                    end

                end
            end
        endcase
    end

    //-------------------------------------------------------------
    //----------------- 힌트,UI PC 신호 ----------------------------
    //-------------------------------------------------------------

    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
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
                if (frame_done) begin
                    n_hint_action_done = 0;
                    n_UI_action_done   = 0;
                end
            end

            TARGET_SELECT: begin
                if (frame_done) begin
                    n_hint_action_done = 0;
                    n_UI_action_done   = 0;
                end
            end
            RECEIVE: begin
                if ((hint_pc_rx_data == FRAME_ACTION) && hint_pc_rx_done) begin
                    n_hint_action_done = 1;
                end

                if ((UI_pc_rx_data == FRAME_ACTION) && UI_pc_rx_done) begin
                    n_UI_action_done = 1;
                end
            end
        endcase


    end




endmodule

`timescale 1ns / 1ps



module mode_change (
    input  logic clk,
    input  logic reset,
    input  logic mode_btn,
    output logic game_mode
);

    typedef enum {
        OFF,
        ON
    } state_t;

    state_t c_state, n_state;

    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            c_state <= OFF;
        end else begin
            c_state <= n_state;
        end
    end

    always_comb begin
        n_state   = c_state;
        game_mode = 0;
        case (c_state)
            OFF: begin
                game_mode = 0;
                if (mode_btn) begin
                    n_state = ON;
                end
            end
            ON: begin
                game_mode = 1;
                if (mode_btn) begin
                    n_state = OFF;
                end

            end
        endcase
    end


endmodule

`timescale 1ns / 1ps
// 
module SCCB_DELAY (

    input  logic clk,
    input  logic reset,
    output logic en

);

    logic [$clog2(10_000_000)-1:0] counter;  //100ms

    always_ff @(posedge clk, posedge reset) begin

        if (reset) begin
            counter <= 0;
            en      <= 0;
        end else begin
            if (counter == 10_000_000 - 1) begin  //100ms
                en <= 1;
            end else begin
                counter <= counter + 1;
                en <= 0;
            end
        end

    end


endmodule




`timescale 1ns / 1ps

module mux_nx1 #(
    parameter NUM   = 2,
    parameter WIDTH = 8

) (
    input  [$clog2(NUM)-1:0] sel,
    input  [     WIDTH -1:0] x  [0:NUM-1],
    output [     WIDTH -1:0] y
);

    assign y = x[sel];
endmodule

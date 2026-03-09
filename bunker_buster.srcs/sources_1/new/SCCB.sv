`timescale 1ns / 1ps

module SCCB (
    input  logic clk,
    input  logic reset,
    output logic sioc,
    inout  wire  siod
);

    typedef enum {
        IDLE,
        START,
        SEND_ADDRESS,
        WRITE_DATA
    } name;


endmodule



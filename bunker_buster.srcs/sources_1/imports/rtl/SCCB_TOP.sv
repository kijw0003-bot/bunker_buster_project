`timescale 1ns / 1ps

module SCCB_TOP (

    input  logic clk,
    input  logic reset,
    output logic scl,
    output logic sda
);


    logic       w_tx_done;
    logic       w_en;

    logic [6:0] w_addr;
    logic [7:0] w_reg_addr;
    logic [7:0] w_reg_data;
    logic       w_start;


    SCCB U_SCCB (
        .clk(clk),
        .reset(reset),
        .en(w_en),
        .reg_addr(w_reg_addr),
        .reg_data(w_reg_data),
        .scl(scl),
        .sda(sda),
        .tx_done(w_tx_done)
    );

    SCCB_DELAY U_SCCB_DELAY (

        .clk(clk),
        .reset(reset),
        .en(w_en)

    );

    SCCB_ROM_COUNTER U_SCCB_ROM_COUNTER (
        .clk(clk),
        .reset(reset),
        .tx_done(w_tx_done),  //SCCB 통신 끝나면 받음
        .addr(w_addr)

    );

    SCCB_ROM U_SCCB_ROM (
        .addr(w_addr),
        .reg_addr(w_reg_addr),
        .reg_data(w_reg_data)

    );


endmodule

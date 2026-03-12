`timescale 1ns / 1ps
`include "define.vh"

module tb_send_uart2hintpc;

    logic clk;
    logic reset;

    logic [7:0] hint_data;
    logic [7:0] target_data;

    logic frame_done;
    logic bunker_detected;

    logic [7:0] hint_pc_tx_mux_out;

    logic hint_tx_fifo_empty;
    logic [7:0] hint_pc_tx_fifo_rdata;
    logic hint_tx_busy;

    logic RsTx_hint;


    //--------------------------------
    // clock
    //--------------------------------

    always #5 clk = ~clk;  // 100MHz


    //--------------------------------
    // mux input
    //--------------------------------

    logic [7:0] mux_in[2];

    assign mux_in[0] = hint_data;
    assign mux_in[1] = target_data;


    //--------------------------------
    // DUT PATH
    //--------------------------------

    mux_nx1 #(
        .NUM  (2),
        .WIDTH(8)
    ) PC_tx_fifo_src_mux (
        .sel(frame_done),
        .x  (mux_in),
        .y  (hint_pc_tx_mux_out)
    );


    FIFO u_hint_pc_tx_fifo (
        .clk(clk),
        .reset(reset),
        .wr(bunker_detected | frame_done),
        .rd(~hint_tx_busy),
        .wdata(hint_pc_tx_mux_out),
        .rdata(hint_pc_tx_fifo_rdata),
        .full(),
        .empty(hint_tx_fifo_empty)
    );


    uart_tx #(
        .BPS(9600)
    ) u_uart_PC_tx (
        .clk(clk),
        .reset(reset),
        .tx_data(hint_pc_tx_fifo_rdata),
        .tx_start(~hint_tx_fifo_empty),
        .tx(RsTx_hint),
        .tx_busy(hint_tx_busy)
    );


    //--------------------------------
    // TEST
    //--------------------------------

    initial begin

        clk = 0;
        reset = 1;

        frame_done = 0;
        bunker_detected = 0;

        hint_data = 0;
        target_data = 0;

        #100 reset = 0;


        //------------------------------------------------
        // CASE1 : 힌트 데이터 전송
        //------------------------------------------------

        $display("CASE1 : HINT DATA TX");

        hint_data = {`CIRCLE, `GREEN, `SECTION_6};

        bunker_detected = 1;
        @(posedge clk);
        bunker_detected = 0;

        repeat (20000) @(posedge clk);



        //------------------------------------------------
        // CASE2 : 다른 힌트
        //------------------------------------------------

        $display("CASE2 : TRIANGLE BLUE");

        hint_data = {`TRIANGLE, `BLUE, `SECTION_3};

        bunker_detected = 1;
        @(posedge clk);
        bunker_detected = 0;

        repeat (20000) @(posedge clk);



        //------------------------------------------------
        // CASE3 : frame_done → target_data 전송
        //------------------------------------------------

        $display("CASE3 : TARGET DATA");

        target_data = {4'b1111, `SECTION_10};

        frame_done  = 1;
        @(posedge clk);
        frame_done = 0;

        repeat (20000) @(posedge clk);



        //------------------------------------------------
        // CASE4 : 여러 힌트 연속
        //------------------------------------------------

        $display("CASE4 : MULTI HINT");

        hint_data = {`CIRCLE, `RED, `SECTION_14};

        bunker_detected = 1;
        @(posedge clk);
        bunker_detected = 0;

        repeat (20000) @(posedge clk);

        hint_data = {`TRIANGLE, `GREEN, `SECTION_0};

        bunker_detected = 1;
        @(posedge clk);
        bunker_detected = 0;

        repeat (20000) @(posedge clk);



        $finish;

    end


    //--------------------------------
    // monitor
    //--------------------------------

    initial begin
        $monitor("time=%0t  TX=%b  FIFO_EMPTY=%b", $time, RsTx_hint,
                 hint_tx_fifo_empty);
    end


endmodule

`timescale 1ns / 1ps

module tb_top;

    // clock
    logic clk;
    logic reset;

    // camera dummy
    logic pclk;
    logic href;
    logic vsync;
    logic [7:0] data;

    // button
    logic mode_btn;

    // uart
    logic RsRx_hint;
    logic RsRx_UI;

    wire RsTx_UI;
    wire RsTx_hint;

    // VGA (unused)
    wire h_sync;
    wire v_sync;
    wire [3:0] port_red;
    wire [3:0] port_green;
    wire [3:0] port_blue;

    wire scl;
    wire sda;
    wire xclk;

    //---------------------------------------
    // DUT
    //---------------------------------------

    top_VGA_OV7670 dut (
        .clk  (clk),
        .reset(reset),

        .xclk (xclk),
        .pclk (pclk),
        .href (href),
        .vsync(vsync),
        .data (data),

        .mode_btn(mode_btn),

        .h_sync(h_sync),
        .v_sync(v_sync),
        .port_red(port_red),
        .port_green(port_green),
        .port_blue(port_blue),

        .scl(scl),
        .sda(sda),

        .RsRx_hint(RsRx_hint),
        .RsTx_hint(RsTx_hint),

        .RsRx_UI(RsRx_UI),
        .RsTx_UI(RsTx_UI)
    );

    //---------------------------------------
    // clock 생성
    //---------------------------------------

    initial clk = 0;
    always #5 clk = ~clk;  // 100MHz

    initial pclk = 0;
    always #20 pclk = ~pclk;

    //---------------------------------------
    // 초기값
    //---------------------------------------

    initial begin

        reset = 1;
        mode_btn = 0;

        href = 0;
        vsync = 0;
        data = 0;

        RsRx_UI = 1;
        RsRx_hint = 1;

        #100;
        reset = 0;

        //-----------------------------------
        // 버튼 1번
        //-----------------------------------

        #200;

        $display("button press 1");

        mode_btn = 1;
        #1000;
        mode_btn = 0;

        //-----------------------------------
        // 버튼 2번
        //-----------------------------------

        #200000;

        $display("button press 2");

        mode_btn = 1;
        #1000;
        mode_btn = 0;

        //-----------------------------------

        #200000;

        $finish;

    end

    //---------------------------------------
    // UART 출력 모니터
    //---------------------------------------

    initial begin
        $monitor("time=%t UART_TX=%b", $time, RsTx_UI);
    end

endmodule


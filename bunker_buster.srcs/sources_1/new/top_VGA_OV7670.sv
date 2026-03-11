`timescale 1ns / 1ps

module top_VGA_OV7670 (
    input  logic       clk,
    input  logic       reset,
    // ov7670 side
    output logic       xclk,
    input  logic       pclk,
    input  logic       href,
    input  logic       vsync,
    input  logic [7:0] data,
    input  logic       mode_btn,    // btnU
    // vga port side
    output logic       h_sync,
    output logic       v_sync,
    output logic [3:0] port_red,
    output logic [3:0] port_green,
    output logic [3:0] port_blue,
    output logic       scl,
    inout  wire        sda,

    // board -> 힌트 PC Tx
    input  logic RsRx_hint,
    output logic RsTx_hint,

    // board -> UI PC Tx
    input  logic RsRx_UI,
    output logic RsTx_UI
);

    logic                       clk_100m;
    logic [                9:0] x_pixel;
    logic [                9:0] y_pixel;
    logic                       DE;
    logic [$clog2(320*240)-1:0] rAddr;
    logic [               16:0] imgData;
    logic                       we;
    logic [$clog2(320*240)-1:0] wAddr;
    logic [               15:0] wData;
    logic [               15:0] rData;
    logic [                7:0] w_tx_rdata;
    logic                       w_tx_empty;

    logic [                7:0] hint_data;
    logic [                3:0] hint_count;
    logic                       data_done;
    logic                       frame_done;
    logic [                7:0] target_data;
    logic                       bunker_detected;

    logic [                7:0] ui_pc_mux_out1;
    logic [                7:0] ui_pc_mux_out2;

    logic [                7:0] hint_pc_tx_mux_out1;
    logic [                7:0] hint_pc_tx_mux_out2;

    logic [                7:0] UI_pc_rx_data;
    logic                       UI_pc_rx_done;
    logic [                7:0] hint_pc_rx_data;
    logic                       hint_pc_rx_done;

    logic                       hint_tx_fifo_empty;
    logic [                7:0] hint_pc_tx_fifo_rdata;
    logic                       hint_tx_busy;

    logic o_mode_btn, game_mode;

    logic [7:0] btn_send_data;
    assign btn_send_data = 8'hDD;


    clk_wiz_0 instance_name (
        // Clock out ports
        .clk_out1(clk_100m),  // output clk_out1 100MHz
        .clk_out2(xclk),  // output clk_out2 25MHZ
        // Status and control signals
        .reset   (reset),     // input reset
        .locked  (locked),    // output locked
        // Clock in ports
        .clk_in1 (clk)    // input clk_in1
    );

    // ==================== 모드 변경 =========================
    btn_debouncer u_btn_debouncer (
        .clk  (clk_100m),
        .reset(reset),
        .i_btn(mode_btn),
        .o_btn(o_mode_btn)
    );

    mode_change u_mode_change (
        .clk(clk_100m),
        .reset(reset),
        .mode_btn(o_mode_btn),
        .game_mode(game_mode)
    );

    // ======================================================

    VGA_Decoder u_VGA_Decoder (
        .clk    (clk_100m),
        .reset  (reset),
        .pclk   (rclk),
        .h_sync (h_sync),
        .v_sync (v_sync),
        .x_pixel(x_pixel),
        .y_pixel(y_pixel),
        .DE     (DE)
    );

    imgMemReader u_imgMemReader (
        .DE        (DE),
        .x_pixel   (x_pixel),
        .y_pixel   (y_pixel),
        .addr      (rAddr),
        .imgData   (rData),
        .port_red  (port_red),
        .port_green(port_green),
        .port_blue (port_blue)
    );

    frameBuffer u_frameBuffer (
        .wclk (pclk),
        .we   (we),
        .wAddr(wAddr),
        .wData(wData),
        .rclk (rclk),
        .rAddr(rAddr),
        .rData(rData)
    );

    OV7670_MemController u_OV7670_MemController (
        .pclk (pclk),
        .reset(reset),
        .href (href),
        .vsync(vsync),
        .data (data),
        .we   (we),
        .wAddr(wAddr),
        .wData(wData)
    );
    // ----------------------------------------------------
    // ----------SCCB 동작 module---------------------------
    // ----------------------------------------------------
    SCCB_TOP u_SCCB_TOP (
        .clk  (clk_100m),
        .reset(reset),
        .scl  (scl),
        .sda  (sda)
    );

    // ----------------------------------------------------
    // ----------------------------------------------------

    // 카메라 Object Scaning 및 힌트 기반 타겟 지정
    Object_Scanner u_Object_Scanner (
        .pclk(pclk),  // 카메라 픽셀 클록 (25MHz)
        .reset(reset),
        .vsync(vsync),
        .we(we),
        .wData(wData),
        .rx_data(hint_pc_rx_data),
        .rx_done(hint_pc_rx_done),
        .hint_data(hint_data),  // [7:6]모양, [5:4]색상, [3:0]위치
        .hint_count(hint_count),  // 검출된 총 객체 수
        .data_done(data_done),  // 1 tick (데이터 1개 완성 트리거)
        .frame_done(frame_done),  // 1 tick (1프레임 완료 트리거)
        .bunker_detected(bunker_detected)
    );

    target_select u_target_select (
        .clk            (clk_100m),
        .reset          (reset),
        .hint_data      (hint_data),
        .hint_count     (hint_count),
        .data_done      (data_done),
        .frame_done     (frame_done),
        .bunker_detected(bunker_detected),
        .target_data    (target_data)
    );

    // ----------------------------------------------------
    // ----------Board -> UI PC 출력 tx 부분----------------
    // ----------------------------------------------------


    mux_nx1 #(
        .NUM  (2),
        .WIDTH(8)
    ) tx_fifo_src_mux1 (
        .sel(frame_done),
        .x  ({hint_data, target_data}),
        .y  (ui_pc_mux_out1)
    );

    mux_nx1 #(
        .NUM  (2),
        .WIDTH(8)
    ) tx_fifo_src_mux2 (
        .sel(first_btn_tick),
        .x  ({ui_pc_mux_out1, btn_send_data}),  // 8'hFA 는 바뀔 수 있음
        .y  (ui_pc_mux_out2)
    );

    FIFO u_UI_PCtx_fifo (
        .clk  (clk_100m),
        .reset(reset),
        .wr   (data_done| frame_done|second_btn_tick),
        .rd   (~w_tx_busy),
        .wdata(ui_pc_mux_out2),
        .rdata(w_tx_rdata),
        .full (),
        .empty(w_tx_empty)
    );

    uart_tx #(
        .BPS(9600)
    ) u_UI_uart_tx (
        .clk     (clk_100m),
        .reset   (reset),
        .tx_data (w_tx_rdata),
        .tx_start(~w_tx_empty),
        .tx      (RsTx_UI),
        .tx_busy (w_tx_busy)
    );


    uart_rx #(
        .BPS(9600)
    ) u_UI_uart_rx (
        .clk(clk_100m),
        .reset(reset),
        .rx(RsRx_UI),
        .data_out(UI_pc_rx_data),
        .rx_done(UI_pc_rx_done)
    );


    // -----------------------------------------------------
    // ----------Board -> 힌트 PC 출력 tx 부분-------------------
    // ------------------------------------------------------

    mux_nx1 #(
        .NUM  (2),
        .WIDTH(8)
    ) PC_hint_tx_fifo_src_mux1 (
        .sel(frame_done),
        .x  ({hint_data, target_data}),
        .y  (hint_pc_tx_mux_out1)
    );

    mux_nx1 #(
        .NUM  (2),
        .WIDTH(8)
    ) PC_hint_tx_fifo_src_mux2 (
        .sel(first_btn_tick),
        .x  ({hint_pc_tx_mux_out1, btn_send_data}),
        .y  (hint_pc_tx_mux_out2)
    );


    FIFO u_hint_pc_tx_fifo (
        .clk  (clk_100m),
        .reset(reset),
        .wr   (bunker_detected|frame_done|second_btn_tick),
        .rd   (~hint_tx_busy),
        .wdata(hint_pc_tx_mux_out2),
        .rdata(hint_pc_tx_fifo_rdata),
        .full (),
        .empty(hint_tx_fifo_empty)
    );

    uart_tx #(
        .BPS(9600)
    ) u_hint_pc_uart_tx (
        .clk     (clk_100m),
        .reset   (reset),
        .tx_data (hint_pc_tx_fifo_rdata),
        .tx_start(~hint_tx_fifo_empty),
        .tx      (RsTx_hint),
        .tx_busy (hint_tx_busy)
    );

    uart_rx #(
        .BPS(9600)
    ) u_hint_pc_uart_rx (
        .clk(clk_100m),
        .reset(reset),
        .rx(RsRx_hint),
        .data_out(hint_pc_rx_data),
        .rx_done(hint_pc_rx_done)
    );

endmodule

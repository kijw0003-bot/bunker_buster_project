`timescale 1ns / 1ps

module top_VGA_ov7670_f (
    input logic clk,
    input logic reset,
    // ov7670 side
    output logic xclk,
    input logic pclk,
    input logic href,
    input logic vsync,
    input logic [7:0] data,
    // vga port side
    output logic h_sync,
    output logic v_sync,
    output logic [3:0] port_red,
    output logic [3:0] port_green,
    output logic [3:0] port_blue,

    output logic [15:0] led,
    // output logic uart_tx_pin,

    output logic SCL,
    inout  wire  SDA,


    // 추가 한거      
    input logic mode_btn,  // btnU

    // board -> 힌트 PC Tx
    input  logic RsRx_hint,
    output logic RsTx_hint,

    // board -> UI PC Tx
    input  logic RsRx_UI,
    output logic RsTx_UI



);
    logic                         clk_100m;
    logic [                  9:0] x_pixel;
    logic [                  9:0] y_pixel;
    logic                         DE;
    logic                         rclk;
    logic [$clog2(320*240)-1 : 0] rAddr;
    logic [                 15:0] rData;
    logic [$clog2(320*240)-1 : 0] wAddr;
    logic [                 15:0] wData;
    logic [                  7:0] hint_data;
    logic [                  3:0] hint_count;
    logic                         data_done;
    logic                         frame_done;
    logic [                  3:0] w_red;
    logic [                  3:0] w_green;
    logic [                  3:0] w_blue;
    logic [7:0] w_h, w_s, w_v;

    logic       locked;

    // 추가 wire

    logic [7:0] target_data;
    logic       bunker_detected;

    logic [7:0] ui_pc_mux_out1;
    logic [7:0] ui_pc_mux_out2;
    logic [7:0] ui_pc_mux_out3;

    logic [7:0] hint_pc_tx_mux_out1;
    logic [7:0] hint_pc_tx_mux_out2;
    logic [7:0] hint_pc_tx_mux_out3;

    logic [7:0] UI_pc_rx_data;
    logic       UI_pc_rx_done;
    logic [7:0] hint_pc_rx_data;
    logic       hint_pc_rx_done;

    logic       hint_tx_fifo_empty;
    logic [7:0] hint_pc_tx_fifo_rdata;
    logic       hint_tx_busy;

    logic o_mode_btn, game_mode;
    logic       camera_start;
    logic       game_ing;

    logic [7:0] w_tx_rdata;
    logic       w_tx_empty;

    logic       we;

    logic [7:0] btn_send_data;
    assign btn_send_data = 8'hDD;


    logic [3:0] w_filter_R;
    logic [3:0] w_filter_G;
    logic [3:0] w_filter_B;

    logic one_red_undetected;


    clk_wiz_1 instance_name (
        // Clock out ports
        .clk_out1(clk_100m),  // output clk_out1
        .clk_out2(xclk),  // output clk_out2
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

    receive_done_signal u_receive_done_signal (
        .clk            (clk_100m),
        .reset          (reset),
        .o_mode_btn     (o_mode_btn),
        .game_mode      (game_mode),
        .game_ing       (game_ing),
        .bunker_detected(bunker_detected),
        .UI_pc_rx_data  (UI_pc_rx_data),
        .UI_pc_rx_done  (UI_pc_rx_done),
        .hint_pc_rx_data(hint_pc_rx_data),
        .hint_pc_rx_done(hint_pc_rx_done),
        .frame_done     (frame_done),
        .camera_start   (camera_start)
    );

    // ======================================================




    VGA_Decoder U_decoder (
        .clk(clk_100m),
        .reset(reset),
        .pclk(rclk),
        .h_sync(h_sync),
        .v_sync(v_sync),
        .x_pixel(x_pixel),
        .y_pixel(y_pixel),
        .DE(DE)
    );

    imgMemReader U_FBuffReader (
        .DE(DE),
        .x_pixel(x_pixel),
        .y_pixel(y_pixel),
        .addr(rAddr),
        .imgData(rData),
        .port_red(w_red),
        .port_green(w_green),
        .port_blue(w_blue)
    );


    //   image_buffer u_image_buffer (
    //     .addr(rAddr),
    //     .data(rData)
    // );



    Framebuffer U_FrameBuffer (
        .wclk(pclk),
        .we(we),
        .wAddr(wAddr),
        .wData(wData),
        .rclk(clk_100m),
        .rAddr(rAddr),
        .rData(rData)
    );

    OV7670_MemController U_OV7670_MemController (
        .pclk(pclk),
        .reset(reset),
        .href(href),
        .vsync(vsync),
        .data(data),
        .we(we),
        .wAddr(wAddr),
        .wData(wData)
    );


    // ----------------------------------------------------
    // ----------SCCB 동작 module---------------------------
    // ----------------------------------------------------

    SCCB_TOP u_sccb (

        .clk  (clk_100m),
        .reset(reset),
        .scl  (SCL),
        .sda  (SDA)
    );


    // ----------------------------------------------------
    // ----------------------------------------------------

    // assign port_red   = w_red;
    // assign port_green = w_green;
    // assign port_blue  = w_blue;

    logic out_de;
    logic [9:0] out_x_pixel, out_y_pixel;



    HSV_object_scanner u_scanner (
        .clk               (clk_100m),
        .reset             (reset),
        .DE                (out_de),
        .o_mode_btn        (o_mode_btn),
        .x_pixel           (out_x_pixel),
        .y_pixel           (out_y_pixel),
        .H                 (w_h),
        .S                 (w_s),
        .V                 (w_v),
        .camera_start      (camera_start),
        .hint_data         (hint_data),
        .one_red_undetected(one_red_undetected),
        .debug_led         (led),
        .data_done         (data_done),
        .bunker_detected   (bunker_detected),
        .frame_done        (frame_done),
        .game_ing          (game_ing),
        .signal_data       (signal_data)
    );

    HSV u_hsv (
        .clk(clk_100m),
        .reset(reset),
        .DE_in(DE),
        .x_in(x_pixel),
        .y_in(y_pixel),
        .R(w_red),
        .G(w_green),
        .B(w_blue),
        .DE_out(out_de),
        .x_out(out_x_pixel),
        .y_out(out_y_pixel),
        .H(w_h),
        .S(w_s),
        .V(w_v)
    );


    target_select u_target_select (
        .clk               (clk_100m),
        .reset             (reset),
        .o_mode_btn        (o_mode_btn),
        .hint_data         (hint_data),
        .data_done         (data_done),
        .frame_done        (frame_done),
        .one_red_undetected(one_red_undetected),
        .bunker_detected   (bunker_detected),
        .target_data       (target_data)
    );


    // ----------------------------------------------------
    // ----------Board -> UI PC 출력 tx 부분----------------
    // ----------------------------------------------------

    logic       delay_trigger;
    logic [7:0] hint_data_reg;

    always_ff @(posedge clk_100m or posedge reset) begin
        if (reset) begin
            delay_trigger <= 0;
            hint_data_reg <= 0;
        end else begin
            delay_trigger <= signal_data;
            hint_data_reg <= hint_data;
        end
    end


    mux_nx1 #(
        .NUM  (2),
        .WIDTH(8)
    ) tx_fifo_src_mux1 (
        .sel((frame_done && game_ing) && !signal_data),
        .x  ({hint_data, target_data}),
        .y  (ui_pc_mux_out1)
    );

    mux_nx1 #(
        .NUM  (2),
        .WIDTH(8)
    ) tx_fifo_src_mux3 (
        .sel(delay_trigger),
        .x  ({ui_pc_mux_out1, {4'b1111, hint_data_reg[3:0]}}),
        .y  (ui_pc_mux_out3)
    );

    mux_nx1 #(
        .NUM  (2),
        .WIDTH(8)
    ) tx_fifo_src_mux2 (
        .sel(o_mode_btn),
        .x  ({ui_pc_mux_out3, btn_send_data}),
        .y  (ui_pc_mux_out2)
    );



    FIFO u_UI_PC_tx_fifo (
        .clk(clk_100m),
        .reset(reset),
        .wr   ( (data_done && !bunker_detected)|| (frame_done && game_ing)||o_mode_btn || (~game_ing && bunker_detected) ||delay_trigger),
        .rd(~w_tx_busy),
        .wdata(ui_pc_mux_out2),
        .rdata(w_tx_rdata),
        .full(),
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
        .sel((frame_done && game_ing) && !(~game_ing && bunker_detected)),
        .x  ({hint_data, target_data}),
        .y  (hint_pc_tx_mux_out1)
    );

    mux_nx1 #(
        .NUM  (2),
        .WIDTH(8)
    ) PC_hint_tx_fifo_src_mux3 (
        .sel(signal_data),
        .x  ({hint_pc_tx_mux_out1, {4'b1111, hint_data[3:0]}}),
        .y  (hint_pc_tx_mux_out3)
    );

    mux_nx1 #(
        .NUM  (2),
        .WIDTH(8)
    ) PC_hint_tx_fifo_src_mux2 (
        .sel(o_mode_btn),
        .x  ({hint_pc_tx_mux_out3, btn_send_data}),
        .y  (hint_pc_tx_mux_out2)
    );


    FIFO u_hint_pc_tx_fifo (
        .clk(clk_100m),
        .reset(reset),
        .wr   ( (bunker_detected||(frame_done && game_ing)||o_mode_btn)&& !delay_trigger),
        .rd(~hint_tx_busy),
        .wdata(hint_pc_tx_mux_out2),
        .rdata(hint_pc_tx_fifo_rdata),
        .full(),
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

    // 카메라 ui
    VGA_Grid_Filter U_grid_filter (
        .x_pixel(x_pixel),
        .y_pixel(y_pixel),
        .DE(DE),
        .raw_R(w_red),
        .raw_G(w_green),
        .raw_B(w_blue),
        .filter_R(w_filter_R),
        .filter_G(w_filter_G),
        .filter_B(w_filter_B)
    );

    camera_ui u_camera_ui (
        .clk(clk_100m),
        .reset(reset),
        .DE(DE),
        .x_pixel(x_pixel),
        .y_pixel(y_pixel),
        .in_R(w_filter_R),
        .in_G(w_filter_G),
        .in_B(w_filter_B),
        .hint_data(hint_data),
        .data_done(data_done),
        .frame_done(frame_done),
        .out_R(port_red),
        .out_G(port_green),
        .out_B(port_blue)
    );



endmodule


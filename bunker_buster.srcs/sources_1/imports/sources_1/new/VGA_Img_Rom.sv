`timescale 1ns / 1ps



module VGA_Img_Rom (
    input  logic       clk,
    input  logic       reset,
    input  logic       sw_scale,
    input  logic [2:0] sw_scale_mode,
    output logic       h_sync,
    output logic       v_sync,
    output logic [3:0] port_red,
    output logic [3:0] port_green,
    output logic [3:0] port_blue
);
    logic [                9:0] x_pixel;
    logic [                9:0] y_pixel;
    logic                       DE;
    logic [$clog2(320*240)-1:0] addr;
    logic [$clog2(320*240)-1:0] addr_origin;
    logic [$clog2(320*240)-1:0] addr_upscale;
    logic [               15:0] data;
    logic [               15:0] data_origin;
    logic [               15:0] data_upscale;

    logic [                3:0] port_red_origin;
    logic [                3:0] port_green_origin;
    logic [                3:0] port_blue_origin;
    logic [                3:0] port_red_upscale;
    logic [                3:0] port_green_upscale;
    logic [                3:0] port_blue_upscale;
    logic [               11:0] rgb;
    logic [               11:0] rgb_gray;
    logic [               11:0] rgb_red_only;
    logic [               11:0] rgb_green_only;
    logic [               11:0] rgb_blue_only;
    logic [               11:0] rgb_negative;

    mux #(
        .WIDTH($clog2(320 * 240))
    ) u_mux (
        .sel(sw_scale),
        .x  ({addr_origin, addr_upscale}),
        .y  (addr)
    );

    imgROM u_imgROM (.*);

    VGA_Decoder u_VGA_Decoder (.*);

    imgMemReader u_imgMemReader_Origin (
        .*,
        .addr(addr_origin),
        .imgData(data_origin),
        .port_red(port_red_origin),
        .port_green(port_green_origin),
        .port_blue(port_blue_origin)
    );
    demux #(
        .WIDTH(16)
    ) u_demux (
        .sel(sw_scale),
        .y  (data),
        .x0 (data_origin),
        .x1 (data_upscale)
    );

    imgMemReader_upscale u_imgMemReader_upscale (
        .*,
        .addr(addr_upscale),
        .imgData(data_upscale),
        .port_red(port_red_upscale),
        .port_green(port_green_upscale),
        .port_blue(port_blue_upscale)
    );


    mux #(
        .WIDTH(12)
    ) u_mux_outport (
        .sel(sw_scale),
        .x({
            {port_red_origin, port_green_origin, port_blue_origin},
            {port_red_upscale, port_green_upscale, port_blue_upscale}
        }),
        .y(rgb)
    );


    gray_scale_filter u_gray_scale_filter (

        .i_rgb(rgb),
        .o_rgb(rgb_gray)
    );

    red_only_filter u_red_only_filter (
        .i_rgb(rgb),
        .o_rgb(rgb_red_only)
    );

    green_only_filter u_green_only_filter (
        .i_rgb(rgb),
        .o_rgb(rgb_green_only)
    );

    blue_only_filter u_blue_only_filter (
        .i_rgb(rgb),
        .o_rgb(rgb_blue_only)
    );

    negative_filter U_negative_filter (
        .*,
        .i_rgb(rgb),
        .sw(sw_scale),
        .o_rgb(rgb_negative)
    );
    mux #(
        .WIDTH(12),
        .N(6)
    ) U_MUX_GRAY (
        .sel(sw_scale_mode),
        .x({
            rgb,
            rgb_gray,
            rgb_red_only,
            rgb_green_only,
            rgb_blue_only,
            rgb_negative
        }),
        .y({port_red, port_green, port_blue})
    );
endmodule

module mux #(
    parameter WIDTH = 12,
    parameter N = 2
) (
    input  logic [$clog2(N)-1:0] sel,
    input  logic [ WIDTH -1 : 0] x  [N],
    output logic [ WIDTH -1 : 0] y
);
    assign y = x[sel];

endmodule

module demux #(
    parameter WIDTH = 12
) (
    input  logic                sel,
    input  logic [WIDTH -1 : 0] y,
    output logic [WIDTH -1 : 0] x0,
    output logic [WIDTH -1 : 0] x1
);

    always_comb begin
        x0 = 0;
        x1 = 0;
        case (sel)
            1'b0: x0 = y;
            1'b1: x1 = y;
        endcase
    end

endmodule

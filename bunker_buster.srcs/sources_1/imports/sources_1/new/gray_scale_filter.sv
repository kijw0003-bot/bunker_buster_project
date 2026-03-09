`timescale 1ns / 1ps

module gray_scale_filter (
    input  logic [11:0] i_rgb,
    output logic [11:0] o_rgb
);
    logic [11:0] gray;

    assign gray  = 51 * i_rgb[11:8] + 179 * i_rgb[7:4] + 26 * i_rgb[3:0]; // r g b 순서
    assign o_rgb = {gray[11:8], gray[11 : 8], gray[11:8]};
endmodule

module red_only_filter (
    input  logic [11:0] i_rgb,
    output logic [11:0] o_rgb
);

    assign o_rgb = {i_rgb[11:8], 4'd0, 4'd0};
endmodule

module green_only_filter (
    input  logic [11:0] i_rgb,
    output logic [11:0] o_rgb
);

    assign o_rgb = {4'd0, i_rgb[7:4], 4'd0};
endmodule

module blue_only_filter (
    input  logic [11:0] i_rgb,
    output logic [11:0] o_rgb
);

    assign o_rgb = {4'd0, 4'd0, i_rgb[3:0]};
endmodule

module negative_filter (
    input  logic [11:0] i_rgb,
    input  logic        DE,
    input  logic        sw,
    input  logic [ 9:0] x_pixel,
    input  logic [ 9:0] y_pixel,
    output logic [11:0] o_rgb
);
    logic [3:0] red_negative_rgb, green_negative_rgb, blue_negative_rgb;
    logic qvga_de;
    assign qvga_de = sw ? DE : (DE && (x_pixel < 320) && (y_pixel < 240));

    assign red_negative_rgb = ~i_rgb[11:8];
    assign green_negative_rgb = ~i_rgb[7:4];
    assign blue_negative_rgb = ~i_rgb[3:0];

    assign o_rgb = qvga_de ? {red_negative_rgb, green_negative_rgb, blue_negative_rgb} : 0;

endmodule

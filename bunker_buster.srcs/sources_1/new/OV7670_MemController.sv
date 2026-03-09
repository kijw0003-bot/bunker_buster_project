`timescale 1ns / 1ps


module OV7670_MemController (
    input  logic                       pclk,
    input  logic                       reset,
    // OV7670 side
    input  logic                       href,
    input  logic                       vsync,
    input  logic [                7:0] data,
    // mem side
    output logic                       we,
    output logic [$clog2(320*240)-1:0] wAddr,
    output logic [               15:0] wData
);

    logic [15:0] pixelData;
    logic pixelEvenOdd;

    assign wData = pixelData;
    always_ff @(posedge pclk or posedge reset) begin
        if (reset) begin
            pixelData    <= 0;
            pixelEvenOdd <= 0;
            we           <= 0;
            wAddr        <= 0;
        end else begin
            if (href) begin
                if (pixelEvenOdd == 1'b0) begin
                    we <= 1'b0;
                    pixelData[15:8] <= data;
                    pixelEvenOdd <= ~pixelEvenOdd;
                end else begin
                    we <= 1'b1;
                    pixelData[7:0] <= data;
                    pixelEvenOdd <= ~pixelEvenOdd;
                    wAddr <= wAddr + 1;
                end
            end else if (vsync) begin
                pixelEvenOdd <= 0;
                we           <= 0;
                wAddr        <= 0;
            end


        end
    end




endmodule

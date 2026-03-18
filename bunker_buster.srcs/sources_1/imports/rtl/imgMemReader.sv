`timescale 1ns / 1ps

module imgMemReader (
    input  logic                       DE,
    input  logic [                9:0] x_pixel,
    input  logic [                9:0] y_pixel,
    output logic [$clog2(320*240)-1:0] addr,
    input  logic [               15:0] imgData,
    output logic [                3:0] port_red,
    output logic [                3:0] port_green,
    output logic [                3:0] port_blue
);
    // logic qvga_de;


    // assign qvga_de = DE && (x_pixel < 320) && (y_pixel < 240);
    assign addr = DE ? (320 * y_pixel[9:1] + x_pixel[9:1]) : 'bz;
    assign {port_red, port_green, port_blue} = DE ? {imgData[15:12], imgData[10:7], imgData[4:1]} : 0;

endmodule

module ImgMemReader_upscaler (
    input  logic                       DE,
    input  logic [                9:0] x_pixel,
    input  logic [                9:0] y_pixel,
    output logic [$clog2(320*240)-1:0] addr,
    input  logic [               15:0] imgData,
    output logic [                3:0] port_red,
    output logic [                3:0] port_green,
    output logic [                3:0] port_blue
);

    assign addr = DE ? (320 * y_pixel[9:1] + x_pixel[9:1]) : 'bz;
    assign {port_red, port_green, port_blue} = DE ? {imgData[15:12], imgData[10:7], imgData[4:1]} : 0;

endmodule

module VGA_Grid_Filter (
    input  logic [9:0] x_pixel,  
    input  logic [9:0] y_pixel,  
    input  logic       DE,       
    input  logic [3:0] raw_R,    
    input  logic [3:0] raw_G,    
    input  logic [3:0] raw_B,    
    
    output logic [3:0] filter_R, 
    output logic [3:0] filter_G, 
    output logic [3:0] filter_B  
);

    logic is_grid_line;

    always_comb begin
        if (!DE) begin
            is_grid_line = 1'b0;
        end
        else begin
            
            // 64, 128, 192, 256
            if (x_pixel == 128 || x_pixel == 256 || x_pixel == 384 || x_pixel == 512) begin
                is_grid_line = 1'b1;
            end
         
            // 80, 160
            else if (y_pixel == 160 || y_pixel == 320) begin
                is_grid_line = 1'b1;
            end
            else begin
                is_grid_line = 1'b0;
            end
        end
    end

    //  최종 출력 선택
    always_comb begin
        if (is_grid_line) begin
            // 격자 선 위치라면 흰색(White) 출력
            filter_R = 4'hF; 
            filter_G = 4'hF;
            filter_B = 4'hF;
        end
        else begin
            // 그 외에는 원본 카메라 화면 출력
            filter_R = raw_R;
            filter_G = raw_G;
            filter_B = raw_B;
        end
    end

endmodule



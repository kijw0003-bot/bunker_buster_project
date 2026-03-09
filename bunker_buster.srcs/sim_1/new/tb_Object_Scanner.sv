// `timescale 1ns / 1ps



// module tb_Object_Scanner ();

//     logic        pclk;  // 카메라 픽셀 클록 (25MHz)
//     logic        reset;
//     logic        vsync;
//     logic        we;
//     logic [15:0] wData;



//     logic [ 7:0] hint_data;  // [7:6]모양, [5:4]색상, [3:0]위치
//     logic [ 3:0] hint_count;  // 검출된 총 객체 수
//     logic        data_done;  // 1 tick (데이터 1개 완성 트리거)
//     logic        frame_done;  // 1 tick (1프레임 완료 트리거)

//     logic [ 9:0] x;
//     logic [ 9:0] y;

//     Object_Scanner dut (.*);

//     always #5 pclk = ~pclk;

//     assign vsync = !(x < 320 && y < 240);

//     initial begin
//         pclk  = 0;
//         reset = 1;
//         #10 reset = 0;
//         x = 0;
//         y = 250;
//         #10;
//         insert_data(16'b11110000000000);  //  빨간색
//         #300;
//         // insert_data(16'b11110000000000); //  빨간색
//         // insert_data(16'b11110000000000); //  빨간색
//         $stop;

//     end
//     task insert_data(logic [15:0] color);
//         x = 0;
//         y = 0;
//         while (1) begin
//             @(posedge pclk);
//             #1;
//             we = 1;
//             if (x >= 128 && x < 192 && y >= 80 && y < 160) begin
//                 wData = color;
//             end else begin
//                 wData = 0;
//             end


//             @(posedge pclk);
//             #1;
//             we = 0;

//             // if (x > 320 && y > 240) begin
//             //     y = 250;
//             //     @(posedge pclk);
//             //     @(posedge pclk);
//             //     @(posedge pclk);

//             //     return;
//             // end
//             if (x < 320 - 1) begin
//                 x++;
//             end else begin
//                 x = 0;
//                 if (y < 250 - 1) begin
//                     y++;

//                 end else begin
//                     return;
//                 end
//             end
//         end

//     endtask  //
// endmodule

`timescale 1ns / 1ps

module tb_Object_Scanner;

    //////////////////////////////////////////////////////////
    // DUT I/O
    //////////////////////////////////////////////////////////

    logic pclk;
    logic reset;

    logic vsync;
    logic we;
    logic [15:0] wData;

    logic [7:0] hint_data;
    logic [3:0] hint_count;
    logic data_done;
    logic frame_done;

    int px, py, dx, dy, rx, ry;
    //////////////////////////////////////////////////////////
    // DUT
    //////////////////////////////////////////////////////////

    Object_Scanner dut (
        .pclk(pclk),
        .reset(reset),
        .vsync(vsync),
        .we(we),
        .wData(wData),
        .hint_data(hint_data),
        .hint_count(hint_count),
        .data_done(data_done),
        .frame_done(frame_done)
    );

    //////////////////////////////////////////////////////////
    // Clock (25MHz)
    //////////////////////////////////////////////////////////

    initial pclk = 0;
    always #20 pclk = ~pclk;

    //////////////////////////////////////////////////////////
    // Frame buffer (TB용)
    //////////////////////////////////////////////////////////

    logic [15:0] frame_mem[0:239][0:319];

    //////////////////////////////////////////////////////////
    // 색 정의
    //////////////////////////////////////////////////////////

    localparam RED = 16'hF800;
    localparam GREEN = 16'h07E0;
    localparam BLUE = 16'h001F;
    localparam YELLOW = 16'hFFE0;
    localparam BLACK = 16'h0000;

    //////////////////////////////////////////////////////////
    // Frame 초기화
    //////////////////////////////////////////////////////////

    task clear_frame;
        int x, y;
        begin
            for (y = 0; y < 240; y++)
            for (x = 0; x < 320; x++) frame_mem[y][x] = BLACK;
        end
    endtask

    //////////////////////////////////////////////////////////
    // 사각형 객체 생성
    //////////////////////////////////////////////////////////

    task draw_square(input int cx, input int cy, input int size,
                     input [15:0] color);
        int x, y;
        begin

            for (y = cy - size; y <= cy + size; y++)
            for (x = cx - size; x <= cx + size; x++)
            if (x >= 0 && x < 320 && y >= 0 && y < 240) frame_mem[y][x] = color;

        end
    endtask

    //////////////////////////////////////////////////////////
    // 원 생성
    //////////////////////////////////////////////////////////

    task draw_circle(input int cx, input int cy, input int r,
                     input [15:0] color);
        int x, y;
        begin

            for (y = cy - r; y <= cy + r; y++)
            for (x = cx - r; x <= cx + r; x++) begin
                if (x >= 0 && x < 320 && y >= 0 && y < 240) begin
                    dx = x - cx;
                    dy = y - cy;

                    if (dx * dx + dy * dy <= r * r) frame_mem[y][x] = color;
                end
            end

        end
    endtask

    //////////////////////////////////////////////////////////
    // 삼각형 생성
    //////////////////////////////////////////////////////////

    task draw_triangle(input int cx, input int cy, input int size,
                       input [15:0] color);
        int x, y;
        begin

            for (y = 0; y < size; y++) begin
                for (x = -y; x <= y; x++) begin
                    px = cx + x;
                    py = cy + y;

                    if (px >= 0 && px < 320 && py >= 0 && py < 240)
                        frame_mem[py][px] = color;
                end
            end

        end
    endtask

    //////////////////////////////////////////////////////////
    // 프레임 전송
    //////////////////////////////////////////////////////////

    task send_frame;

        int x, y;

        begin

            // frame start
            @(negedge pclk);
            vsync = 1;
            repeat (5) @(posedge pclk);
            #1;
            vsync = 0;

            for (y = 0; y < 240; y++) begin
                for (x = 0; x < 320; x++) begin

                    @(posedge pclk);

                    we    <= 1;
                    wData <= frame_mem[y][x];

                end
            end

            @(posedge pclk);
            we <= 0;

            // frame end
            @(posedge pclk);
            #1;
            vsync <= 1;

        end
    endtask

    //////////////////////////////////////////////////////////
    // 결과 모니터
    //////////////////////////////////////////////////////////

    always @(posedge pclk) begin
        if (data_done) begin
            $display("Detected Object : hint_data = %b", hint_data);
        end
    end

    always @(posedge pclk) begin
        if (frame_done) begin
            $display("Frame Done : object count = %d", hint_count);
        end
    end

    //////////////////////////////////////////////////////////
    // 테스트 시나리오
    //////////////////////////////////////////////////////////

    initial begin

        reset = 1;
        vsync = 1;
        we    = 0;
        wData = 0;

        repeat (20) @(posedge pclk);
        reset = 0;

        //////////////////////////////////////////////////////
        // TEST 1 : 중앙 빨간 네모
        //////////////////////////////////////////////////////

        clear_frame();

        draw_square(160,  // center x
                    120,  // center y
                    20,  // size
                    RED);

        send_frame();

        wait (frame_done);

        //////////////////////////////////////////////////////
        // TEST 2 : 여러 객체
        //////////////////////////////////////////////////////

        clear_frame();

        draw_square(80, 60, 20, RED);
        draw_circle(200, 100, 20, BLUE);
        draw_triangle(150, 160, 20, GREEN);

        send_frame();

        wait (frame_done);

        //////////////////////////////////////////////////////
        // TEST 3 : 랜덤 객체
        //////////////////////////////////////////////////////

        clear_frame();

        repeat (5) begin
            rx = $urandom_range(50, 270);
            ry = $urandom_range(50, 190);

            draw_square(rx, ry, 15, RED);
        end

        send_frame();

        wait (frame_done);

        #2000;

        $stop;

    end

endmodule

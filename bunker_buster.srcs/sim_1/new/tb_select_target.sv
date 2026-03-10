`timescale 1ns / 1ps
`include "define.vh"

module tb_target_select;

    //---------------------------------------
    // DUT signals
    //---------------------------------------
    logic clk;
    logic reset;

    logic [7:0] hint_data;
    logic [3:0] hint_count;
    logic data_done;
    logic frame_done;
    logic bunker_detected;

    logic [7:0] target_data;

    //---------------------------------------
    // DUT
    //---------------------------------------
    target_select dut (
        .clk  (clk),
        .reset(reset),

        .hint_data(hint_data),
        .hint_count(hint_count),
        .data_done(data_done),
        .frame_done(frame_done),
        .bunker_detected(bunker_detected),

        .target_data(target_data)
    );

    //---------------------------------------
    // clock
    //---------------------------------------
    initial clk = 0;
    always #5 clk = ~clk;  // 100MHz

    //---------------------------------------
    // reset
    //---------------------------------------
    initial begin
        reset = 1;
        hint_data = 0;
        hint_count = 0;
        data_done = 0;
        frame_done = 0;
        bunker_detected = 0;

        #20;
        reset = 0;
    end

    //-------------------------------------------------
    // task : frame 시작 (힌트 개수 전달)
    //-------------------------------------------------
    task send_frame_start(input [3:0] count);
        begin
            @(posedge clk);
            hint_count = count;
            frame_done = 1;

            @(posedge clk);
            frame_done = 0;
        end
    endtask


    //-------------------------------------------------
    // task : hint 전송
    //-------------------------------------------------
    task send_hint(input [1:0] shape, input [1:0] color, input [3:0] section);
        begin

            hint_data = {shape, color, section};

            @(posedge clk);
            data_done = 1;

            @(posedge clk);
            data_done = 0;

            repeat (10) @(posedge clk);
        end
    endtask


    //-------------------------------------------------
    // task : bunker detection
    //-------------------------------------------------
    task send_bunker();
        begin
            @(posedge clk);
            bunker_detected = 1;
            data_done       = 1;
            @(posedge clk);
            bunker_detected = 0;
            data_done       = 0;
            repeat (10) @(posedge clk);
        end
    endtask


    //---------------------------------------
    // Simulation Scenario
    //---------------------------------------
    initial begin

        wait (!reset);

        //-------------------------------------------------
        // frame 시작
        //-------------------------------------------------
        send_frame_start(4);

        //-------------------------------------------------
        // hint 입력
        //-------------------------------------------------

        // green circle at section 5
        send_hint(`CIRCLE, `GREEN, `SECTION_5);

        // blue triangle at section 8
        send_hint(`TRIANGLE, `BLUE, `SECTION_8);

        // yellow circle at section 12
        send_hint(`CIRCLE, `YELLOW, `SECTION_12);

        //-------------------------------------------------
        // bunker detection
        //-------------------------------------------------
        send_bunker();

        //-------------------------------------------------
        // 추가 hint
        //-------------------------------------------------
        send_hint(`CIRCLE, `GREEN, `SECTION_7);

        //-------------------------------------------------
        // simulation 종료
        //-------------------------------------------------
        #200;

        $finish;

    end

endmodule

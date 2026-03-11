`timescale 1ns / 1ps

module tb_receive_done_signal;

    logic clk;
    logic reset;

    logic game_mode;
    logic bunker_detected;

    logic [7:0] UI_pc_rx_data;
    logic UI_pc_rx_done;

    logic [7:0] hint_pc_rx_data;
    logic hint_pc_rx_done;

    logic frame_done;

    logic camera_start;

    //-------------------------------------------------
    // DUT
    //-------------------------------------------------

    receive_done_signal dut (
        .clk(clk),
        .reset(reset),
        .game_mode(game_mode),
        .bunker_detected(bunker_detected),
        .UI_pc_rx_data(UI_pc_rx_data),
        .UI_pc_rx_done(UI_pc_rx_done),
        .hint_pc_rx_data(hint_pc_rx_data),
        .hint_pc_rx_done(hint_pc_rx_done),
        .frame_done(frame_done),
        .camera_start(camera_start)
    );

    //-------------------------------------------------
    // clock
    //-------------------------------------------------

    initial clk = 0;
    always #5 clk = ~clk;  // 100MHz

    //-------------------------------------------------
    // reset
    //-------------------------------------------------

    initial begin
        reset = 1;

        game_mode = 0;
        bunker_detected = 0;

        UI_pc_rx_data = 0;
        UI_pc_rx_done = 0;

        hint_pc_rx_data = 0;
        hint_pc_rx_done = 0;

        frame_done = 0;

        #20;
        reset = 0;
    end

    //-------------------------------------------------
    // helper tasks
    //-------------------------------------------------

    task send_hint_frame_done;
        begin
            hint_pc_rx_data = 8'hFF;
            hint_pc_rx_done = 1;
            #10;
            hint_pc_rx_done = 0;
        end
    endtask

    task send_UI_frame_done;
        begin
            UI_pc_rx_data = 8'hFF;
            UI_pc_rx_done = 1;
            #10;
            UI_pc_rx_done = 0;
        end
    endtask

    task trigger_frame;
        begin
            frame_done = 1;
            #10;
            frame_done = 0;
        end
    endtask

    //-------------------------------------------------
    // TEST SCENARIO
    //-------------------------------------------------

    initial begin

        wait (!reset);

        //-----------------------------------------
        // 1️⃣ IDLE -> RECEIVE
        //-----------------------------------------

        $display("TEST1 : IDLE -> RECEIVE");

        trigger_frame();

        #20;

        //-----------------------------------------
        // 2️⃣ RECEIVE -> TARGET_SELECT (game_mode=0)
        //-----------------------------------------

        $display("TEST2 : RECEIVE -> TARGET_SELECT (hint only)");

        send_hint_frame_done();

        #20;

        //-----------------------------------------
        // 3️⃣ TARGET_SELECT -> IDLE (bunker_detected)
        //-----------------------------------------

        $display("TEST3 : TARGET_SELECT -> IDLE");

        bunker_detected = 1;
        #10;
        bunker_detected = 0;

        #20;

        //-----------------------------------------
        // 4️⃣ game_mode = 1 테스트
        //-----------------------------------------

        $display("TEST4 : game_mode = 1");

        game_mode = 1;

        trigger_frame();  // IDLE -> RECEIVE

        #20;

        send_hint_frame_done();
        #20;

        send_UI_frame_done();

        #20;

        //-----------------------------------------
        // 5️⃣ TARGET_SELECT frame 반복
        //-----------------------------------------

        $display("TEST5 : TARGET_SELECT -> RECEIVE");

        trigger_frame();

        #50;

        $finish;

    end

endmodule

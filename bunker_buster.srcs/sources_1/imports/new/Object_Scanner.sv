`timescale 1ns / 1ps
`include "define.vh"

module Object_Scanner (
    input logic pclk,  // 카메라 픽셀 클록 (25MHz)
    input logic reset,

    // OV7670_MemController에서 가로챈 신호
    input logic        vsync,
    input logic        we,
    input logic [15:0] wData,

    // 실제 합성때는 삭제
    // output logic [3:0] debug_led,
    // output logic [2:0] debug_shape_led,

    // ---------------- 상대 모듈 인터페이스 ----------------
    input logic rx_done,
    input logic [7:0] rx_data,
    output logic bunker_detected,
    output logic [7:0] hint_data,  // [7:6]모양, [5:4]색상, [3:0]위치
    output logic [3:0] hint_count,  // 검출된 총 객체 수
    output logic data_done,  // 1 tick (데이터 1개 완성 트리거)
    output logic frame_done  // 1 tick (1프레임 완료 트리거)

);

    // 거리 허용 오차 (이 픽셀 수 이내에 같은 색이 있으면 같은 객체로 묶음)
    localparam MARGIN = 5;
    localparam FRAME_ACTION = 8'h7E;  // 0111 1110

    logic [5:0] r6, g6, b6;
    logic [5:0] max_c, min_c;
    logic [6:0] sat_diff;  // 채도 유사 지표 = max - min
    logic [7:0] lum_sum;  // 밝기 유사 지표 = r+g+b

    // -----------------------------------------------------------------
    // 1. 색상 검출 (Combinational)
    // -----------------------------------------------------------------
    logic [4:0] R, B;
    logic [5:0] G;
    assign {R, G, B} = {wData[15:11], wData[10:5], wData[4:0]};
    assign r6 = {R, R[4]};  // 5bit -> 6bit 확장
    assign g6 = G;
    assign b6 = {B, B[4]};  // 5bit -> 6bit 확장

    logic [1:0] cur_color;
    logic       is_colored;

    always_comb begin
        // 기본값: 색 없음
        is_colored = 1'b0;
        cur_color = 2'b00;

        // max / min 계산
        max_c = r6;
        if (g6 > max_c) max_c = g6;
        if (b6 > max_c) max_c = b6;

        min_c = r6;
        if (g6 < min_c) min_c = g6;
        if (b6 < min_c) min_c = b6;

        // 밝기/채도 계산
        sat_diff = max_c - min_c;
        lum_sum  = r6 + g6 + b6;

        // ---------------------------------------------------------
        // 1) 너무 어두운 픽셀 제거
        // 2) 무채색(회색/검정/흰색 계열) 제거
        // ---------------------------------------------------------
        if ((lum_sum > 24) && (sat_diff > 7)) begin
            is_colored = 1;
            cur_color  = 2'b00;

            // RED
            if (r6 > 12 && g6 < 40 && b6 < 40) cur_color = `RED;

            // GREEN
            else if (g6 > 12 && r6 < 25 && b6 < 40) cur_color = `GREEN;

            // BLUE
            else if (b6 > 12 && r6 < 25 && g6 < 40) cur_color = `BLUE;

            // YELLOW
            else if (r6 > 32 && g6 > 45 && b6 < 12) cur_color = `YELLOW;

            else is_colored = 0;

        end
    end

    // -----------------------------------------------------------------
    // 2. 동적 객체 추적 메모리 (최대 15개)
    // -----------------------------------------------------------------
    logic [9:0] min_x[0:14], max_x[0:14];
    logic [8:0] min_y[0:14], max_y[0:14];
    logic [15:0] pix_count[0:14];
    logic [1:0] obj_color[0:14];
    logic obj_valid[0:14];  // 해당 ID가 사용 중인지 여부

    logic [3:0] obj_count;  // 현재까지 발견된 객체 수 (0~15)

    logic [9:0] X;
    logic [8:0] Y;

    // VSYNC 에지 검출
    logic vsync_d;
    always_ff @(posedge pclk) vsync_d <= vsync;
    wire frame_start = (~vsync && vsync_d);  // Falling Edge
    wire frame_end = (vsync && ~vsync_d);  // Rising Edge

    // 병렬 매칭 로직 (현재 픽셀이 어떤 객체에 속하는가?)
    logic [14:0] match_vec;
    always_comb begin
        for (int i = 0; i < 15; i++) begin
            if (obj_valid[i] && (obj_color[i] == cur_color) &&
                (X + MARGIN >= min_x[i]) && (X <= max_x[i] + MARGIN) &&
                (Y + MARGIN >= min_y[i]) && (Y <= max_y[i] + MARGIN)) begin
                match_vec[i] = 1'b1;
            end else begin
                match_vec[i] = 1'b0;
            end
        end
    end

    // 우선순위 인코더 (가장 먼저 매칭된 객체 ID 찾기)
    logic [3:0] match_id;
    logic       is_matched;
    always_comb begin
        is_matched = 1'b0;
        match_id   = 0;
        for (int i = 14; i >= 0; i--) begin
            if (match_vec[i]) begin
                is_matched = 1'b1;
                match_id   = i;
            end
        end
    end

    // 좌표 추적 및 바운딩 박스 갱신
    always_ff @(posedge pclk or posedge reset) begin
        if (reset) begin
            X <= 0;
            Y <= 0;
            obj_count <= 0;
            for (int i = 0; i < 15; i++) obj_valid[i] <= 0;
        end else if (frame_start) begin
            X <= 0;
            Y <= 0;
            obj_count <= 0;
            for (int i = 0; i < 15; i++) begin
                obj_valid[i] <= 0;
                pix_count[i] <= 0;
            end
        end else if (we) begin
            if (X == 319) begin
                X <= 0;
                Y <= Y + 1;
            end else X <= X + 1;

            if (is_colored) begin
                if (is_matched) begin
                    // 기존 객체 박스 확장
                    pix_count[match_id] <= pix_count[match_id] + 1;
                    if (X < min_x[match_id]) min_x[match_id] <= X;
                    if (X > max_x[match_id]) max_x[match_id] <= X;
                    if (Y < min_y[match_id]) min_y[match_id] <= Y;
                    if (Y > max_y[match_id]) max_y[match_id] <= Y;
                end else if (obj_count < 15) begin
                    // 쌩뚱맞은 위치면 새로운 객체 생성
                    obj_valid[obj_count] <= 1'b1;
                    obj_color[obj_count] <= cur_color;
                    min_x[obj_count] <= X;
                    max_x[obj_count] <= X;
                    min_y[obj_count] <= Y;
                    max_y[obj_count] <= Y;
                    pix_count[obj_count] <= 1;
                    obj_count <= obj_count + 1;
                end
            end
        end
    end

    // -----------------------------------------------------------------
    // 3. 프레임 종료 후 결과 계산 FSM (모양 및 위치 판별)
    // -----------------------------------------------------------------
    typedef enum logic [2:0] {
        IDLE,
        READ,
        MATH,
        EVAL,
        DONE,
        WAIT
    } state_t;
    state_t state;

    logic [3:0] idx;
    logic [3:0] final_cnt;
    logic [9:0] W, H, cX;
    logic [8:0] cY;
    logic [19:0] area, thresh_sq, thresh_cir;
    logic [2:0] pX;  // 0 ~ 4 (가로 5칸)
    logic [1:0] pY;  // 0 ~ 2 (세로 3칸)

    logic [1:0] shape;
    logic [3:0] pos_4bit;

    always_ff @(posedge pclk or posedge reset) begin
        if (reset) begin
            state <= IDLE;
            data_done <= 0;
            frame_done <= 0;
            hint_count <= 0;
            bunker_detected <= 0;
            shape <= 2'b11;
        end else begin
            bunker_detected <= 0;
            case (state)
                IDLE: begin
                    frame_done <= 0;
                    data_done  <= 0;
                    if (frame_end) begin
                        idx <= 0;
                        final_cnt <= 0;
                        shape <= 2'b11;
                        state <= READ;
                    end
                end

                READ: begin
                    data_done <= 0;
                    if (idx == obj_count) begin
                        state <= DONE;  // 등록된 객체 모두 확인 완료
                    end else begin
                        if (pix_count[idx] > 100)
                            state <= MATH;  // 노이즈 필터링
                        else idx <= idx + 1;
                    end
                end

                MATH: begin
                    W <= max_x[idx] - min_x[idx] + 1;
                    H <= max_y[idx] - min_y[idx] + 1;
                    // 중심 좌표 (위치 4bit 변환용)
                    cX <= (max_x[idx] + min_x[idx]) >> 1;
                    cY <= (max_y[idx] + min_y[idx]) >> 1;
                    state <= EVAL;
                end

                EVAL: begin

                    area <= W * H;
                    thresh_sq <= area - (area >> 3);  // 87.5%
                    thresh_cir <= (area >> 1) + (area >> 3);  // 62.5%

                    // 1. 모양 판별
                    if (pix_count[idx] > thresh_sq) shape <= `SQUARE;
                    else if (pix_count[idx] > thresh_cir) shape <= `CIRCLE;
                    else shape <= `TRIANGLE;

                    // 2. 5x3 위치 판별 
                    // 가로 5등분: 320 / 5 = 64. 64로 나누는 것은 비트 쉬프트(>> 6)와 완전히 동일함.
                    pX = cX[9:6];

                    // 세로 3등분: 240 / 3 = 80.
                    if (cY < 80) pY = 2'd0;
                    else if (cY < 160) pY = 2'd1;
                    else pY = 2'd2;

                    // 0~14 구역 인덱스 생성 (Y * 5 + X)
                    // pY는 최대 2이므로 곱하기 5를 해도 로직이 매우 작습니다.
                    pos_4bit  <= (pY * 5) + pX;

                    // 3. 1Byte 프로토콜 어셈블리 및 전송
                    hint_data <= {shape, obj_color[idx], pos_4bit};

                    data_done <= 1'b1;  // Trigger!

                    if ((obj_color[idx] == `RED) && (shape == `SQUARE)) begin
                        // bunker_detected
                        final_cnt <= 0;
                        idx <= 0;
                        bunker_detected <= 1;
                        state <= IDLE;
                    end else begin
                        final_cnt <= final_cnt + 1;
                        idx <= idx + 1;
                        state <= READ;
                    end
                end

                DONE: begin
                    hint_count <= final_cnt;
                    frame_done <= 1'b1;  // 프레임 전체 완료 Trigger!
                    state <= WAIT;
                end

                WAIT: begin
                    if ((rx_data == FRAME_ACTION) && rx_done) begin
                        state <= IDLE;
                    end
                end

            endcase
        end
    end

    // -----------------------------------------------------------------
    // 5. LED 직관적 디버깅 (어디서든 감지되면 즉시 표시!)
    // -----------------------------------------------------------------
    // always_ff @(posedge pclk or posedge reset) begin
    //     if (reset) begin
    //         debug_led <= 4'b0000;
    //     end else if (state == IDLE && frame_end) begin
    //         // 프레임이 새로 시작할 때 일단 LED를 끕니다. (잔상 방지)
    //         debug_led <= 4'b0000;
    //     end else begin
    //         // 15구역 중 어디든 상관없이 필터(500픽셀)를 통과해서 데이터를 쏠 때
    //         // 방금 조립된 hint_data의 색상 비트 [5:4]를 확인해서 LED를 켭니다.
    //         if (is_colored) begin
    //             case (obj_color[idx])  // data_done일 때 cell_i가 이미 +1 되었으므로 -1 사용
    //                 2'b00:
    //                 debug_led[0] <= 1'b1;  // 빨간색 감지 -> LED 0번 ON
    //                 2'b01:
    //                 debug_led[1] <= 1'b1;  // 초록색 감지 -> LED 1번 ON
    //                 2'b10:
    //                 debug_led[2] <= 1'b1;  // 파란색 감지 -> LED 2번 ON
    //                 2'b11:
    //                 debug_led[3] <= 1'b1;  // 노란색 감지 -> LED 3번 ON
    //             endcase
    //         end
    //     end
    // end

    // -----------------------------------------------------------------
    // 5. shape 직관적 디버깅 (어디서든 감지되면 즉시 표시!)
    // -----------------------------------------------------------------
    /*
    always_ff @(posedge pclk or posedge reset) begin
        if (reset) begin
            debug_shape_led <= 3'b0000;
        end else if (state == IDLE && frame_end) begin
            // 프레임이 새로 시작할 때 일단 LED를 끕니다. (잔상 방지)
            debug_shape_led <= 3'b0000;
        end else begin
            // 15구역 중 어디든 상관없이 필터(500픽셀)를 통과해서 데이터를 쏠 때
            // 방금 조립된 hint_data의 색상 비트 [5:4]를 확인해서 LED를 켭니다.
            case (shape)
                `SQUARE:
                debug_shape_led[0] <= 1'b1;  // 사각 감지 -> LED 0번 ON
                `TRIANGLE:
                debug_shape_led[1] <= 1'b1;  // 삼각 감지 -> LED 1번 ON
                `CIRCLE:
                debug_shape_led[2] <= 1'b1;  // 원 감지 -> LED 2번 ON
                default: debug_shape_led <= 3'd0;  //  off
            endcase
        end
    end
    */
endmodule


// module Object_Scanner (
//     input logic pclk,  // 카메라 픽셀 클록 (25MHz)
//     input logic reset,

//     // OV7670_MemController에서 가로챈 신호
//     input logic        vsync,
//     input logic        we,
//     input logic [15:0] wData,


//     // 실제 합성때는 삭제
//     output logic [3:0] debug_led,



//     // ---------------- 상대 모듈 인터페이스 ----------------
//     output logic [7:0] hint_data,   // [7:6]모양, [5:4]색상, [3:0]위치
//     output logic [3:0] hint_count,  // 검출된 총 객체 수
//     output logic       data_done,   // 1 tick (데이터 1개 완성 트리거)
//     output logic       frame_done   // 1 tick (1프레임 완료 트리거)

// );

//     // 거리 허용 오차 (이 픽셀 수 이내에 같은 색이 있으면 같은 객체로 묶음)
//     localparam MARGIN = 50;

//     // -----------------------------------------------------------------
//     // 1. 색상 검출 (Combinational)
//     // -----------------------------------------------------------------
//     logic [4:0] R, B;
//     logic [5:0] G;
//     assign {R, G, B} = {wData[15:11], wData[10:5], wData[4:0]};

//     logic [1:0] cur_color;
//     logic       is_colored;

//     always_comb begin
//         is_colored = 1'b1;
//         cur_color  = 2'b00;

//         // Red: R이 G보다 최소 8 이상 크고, B보다도 클 때
//         if ((R > G + 8) && (R > B + 8)) cur_color = 2'b00;

//         // Green: G(6비트)가 R, B보다 압도적으로 클 때
//         else if ((G > {1'b0, R} + 12) && (G > {1'b0, B} + 12)) cur_color = 2'b01;

//         // Blue: B가 R보다 크고, G보다 클 때
//         else if ((B > R + 8) && (B > (G >> 1) + 5))  // G는 6비트이므로 shift로 보정
//             cur_color = 2'b10;

//         // Yellow: R과 G가 모두 높고 B는 낮을 때
//         else if ((R > 18) && (G > 25) && (B < 12)) cur_color = 2'b11;

//         else is_colored = 1'b0;
//     end

//     // -----------------------------------------------------------------
//     // 2. 동적 객체 추적 메모리 (최대 15개)
//     // -----------------------------------------------------------------
//     logic [9:0] min_x[0:14], max_x[0:14];
//     logic [8:0] min_y[0:14], max_y[0:14];
//     logic [15:0] pix_count[0:14];
//     logic [1:0] obj_color[0:14];
//     logic obj_valid[0:14];  // 해당 ID가 사용 중인지 여부

//     logic [3:0] obj_count;  // 현재까지 발견된 객체 수 (0~15)

//     logic [9:0] X;
//     logic [8:0] Y;

//     // VSYNC 에지 검출
//     logic vsync_d;
//     always_ff @(posedge pclk) vsync_d <= vsync;
//     wire frame_start = (~vsync && vsync_d);  // Falling Edge
//     wire frame_end = (vsync && ~vsync_d);  // Rising Edge

//     // 병렬 매칭 로직 (현재 픽셀이 어떤 객체에 속하는가?)
//     logic [14:0] match_vec;
//     always_comb begin
//         for (int i = 0; i < 15; i++) begin
//             if (obj_valid[i] && (obj_color[i] == cur_color) &&
//                 (X + MARGIN >= min_x[i]) && (X <= max_x[i] + MARGIN) &&
//                 (Y + MARGIN >= min_y[i]) && (Y <= max_y[i] + MARGIN)) begin
//                 match_vec[i] = 1'b1;
//             end else begin
//                 match_vec[i] = 1'b0;
//             end
//         end
//     end

//     // 우선순위 인코더 (가장 먼저 매칭된 객체 ID 찾기)
//     logic [3:0] match_id;
//     logic       is_matched;
//     always_comb begin
//         is_matched = 1'b0;
//         match_id   = 0;
//         for (int i = 14; i >= 0; i--) begin
//             if (match_vec[i]) begin
//                 is_matched = 1'b1;
//                 match_id   = i;
//             end
//         end
//     end

//     // 좌표 추적 및 바운딩 박스 갱신
//     always_ff @(posedge pclk or posedge reset) begin
//         if (reset) begin
//             X <= 0;
//             Y <= 0;
//             obj_count <= 0;
//             for (int i = 0; i < 15; i++) obj_valid[i] <= 0;
//         end else if (frame_start) begin
//             X <= 0;
//             Y <= 0;
//             obj_count <= 0;
//             for (int i = 0; i < 15; i++) begin
//                 obj_valid[i] <= 0;
//                 pix_count[i] <= 0;
//             end
//         end else if (we) begin
//             if (X == 319) begin
//                 X <= 0;
//                 Y <= Y + 1;
//             end else X <= X + 1;

//             if (is_colored) begin
//                 if (is_matched) begin
//                     // 기존 객체 박스 확장
//                     pix_count[match_id] <= pix_count[match_id] + 1;
//                     if (X < min_x[match_id]) min_x[match_id] <= X;
//                     if (X > max_x[match_id]) max_x[match_id] <= X;
//                     if (Y < min_y[match_id]) min_y[match_id] <= Y;
//                     if (Y > max_y[match_id]) max_y[match_id] <= Y;
//                 end else if (obj_count < 15) begin
//                     // 쌩뚱맞은 위치면 새로운 객체 생성
//                     obj_valid[obj_count] <= 1'b1;
//                     obj_color[obj_count] <= cur_color;
//                     min_x[obj_count] <= X;
//                     max_x[obj_count] <= X;
//                     min_y[obj_count] <= Y;
//                     max_y[obj_count] <= Y;
//                     pix_count[obj_count] <= 1;
//                     obj_count <= obj_count + 1;
//                 end
//             end
//         end
//     end

//     // -----------------------------------------------------------------
//     // 3. 프레임 종료 후 결과 계산 FSM (모양 및 위치 판별)
//     // -----------------------------------------------------------------
//     typedef enum logic [2:0] {
//         IDLE,
//         READ,
//         MATH,
//         EVAL,
//         DONE
//     } state_t;
//     state_t state;

//     logic [3:0] idx;
//     logic [3:0] final_cnt;
//     logic [9:0] W, H, cX;
//     logic [8:0] cY;
//     logic [19:0] area, thresh_sq, thresh_cir;
//     logic [2:0] pX;  // 0 ~ 4 (가로 5칸)
//     logic [1:0] pY;  // 0 ~ 2 (세로 3칸)

//     always_ff @(posedge pclk or posedge reset) begin
//         if (reset) begin
//             state <= IDLE;
//             data_done <= 0;
//             frame_done <= 0;
//             hint_count <= 0;
//         end else begin
//             case (state)
//                 IDLE: begin
//                     frame_done <= 0;
//                     data_done  <= 0;
//                     if (frame_end) begin
//                         idx <= 0;
//                         final_cnt <= 0;
//                         state <= READ;
//                     end
//                 end

//                 READ: begin
//                     data_done <= 0;
//                     if (idx == obj_count) begin
//                         state <= DONE;  // 등록된 객체 모두 확인 완료
//                     end else begin
//                         if (pix_count[idx] > 300) state <= MATH;  // 노이즈 필터링
//                         else idx <= idx + 1;
//                     end
//                 end

//                 MATH: begin
//                     W <= max_x[idx] - min_x[idx] + 1;
//                     H <= max_y[idx] - min_y[idx] + 1;
//                     // 중심 좌표 (위치 4bit 변환용)
//                     cX <= (max_x[idx] + min_x[idx]) >> 1;
//                     cY <= (max_y[idx] + min_y[idx]) >> 1;
//                     state <= EVAL;
//                 end

//                 EVAL: begin
//                     logic [1:0] shape;
//                     logic [3:0] pos_4bit;

//                     area = W * H;
//                     thresh_sq = area - (area >> 3);  // 87.5%
//                     thresh_cir = (area >> 1) + (area >> 3);  // 62.5%

//                     // 1. 모양 판별
//                     if (pix_count[idx] > thresh_sq) shape = 2'b01;  // Square
//                     else if (pix_count[idx] > thresh_cir) shape = 2'b11;  // Circle
//                     else shape = 2'b10;  // Triangle

//                     // 2. 5x3 위치 판별 (수정된 부분!)
//                     // 가로 5등분: 320 / 5 = 64. 64로 나누는 것은 비트 쉬프트(>> 6)와 완전히 동일함.
//                     pX = cX[9:6];

//                     // 세로 3등분: 240 / 3 = 80.
//                     if (cY < 80) pY = 2'd0;
//                     else if (cY < 160) pY = 2'd1;
//                     else pY = 2'd2;

//                     // 0~14 구역 인덱스 생성 (Y * 5 + X)
//                     // pY는 최대 2이므로 곱하기 5를 해도 로직이 매우 작습니다.
//                     pos_4bit = (pY * 5) + pX;

//                     // 3. 1Byte 프로토콜 어셈블리 및 전송
//                     hint_data <= {shape, obj_color[idx], pos_4bit};
//                     data_done <= 1'b1;  // Trigger!

//                     final_cnt <= final_cnt + 1;
//                     idx <= idx + 1;
//                     state <= READ;
//                 end

//                 DONE: begin
//                     hint_count <= final_cnt;
//                     frame_done <= 1'b1;  // 프레임 전체 완료 Trigger!
//                     state <= IDLE;
//                 end
//             endcase
//         end
//     end
//     // -----------------------------------------------------------------
//     // 5. LED 직관적 디버깅 (어디서든 감지되면 즉시 표시!)
//     // -----------------------------------------------------------------
//     always_ff @(posedge pclk or posedge reset) begin
//         if (reset) begin
//             debug_led <= 4'b0000;
//         end else if (state == IDLE && frame_end) begin
//             // 프레임이 새로 시작할 때 일단 LED를 끕니다. (잔상 방지)
//             debug_led <= 4'b0000;
//         end else begin
//             // 🌟 15구역 중 어디든 상관없이 필터(500픽셀)를 통과해서 데이터를 쏠 때!
//             // 방금 조립된 hint_data의 색상 비트 [5:4]를 확인해서 LED를 켭니다.

//             case (obj_color[idx])  // data_done일 때 cell_i가 이미 +1 되었으므로 -1 사용
//                 2'b00: debug_led <= 4'b0001;  // 빨간색 감지 -> LED 0번 ON
//                 2'b01: debug_led <= 4'b0010;  // 초록색 감지 -> LED 1번 ON
//                 2'b10: debug_led <= 4'b0100;  // 파란색 감지 -> LED 2번 ON
//                 2'b11: debug_led <= 4'b1000;  // 노란색 감지 -> LED 3번 ON
//             endcase
//         end
//     end



// endmodule



// module Object_Scanner (
//     input  logic        pclk,       // 카메라 픽셀 클록 (25MHz)
//     input  logic        reset,

//     // OV7670_MemController에서 나오는 신호 (Intercept)
//     input  logic        vsync,      // 프레임 동기화 신호
//     input  logic        we,         // 유효한 1픽셀 데이터가 들어올 때 High
//     input  logic [15:0] wData,      // RGB565 데이터

//     // 상대 모듈과 약속한 Output Protocol
//     output logic [7:0]  hint_data,  // [7:6]모양, [5:4]색상, [3:0]위치
//     output logic [3:0]  hint_count, // 검출된 총 객체 수 (마지막에 출력)
//     output logic        data_done,  // 1 tick (데이터 1개 완성)
//     output logic        frame_done  // 1 tick (1프레임 전체 완료)
// );

//     // -----------------------------------------------------------------
//     // 1. 색상 검출 로직 (Combinational)
//     // -----------------------------------------------------------------
//     logic [4:0] R, B;
//     logic [5:0] G;
//     assign {R, G, B} = {wData[15:11], wData[10:5], wData[4:0]};

//     logic [1:0] cur_color;
//     logic       is_colored;

//     always_comb begin
//         is_colored = 1'b1;
//         cur_color  = 2'b00;
//         if      (R > 22 && G < 12 && B < 12) cur_color = 2'b00; // Red (순수 빨강)
//         else if (R < 12 && G > 45 && B < 12) cur_color = 2'b01; // Green (순수 초록)
//         else if (R < 12 && G < 15 && B > 22) cur_color = 2'b10; // Blue (순수 파랑)
//         else if (R > 22 && G > 45 && B < 12) cur_color = 2'b11; // Yellow (빨+초)
//         else is_colored = 1'b0; // 나머지는 다 찌끄레기(노이즈)로 무시!
//     end

//     // -----------------------------------------------------------------
//     // 2. 좌표 및 15구역 인덱스 생성
//     // -----------------------------------------------------------------
//     logic [9:0] X;
//     logic [8:0] Y;
//     logic [3:0] pos_idx;  // 0 ~ 14

//     logic [2:0] pos_x; // 0 ~ 4
//     logic [1:0] pos_y; // 0 ~ 2

//     // 화면(320x240)을 5x3으로 분할. 
//     // 가로는 64단위(X >> 6), 세로는 80단위
//     assign pos_x = X[8:6]; // X / 64 와 동일
//     always_comb begin
//         if      (Y < 80)  pos_y = 2'd0;
//         else if (Y < 160) pos_y = 2'd1;
//         else              pos_y = 2'd2;
//     end
//     assign pos_idx = (pos_y * 5) + pos_x; // 0 ~ 14 생성

//     // -----------------------------------------------------------------
//     // 3. 15구역의 독립된 데이터 저장소 (Registers)
//     // -----------------------------------------------------------------
//     logic [9:0] min_x [0:14], max_x [0:14];
//     logic [8:0] min_y [0:14], max_y [0:14];
//     logic [15:0] pix_count [0:14];
//     logic [1:0]  obj_color [0:14];

//     // VSYNC 에지 검출
//     logic vsync_d;
//     always_ff @(posedge pclk) vsync_d <= vsync;
//     wire frame_start = (~vsync && vsync_d);  // VSYNC Falling Edge
//     wire frame_end   = (vsync && ~vsync_d);  // VSYNC Rising Edge

//     // 좌표 추적 및 픽셀 누적
//     always_ff @(posedge pclk or posedge reset) begin
//         if (reset) begin
//             X <= 0; Y <= 0;
//         end else if (frame_start) begin
//             X <= 0; Y <= 0;
//             // 15구역 초기화
//             for (int i=0; i<15; i++) begin
//                 min_x[i] <= 10'h3FF; max_x[i] <= 0;
//                 min_y[i] <= 9'h1FF;  max_y[i] <= 0;
//                 pix_count[i] <= 0;
//             end
//         end else if (we) begin // 유효한 픽셀이 들어올 때
//             // X, Y 좌표 카운터
//             if (X == 319) begin
//                 X <= 0; Y <= Y + 1;
//             end else begin
//                 X <= X + 1;
//             end

//             // 색상 픽셀 누적 (바운딩 박스 및 카운트)
//             if (is_colored && pos_idx < 15) begin
//                 pix_count[pos_idx] <= pix_count[pos_idx] + 1;
//                 obj_color[pos_idx] <= cur_color;

//                 if (X < min_x[pos_idx]) min_x[pos_idx] <= X;
//                 if (X > max_x[pos_idx]) max_x[pos_idx] <= X;
//                 if (Y < min_y[pos_idx]) min_y[pos_idx] <= Y;
//                 if (Y > max_y[pos_idx]) max_y[pos_idx] <= Y;
//             end
//         end
//     end

//     // -----------------------------------------------------------------
//     // 4. 프레임 종료 후 일괄 정산 FSM (모양 판단 및 출력)
//     // -----------------------------------------------------------------
//     typedef enum logic [2:0] {
//         IDLE, READ, MATH_W_H, MATH_AREA, MATH_THRESH, EVAL, DONE
//     } state_t;
//     state_t state;

//     logic [3:0] cell_i;       // 0 ~ 14 루프용 인덱스
//     logic [3:0] valid_cnt;    // 발견된 객체 수 카운터

//     // 계산용 파이프라인 레지스터
//     logic [9:0] W;
//     logic [8:0] H;
//     logic [19:0] area;
//     logic [19:0] thresh_sq, thresh_cir;

//     always_ff @(posedge pclk or posedge reset) begin
//         if (reset) begin
//             state <= IDLE;
//             data_done <= 0; frame_done <= 0; hint_count <= 0;
//         end else begin
//             case (state)
//                 IDLE: begin
//                     frame_done <= 0;
//                     data_done  <= 0;
//                     if (frame_end) begin // 한 프레임의 픽셀 스캔이 끝남
//                         cell_i <= 0;
//                         valid_cnt <= 0;
//                         state <= READ;
//                     end
//                 end

//                 READ: begin
//                     data_done <= 0;
//                     if (cell_i == 15) begin
//                         state <= DONE; // 15구역 모두 확인 완료
//                     end else begin
//                         // 100픽셀 이하는 노이즈로 간주하고 무시
//                         if (pix_count[cell_i] > 100) state <= MATH_W_H;
//                         else cell_i <= cell_i + 1; // 유효하지 않으면 다음 칸으로
//                     end
//                 end

//                 MATH_W_H: begin
//                     W <= max_x[cell_i] - min_x[cell_i] + 1;
//                     H <= max_y[cell_i] - min_y[cell_i] + 1;
//                     state <= MATH_AREA;
//                 end

//                 MATH_AREA: begin
//                     area <= W * H; // 가로 x 세로
//                     state <= MATH_THRESH;
//                 end

//                 MATH_THRESH: begin
//                     // Shift 연산으로 슬랙 확보 (면적의 87.5%, 62.5%)
//                     thresh_sq  <= area - (area >> 3); 
//                     thresh_cir <= (area >> 1) + (area >> 3);
//                     state <= EVAL;
//                 end

//                 EVAL: begin
//                     logic [1:0] shape;

//                     // 밀도(Density) 기반 모양 판별
//                     if      (pix_count[cell_i] > thresh_sq)  shape = 2'b01; // Square
//                     else if (pix_count[cell_i] > thresh_cir) shape = 2'b11; // Circle
//                     else                                     shape = 2'b10; // Triangle

//                     // 1Byte 프로토콜 어셈블리 및 전송
//                     hint_data <= {shape, obj_color[cell_i], cell_i};
//                     data_done <= 1'b1; // Trigger!

//                     valid_cnt <= valid_cnt + 1;
//                     cell_i <= cell_i + 1;
//                     state <= READ; // 다음 칸 검사하러 복귀
//                 end

//                 DONE: begin
//                     hint_count <= valid_cnt; // 최종 개수 출력
//                     frame_done <= 1'b1;      // 프레임 완료 Trigger!
//                     state <= IDLE;
//                 end
//             endcase
//         end
//     end

// endmodule


// `timescale 1ns / 1ps

// module Object_Scanner (
//     input  logic        pclk,       // 카메라 픽셀 클록 (25MHz)
//     input  logic        reset,

//     // OV7670_MemController에서 가로챈 신호
//     input  logic        vsync,      
//     input  logic        we,         
//     input  logic [15:0] wData,      

//     // ---------------- 상대 모듈 인터페이스 ----------------
//     output logic [7:0]  hint_data,  
//     output logic [3:0]  hint_count, 
//     output logic        data_done,  
//     output logic        frame_done,

//     output logic [3:0]  debug_led 
// );

//     // -----------------------------------------------------------------
//     // 1. 색상 검출 로직 (모니터 촬영에 최적화된 영점 조절!)
//     // -----------------------------------------------------------------
//     logic [4:0] R, B;
//     logic [5:0] G;
//     assign {R, G, B} = {wData[15:11], wData[10:5], wData[4:0]};

//     logic [1:0] cur_color;
//     logic       is_colored;

//     always_comb begin
//         is_colored = 1'b1;
//         cur_color  = 2'b00;

//         // 초록색은 매우 엄격하게(G>45), 파랑/빨강은 관대하게 허용
//         if      (R > 20 && G < 20 && B < 15) cur_color = 2'b00; // Red 
//         else if (B > 18 && R < 15 && G < 35) cur_color = 2'b10; // Blue (스카이블루 허용)
//         else if (G > 45 && R < 12 && B < 15) cur_color = 2'b01; // Green (엄격!)
//         else if (R > 20 && G > 35 && B < 15) cur_color = 2'b11; // Yellow
//         else is_colored = 1'b0; 
//     end

//     // -----------------------------------------------------------------
//     // 2. 5x3 고정 그리드 좌표 인덱스 생성
//     // -----------------------------------------------------------------
//     logic [9:0] X;
//     logic [8:0] Y;
//     logic [3:0] pos_idx;  // 0 ~ 14

//     logic [2:0] pos_x; // 0 ~ 4
//     logic [1:0] pos_y; // 0 ~ 2

//     assign pos_x = X[8:6]; // X / 64
//     always_comb begin
//         if      (Y < 80)  pos_y = 2'd0;
//         else if (Y < 160) pos_y = 2'd1;
//         else              pos_y = 2'd2;
//     end
//     assign pos_idx = (pos_y * 5) + pos_x;

//     // -----------------------------------------------------------------
//     // 3. 15구역 독립 데이터 저장소 (노이즈 방해 차단 완벽)
//     // -----------------------------------------------------------------
//     logic [9:0] min_x [0:14], max_x [0:14];
//     logic [8:0] min_y [0:14], max_y [0:14];
//     logic [15:0] pix_count [0:14];
//     logic [1:0]  obj_color [0:14];

//     logic vsync_d;
//     always_ff @(posedge pclk) vsync_d <= vsync;
//     wire frame_start = (~vsync && vsync_d); 
//     wire frame_end   = (vsync && ~vsync_d); 

//     always_ff @(posedge pclk or posedge reset) begin
//         if (reset) begin
//             X <= 0; Y <= 0;
//         end else if (frame_start) begin
//             X <= 0; Y <= 0;
//             for (int i=0; i<15; i++) begin
//                 min_x[i] <= 10'h3FF; max_x[i] <= 0;
//                 min_y[i] <= 9'h1FF;  max_y[i] <= 0;
//                 pix_count[i] <= 0;
//             end
//         end else if (we) begin 
//             if (X == 319) begin
//                 X <= 0; Y <= Y + 1;
//             end else begin
//                 X <= X + 1;
//             end

//             if (is_colored && pos_idx < 15) begin
//                 pix_count[pos_idx] <= pix_count[pos_idx] + 1;
//                 obj_color[pos_idx] <= cur_color;

//                 if (X < min_x[pos_idx]) min_x[pos_idx] <= X;
//                 if (X > max_x[pos_idx]) max_x[pos_idx] <= X;
//                 if (Y < min_y[pos_idx]) min_y[pos_idx] <= Y;
//                 if (Y > max_y[pos_idx]) max_y[pos_idx] <= Y;
//             end
//         end
//     end

//     // -----------------------------------------------------------------
//     // 4. 프레임 종료 후 결과 출력 FSM
//     // -----------------------------------------------------------------
//     typedef enum logic [2:0] { IDLE, READ, MATH, EVAL, DONE } state_t;
//     state_t state;

//     logic [3:0] cell_i;       
//     logic [3:0] valid_cnt;    

//     logic [9:0] W;
//     logic [8:0] H;
//     logic [19:0] area, thresh_sq, thresh_cir;

//     always_ff @(posedge pclk or posedge reset) begin
//         if (reset) begin
//             state <= IDLE;
//             data_done <= 0; frame_done <= 0; hint_count <= 0;
//         end else begin
//             case (state)
//                 IDLE: begin
//                     frame_done <= 0; data_done <= 0;
//                     if (frame_end) begin 
//                         cell_i <= 0; valid_cnt <= 0;
//                         state <= READ;
//                     end
//                 end

//                 READ: begin
//                     data_done <= 0;
//                     if (cell_i == 15) begin
//                         state <= DONE; 
//                     end else begin
//                         // 100픽셀 이하는 노이즈로 쿨하게 무시!
//                         if (pix_count[cell_i] > 200) state <= MATH;
//                         else cell_i <= cell_i + 1; 
//                     end
//                 end

//                 MATH: begin
//                     W <= max_x[cell_i] - min_x[cell_i] + 1;
//                     H <= max_y[cell_i] - min_y[cell_i] + 1;
//                     state <= EVAL;
//                 end

//                 EVAL: begin
//                     logic [1:0] shape;

//                     area = W * H; 
//                     thresh_sq  = area - (area >> 3); 
//                     thresh_cir = (area >> 1) + (area >> 3);

//                     if      (pix_count[cell_i] > thresh_sq)  shape = 2'b01; // Square
//                     else if (pix_count[cell_i] > thresh_cir) shape = 2'b11; // Circle
//                     else                                     shape = 2'b10; // Triangle

//                     // 위치(cell_i) 데이터 바로 전송
//                     hint_data <= {shape, obj_color[cell_i], cell_i};
//                     data_done <= 1'b1; // Trigger!

//                     valid_cnt <= valid_cnt + 1;
//                     cell_i <= cell_i + 1;
//                     state <= READ; 
//                 end

//                 DONE: begin
//                     hint_count <= valid_cnt; 
//                     frame_done <= 1'b1;      
//                     state <= IDLE;
//                 end
//             endcase
//         end
//     end

//     // -----------------------------------------------------------------
//     // 5. LED 직관적 디버깅 (어디서든 감지되면 즉시 표시!)
//     // -----------------------------------------------------------------
//     always_ff @(posedge pclk or posedge reset) begin
//         if (reset) begin
//             debug_led <= 4'b0000;
//         end else if (state == IDLE && frame_end) begin
//             // 프레임이 새로 시작할 때 일단 LED를 끕니다. (잔상 방지)
//             debug_led <= 4'b0000;
//         end else if (data_done) begin 
//             // 🌟 15구역 중 어디든 상관없이 필터(500픽셀)를 통과해서 데이터를 쏠 때!
//             // 방금 조립된 hint_data의 색상 비트 [5:4]를 확인해서 LED를 켭니다.
//             case (obj_color[cell_i - 1]) // data_done일 때 cell_i가 이미 +1 되었으므로 -1 사용
//                 2'b00: debug_led <= 4'b0001; // 빨간색 감지 -> LED 0번 ON
//                 2'b01: debug_led <= 4'b0010; // 초록색 감지 -> LED 1번 ON
//                 2'b10: debug_led <= 4'b0100; // 파란색 감지 -> LED 2번 ON
//                 2'b11: debug_led <= 4'b1000; // 노란색 감지 -> LED 3번 ON
//             endcase
//         end
//     end
// endmodule

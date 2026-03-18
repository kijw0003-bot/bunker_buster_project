`timescale 1ns / 1ps
`include "define.vh"

module camera_ui (
    //SYSTEM PORT
    input  logic       clk,
    input  logic       reset,

    //VGA_Decoder 신호
    input  logic       DE, // 현재 픽셀 유효한 화면 영역
    input  logic [9:0] x_pixel, // 현재 가로 좌표
    input  logic [9:0] y_pixel, // 현재 세로 좌표

    //Grid_Filter 신호 카메라 영상 + 흰색 격자 데이터
    input  logic [3:0] in_R,
    input  logic [3:0] in_G,
    input  logic [3:0] in_B,

    //HSV_object_scanner 신호
    input  logic [7:0] hint_data, // [7:4]color 색, [3:0]section 위치
    input  logic       data_done, //지금 hint data가 유효하다는 신호
    input  logic       frame_done, //한 프레임의 힌트 수집이 끝난 신호

    // 입력 영상 + 텍스트 UI
    output logic [3:0] out_R, 
    output logic [3:0] out_G,
    output logic [3:0] out_B
);

    ///////////////////////////////////////////////////////////////
    //화면 / 폰트 기본 설정
    ////////////////////////////////////////////////////////////////

    //15칸으로 나눔 640x480기준으로 칸하나 크기 128x160
    localparam int NUM_SEC = 15; // 화면 칸 개수 5 x 3 = 15
    localparam int CELL_W  = 128;  // 각 칸 크기 640 / 5 = 128
    localparam int CELL_H  = 160;  // 각 칸 크기 480 / 3 = 160

    //폰트 2배 확대
    localparam int SCALE     = 2; 

    //기본 문자 크기 5x7 폰트
    localparam int CHAR_W    = 5; 
    localparam int CHAR_H    = 7;

    //실제 확대 후 문자 하나 크기
    localparam int CHAR_PX_W = CHAR_W * SCALE;  // 10 
    localparam int CHAR_PX_H = CHAR_H * SCALE;  // 14

    //문자와 문자 사이 간격
    localparam int GAP_X = 2;

    //텍스트 위치 
    // 첫번째 줄은 y=16 위치
    localparam int LINE1_Y = 16;

    // ============================================================
    // 2) 표시용 단어 ID
    // ============================================================
    localparam logic [2:0] WORD_RED      = 3'd0;
    localparam logic [2:0] WORD_GREEN    = 3'd1;
    localparam logic [2:0] WORD_BLUE     = 3'd2;
    localparam logic [2:0] WORD_NONE     = 3'd3;

    // ============================================================
    // 3) 프레임 버퍼
    // scan_* : 현재 프레임 동안 수집
    // disp_* : 현재 화면에 실제 표시 중
    // ============================================================
    logic       scan_valid [0:NUM_SEC-1]; //i번 칸에 이번 프레임 동안 유효한 힌트가 들어왔는지
    logic [3:0] scan_color [0:NUM_SEC-1]; //i번 칸의 색상

    //현쟈 화면에 실제로 보여주고 있는 버퍼
    //한 프레임 끝났을 때 한꺼번에 화면용 버퍼로 넘기기 위해서 안정성
    logic       disp_valid [0:NUM_SEC-1]; 
    logic [3:0] disp_color [0:NUM_SEC-1];

    integer i;

    // ============================================================
    // 4) 유효성 검사
    // ============================================================

    //칸 번호가 0~14 안에 들어오는지 검사
    function automatic logic is_valid_section(input logic [3:0] sec);
        begin
            is_valid_section = (sec < 4'd15);
        end
    endfunction

    //색상 검사 색상이 빨강, 초록, 파랑 중 하나 인지 검사
    function automatic logic is_valid_color(input logic [3:0] color);
        begin
            case (color)
                `RED, `GREEN, `BLUE: is_valid_color = 1'b1;
                default:             is_valid_color = 1'b0;
            endcase
        end
    endfunction


    // ============================================================
    // 5) 이번 클럭에 들어온 새 hit 해석
    // hint_data = {color[7:4], section[3:0]}
    // ============================================================
    logic       hit_valid;
    logic [3:0] hit_sec;
    logic [3:0] hit_color;

    //hint_data 를 두 부분 {color[7:4], section[3:0]} 이거를 나눠서 검사
    always_comb begin
        hit_sec   = hint_data[3:0];
        hit_color = hint_data[7:4];

        //이번 힌트가 진짜 유효한지 판정
        //조건 4개가 모두 참이면 hit_valid = 1;
        hit_valid = data_done &&
                    is_valid_section(hit_sec) &&
                    is_valid_color(hit_color);
    end

    // ============================================================
    // 6) 프레임 수집 및 표시 버퍼 갱신
    //
    // - 프레임 중에는 scan_*에 칸별 최신 결과를 저장
    // - frame_done이 오면 scan_*를 disp_*로 복사
    // - 같은 클럭에 hit_valid와 frame_done이 동시에 오면
    //   그 마지막 hit도 바로 disp_*에 반영
    // ============================================================
    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            for (i = 0; i < NUM_SEC; i = i + 1) begin
                scan_valid[i] <= 1'b0;
                scan_color[i] <= 4'd0;

                disp_valid[i] <= 1'b0;
                disp_color[i] <= 4'd0;

            end
        end
        else begin
            if (frame_done) begin
                for (i = 0; i < NUM_SEC; i = i + 1) begin
                    // 이번 클럭에 막 들어온 hit가 이 section이면
                    // 그 값을 우선 반영
                    // frame done이 오는 시점에 마지막 힌트 hit_valid도 같은 클럭에 들어올 수있음
                    // 같은 클럭에 들어온 마지막 hit를 우선 반영
                    // i번 칸에 마지막 힌트가 막 들어왔으면 sacn_x 대신 바로 hit_x 값을 disp_x에 넣음
                    if (hit_valid && (hit_sec == i)) begin
                        disp_valid[i] <= 1'b1;
                        disp_color[i] <= hit_color;
                    end

                    // 마지막 hit가 아니면 이번 프레임 동안 모아둔 값을 화면 버퍼로 복사
                    else begin
                        disp_valid[i] <= scan_valid[i];
                        disp_color[i] <= scan_color[i];
                    end

                    // 다음 프레임을 위해 scan 버퍼 초기화
                    scan_valid[i] <= 1'b0;
                    scan_color[i] <= 4'd0;
                end
            end
            else begin
                // 프레임 동안 section별 최신 결과 저장
                // 프레임 진행 중이면 같은 프레임 동안 section대해 힌트가 여러 번 들어오면
                // 가장 마지막 값이 남게
                if (hit_valid) begin
                    scan_valid[hit_sec] <= 1'b1;
                    scan_color[hit_sec] <= hit_color;
                end
            end
        end
    end

    // ============================================================
    // 7) 현재 픽셀이 어느 칸(section)인지 계산
    // ============================================================
    logic [2:0] cur_sx; // 가로 칸 번호
    logic [2:0] cur_sy; // 세로 칸 번호
    logic [3:0] cur_sec; // 전체 section 번호
    logic [9:0] sec_x0, sec_y0; // 그 칸의 시작 좌표
    logic [9:0] local_x, local_y; // 칸 내부 로컬 좌표

    always_comb begin
        // 가로 5칸 중 몇 번째 칸인지 계산
        // ex) 0~127 는 0번칸 512~639는 4번째 칸
        cur_sx = (x_pixel < 10'd128) ? 3'd0 :
                 (x_pixel < 10'd256) ? 3'd1 :
                 (x_pixel < 10'd384) ? 3'd2 :
                 (x_pixel < 10'd512) ? 3'd3 : 3'd4;

        //세로 3칸 중 몇 번째 칸인지 계산
        // ex) 0~159 0행 320~479 2행
        cur_sy = (y_pixel < 10'd160) ? 3'd0 :
                 (y_pixel < 10'd320) ? 3'd1 : 3'd2;

        //section 번호로 바꿈
        // 1행 0,1,2,3,4
        // 2행 5,6,7,8,9
        // 3행 10,11,12,13,14
        cur_sec = cur_sy * 4'd5 + cur_sx;

        //현재 칸의 왼쪽 위 시작 좌표를 구함
        //ex) cur_sx = 2면 x 시작은 2x128 = 256
        //ex) cur_sy = 1면 x 시작은 1x160 = 160
        sec_x0  = cur_sx * CELL_W;
        sec_y0  = cur_sy * CELL_H;

        //현재 픽셀이 칸 내부에서 어디쯤인지 계산
        //ex) 화면 전체 x = 270인데 현재 칸 시작점 256이면
        //칸 내부 x 좌표는 14가 됨
        //칸 내부 좌표가 필요하기 때문에 계산
        local_x = x_pixel - sec_x0;
        local_y = y_pixel - sec_y0;
    end

    // ============================================================
    // 8) 현재 칸의 color 값을 단어 ID로 변환
    // ============================================================
    //현재 픽셀이 속한 칸에 대해 무슨 단어를 쓸지 저장할 변수
    logic [2:0] color_word_id;

    //현재 칸의 표시용 색상 값을 보고 색상 RED~BLUE로 
    always_comb begin
        case (disp_color[cur_sec])
            `RED:   color_word_id = WORD_RED;
            `GREEN: color_word_id = WORD_GREEN;
            `BLUE:  color_word_id = WORD_BLUE;
            default: color_word_id = WORD_NONE;
        endcase
    end

    // ============================================================
    // 9) 단어 길이 / 단어 문자 선택
    // ============================================================
    //단어가 몇 글자인지 반환
    //ex) RED 는 3 GREEN는 5
    function automatic [2:0] word_len_chars(input logic [2:0] word_id);
        begin
            //텍스트 중앙정렬, 문자 몇개를 그릴지 결정
            case (word_id)
                WORD_RED:      word_len_chars = 3'd3;
                WORD_GREEN:    word_len_chars = 3'd5;
                WORD_BLUE:     word_len_chars = 3'd4;
                default:       word_len_chars = 3'd0;
            endcase
        end
    endfunction

    //단어의 특정 위치 문자 가져옴
    //ex) word_id= RED, idx = 0이면 R
    //ex) word_id= RED, idx = 1이면 E
    //ex) word_id= RED, idx = 2이면 D
    function automatic [7:0] word_char(
        input logic [2:0] word_id,
        input logic [3:0] idx
    );
    
        begin
            word_char = " ";

            case (word_id)
                WORD_RED: begin
                    case (idx)
                        4'd0: word_char = "R";
                        4'd1: word_char = "E";
                        4'd2: word_char = "D";
                        default: word_char = " ";
                    endcase
                end

                WORD_GREEN: begin
                    case (idx)
                        4'd0: word_char = "G";
                        4'd1: word_char = "R";
                        4'd2: word_char = "E";
                        4'd3: word_char = "E";
                        4'd4: word_char = "N";
                        default: word_char = " ";
                    endcase
                end

                WORD_BLUE: begin
                    case (idx)
                        4'd0: word_char = "B";
                        4'd1: word_char = "L";
                        4'd2: word_char = "U";
                        4'd3: word_char = "E";
                        default: word_char = " ";
                    endcase
                end

                default: word_char = " ";
            endcase
        end
    endfunction

    // ============================================================
    // 10) 5x7 비트맵 폰트
    // ============================================================

    //주어진 문자 ch의 row번째 줄 비트 패턴 반환
    //ex)A의 0번째 줄은 5'b01110이니 5이걸 5칸으로 보면 가운데 3칸이 켜진 모양
    function automatic [4:0] font_row(
        input logic [7:0] ch,
        input logic [2:0] row
    );
        begin
            font_row = 5'b00000;

            case (ch)
                "B": begin
                    case (row)
                        3'd0: font_row = 5'b11110;
                        3'd1: font_row = 5'b10001;
                        3'd2: font_row = 5'b11110;
                        3'd3: font_row = 5'b10001;
                        3'd4: font_row = 5'b10001;
                        3'd5: font_row = 5'b10001;
                        3'd6: font_row = 5'b11110;
                    endcase
                end

                "D": begin
                    case (row)
                        3'd0: font_row = 5'b11110;
                        3'd1: font_row = 5'b10001;
                        3'd2: font_row = 5'b10001;
                        3'd3: font_row = 5'b10001;
                        3'd4: font_row = 5'b10001;
                        3'd5: font_row = 5'b10001;
                        3'd6: font_row = 5'b11110;
                    endcase
                end

                "E": begin
                    case (row)
                        3'd0: font_row = 5'b11111;
                        3'd1: font_row = 5'b10000;
                        3'd2: font_row = 5'b11110;
                        3'd3: font_row = 5'b10000;
                        3'd4: font_row = 5'b10000;
                        3'd5: font_row = 5'b10000;
                        3'd6: font_row = 5'b11111;
                    endcase
                end

                "G": begin
                    case (row)
                        3'd0: font_row = 5'b01110;
                        3'd1: font_row = 5'b10001;
                        3'd2: font_row = 5'b10000;
                        3'd3: font_row = 5'b10111;
                        3'd4: font_row = 5'b10001;
                        3'd5: font_row = 5'b10001;
                        3'd6: font_row = 5'b01110;
                    endcase
                end

                "L": begin
                    case (row)
                        3'd0: font_row = 5'b10000;
                        3'd1: font_row = 5'b10000;
                        3'd2: font_row = 5'b10000;
                        3'd3: font_row = 5'b10000;
                        3'd4: font_row = 5'b10000;
                        3'd5: font_row = 5'b10000;
                        3'd6: font_row = 5'b11111;
                    endcase
                end

                "N": begin
                    case (row)
                        3'd0: font_row = 5'b10001;
                        3'd1: font_row = 5'b11001;
                        3'd2: font_row = 5'b10101;
                        3'd3: font_row = 5'b10011;
                        3'd4: font_row = 5'b10001;
                        3'd5: font_row = 5'b10001;
                        3'd6: font_row = 5'b10001;
                    endcase
                end

                "R": begin
                    case (row)
                        3'd0: font_row = 5'b11110;
                        3'd1: font_row = 5'b10001;
                        3'd2: font_row = 5'b11110;
                        3'd3: font_row = 5'b10100;
                        3'd4: font_row = 5'b10010;
                        3'd5: font_row = 5'b10001;
                        3'd6: font_row = 5'b10001;
                    endcase
                end

                "U": begin
                    case (row)
                        3'd0: font_row = 5'b10001;
                        3'd1: font_row = 5'b10001;
                        3'd2: font_row = 5'b10001;
                        3'd3: font_row = 5'b10001;
                        3'd4: font_row = 5'b10001;
                        3'd5: font_row = 5'b10001;
                        3'd6: font_row = 5'b11111;
                    endcase
                end

                default: begin
                    font_row = 5'b00000;
                end
            endcase
        end
    endfunction

    // ============================================================
    // 11) 문자 1개 / 단어 전체 픽셀 on 판정
    // ============================================================

    //문자 ch 내부에서 (px, py) 위치가 켜지는 픽셀인지 판단
    function automatic logic char_pixel_on(
        input logic [7:0] ch,
        input integer px,
        input integer py
    );
        logic [2:0] row_idx;
        logic [2:0] col_idx;
        logic [4:0] row_bits;
        begin
            char_pixel_on = 1'b0;

            //이 좌표가 문자 범위 안인지 확인
            //현재 문자 크기가 10x14여서 그 범위 안일 때만 계산
            if (px >= 0 && px < CHAR_PX_W && py >= 0 && py < CHAR_PX_H) begin

                //2배 확대 되서 실제 5x7폰트의 어느 칸인지 구하려면 2로 나눠야함
                //즉 확대전 값
                row_idx = py / SCALE;
                col_idx = px / SCALE;

                //해당 줄의 5비트 패턴을 가져와서 현재 열 위치의 비트가 1인지 확인
                //이 문자 픽셀이 켜져야 하는지 판정
                row_bits = font_row(ch, row_idx);
                char_pixel_on = row_bits[4 - col_idx];
            end
        end
    endfunction

    //단어 전체에서 픽셀 on 판정
    //한 단어 전체를 기준으로 (px, py)가 글자 픽셀인지 판단
    function automatic logic word_pixel_on(
        input logic [2:0] word_id,
        input integer word_x0,
        input integer word_y0,
        input integer px,
        input integer py
    );
        integer rel_x, rel_y;
        integer char_slot;
        integer char_x;
        logic [7:0] ch;
        begin
            word_pixel_on = 1'b0;
            //현재 점이 단어 시작점 기준으로 어디인지 상대좌표 계산
            rel_x = px - word_x0;
            rel_y = py - word_y0;

            //단어 영역 안인지 확인 적어도 y는 문자 높이 안에 있어야 함
            if (rel_x >= 0 && rel_y >= 0 && rel_y < CHAR_PX_H) begin
                //몇 번째 글자인지 계산
                //문자 하나 폭 + 문자 간격 기준으로 현재 위치가 몇 번째 문자에 속하는지 구함
                //ex) 글자폭 10, 간격 2면 한슬롯은 12픽셀
                //ex) rel_x=0~11 는 첫 글자 슬롯
                //ex) rel_x=12~23 는 둘째 글자 슬롯
                char_slot = rel_x / (CHAR_PX_W + GAP_X);
                char_x    = rel_x % (CHAR_PX_W + GAP_X);

                //그 슬롯이 실제 단어 길이 안에 있는지 확인
                if (char_slot < word_len_chars(word_id)) begin
                    //슬롯 안에서도 문자 본체 영역인지 확인 간격 부분이면 글자 픽셀이 아님
                    if (char_x < CHAR_PX_W) begin
                        //그 문자 슬롯에 해당하는 실제 문자를 꺼내고
                        // 그 문자의 해당 위치가 켜지는지 검사
                        //wrod_pixel_on은 문자열 전체 렌더링 판정 함수
                        ch = word_char(word_id, char_slot[3:0]);
                        word_pixel_on = char_pixel_on(ch, char_x, rel_y);
                    end
                end
            end
        end
    endfunction

    //단어 전체가 몇 필섹 폭인지 구함
    function automatic integer word_pixel_width(input logic [2:0] word_id);
        integer n;
        begin
            //문자 수 x 문자폭 + (문자 수 -1) x 간격
            //ex) RED는 3글자이므로 3 x 10 + 2 x 2 = 34픽셀
            //이 값은 중앙 정렬에 사용
            n = word_len_chars(word_id);
            if (n == 0)
                word_pixel_width = 0;
            else
                word_pixel_width = n * CHAR_PX_W + (n - 1) * GAP_X;
        end
    endfunction

    // ============================================================
    // 12) 텍스트 색상 설정
    // ============================================================

    //첫 줄 색상 텍스트 RGB
    logic [3:0] color_text_R, color_text_G, color_text_B;

    //현재 칸의 색상이 RED면 첫 줄 RED 글자를 빨간색으로 그림
    //알 수 없는 경우 흰색 처리 모양
    //모양 텍스트는 항상 흰색
    always_comb begin
        case (disp_color[cur_sec])
            `RED: begin
                color_text_R = 4'hF;
                color_text_G = 4'h0;
                color_text_B = 4'h0;
            end

            `GREEN: begin
                color_text_R = 4'h0;
                color_text_G = 4'hF;
                color_text_B = 4'h0;
            end

            `BLUE: begin
                color_text_R = 4'h0;
                color_text_G = 4'h0;
                color_text_B = 4'hF;
            end

            default: begin
                color_text_R = 4'hF;
                color_text_G = 4'hF;
                color_text_B = 4'hF;
            end
        endcase

    end

    // ============================================================
    // 13) 현재 픽셀이 텍스트 픽셀인지 판단
    // ============================================================


    integer line1_w; //각 줄 폭
    integer line1_x0; // 각 줄 시작 x좌표
    logic   line1_on; // 현재 픽셀이 그 줄의 글자 픽셀인지 여부

    always_comb begin
        //현재 칸에 들어갈 색상 단어와 모양 단어의 전체 폭을 계산
        line1_w  = word_pixel_width(color_word_id);

        //칸 가운데 정렬을 위해 시작 x를 구함
        //ex) 칸 폭이 128이고 단어 폭이 34면
        //시작 x는 (128-34)/2 = 47
        line1_x0 = (CELL_W - line1_w) / 2;

        //기본 값은 둘다 꺼짐
        line1_on = 1'b0;

        //텍스트를 그리는 조건은
        // 현재 픽셀이 유효한 화면 DE랑
        // 현재 칸에 실제 표시할 데이터가 있어야 함 isp_valid[cur_sec]
        if (DE && disp_valid[cur_sec]) begin
            //칸 내부 좌표 (local_x, local_y)가
            //첫 줄 색상 단어의 픽셀인지
            //둘째 줄 모양 단어의 픽셀인지 계산
            //line1_on = 1이면 색상 텍스트 픽셀
            line1_on = word_pixel_on(color_word_id, line1_x0, LINE1_Y, local_x, local_y);
        end
    end

    // ============================================================
    // 14) 최종 RGB 출력
    // ============================================================
    
    //카메라+격자 화면을 우선 통과 출력
    always_comb begin
        out_R = in_R;
        out_G = in_G;
        out_B = in_B;

        //현재 픽셀이 유효 화면 밖이면 검은색 출력
        if (!DE) begin
            out_R = 4'h0;
            out_G = 4'h0;
            out_B = 4'h0;
        end

        //현재 픽셀이 첫 줄 텍스트 픽셀이면
        //입력 연상 대신 텍스트 색으로 덮어씌움
        //색상 단어가 화면위에 그려짐
        else if (line1_on) begin
            out_R = color_text_R;
            out_G = color_text_G;
            out_B = color_text_B;
        end
    end

endmodule

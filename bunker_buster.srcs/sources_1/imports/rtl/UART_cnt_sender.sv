// `timescale 1ns / 1ps

// module uart_cnt_sender (
//     input  logic        clk,
//     input  logic        reset,
//     input  logic        frame_done,
//     input  logic [15:0] max_cnt,
//     input  logic [ 7:0] H,
//     input  logic [ 7:0] S,
//     input  logic [ 7:0] V,
//     input  logic [ 7:0] hint_data,
//     input  logic        data_done,
//     output logic        uart_txd
// );

//   localparam CLK_2S = 200_000_000;

//   logic [$clog2(CLK_2S)-1:0] clk_count;
//   logic tick;

//   logic [15:0] max_cnt_reg;
//   logic [7:0] H_reg;
//   logic [7:0] S_reg;
//   logic [7:0] V_reg;
//   logic [7:0] hint_data_reg;
//   logic [7:0] result_color_reg;

//   typedef enum {
//     IDLE,
//     WAIT_DATA_DONE,
//     DATA_SEND
//   } state_t;
//   state_t state;

//   logic [7:0] write_data;
//   logic [10:0] index;
//   logic w_wr, wr;
//   logic w_tx_busy, w_tx_empty, w_tx_full;
//   logic [7:0] w_tx_data;
//   assign wr = w_wr && !w_tx_full;

// localparam CLK_2S = 200_000_000;

//   logic [$clog2(CLK_2S)-1:0] clk_count;

//   always_ff @(posedge clk, posedge reset) begin
//     if (reset) begin
//       clk_count <= 0;
//     end else begin
//       case (state)
//         IDLE: begin
//           wr <= 0;
//           if (clk_count == CLK_2S - 1) begin
//             clk_count <= 0;
//             state <= DATA_SEND;
//           end else begin
//             clk_count <= clk_count + 1;
//           end

//         end
//         WAIT_DATA_DONE: begin
//           if (data_done) begin
//             state <= DATA_SEND;
//             H_reg <= H;
//             S_reg <= S;
//             V_reg <= V;
//             hint_data_reg <= hint_data;
//             max_cnt_reg <= max_cnt;
//             result_color_reg <= result_color;
//           end
//         end

//         DATA_SEND: begin
//           if (w_tx_full) begin
//             w_wr  <= 1;
//             index <= index + 1;
//             //             case (index)
//             // //                : write_data
//             //             endcase

//           end else begin
//             w_wr <= 0;
//           end

//         end

//       endcase

//     end
//   end





//   FIFO u_UI_PC_tx_fifo (
//       .clk(clk),
//       .reset(reset),
//       .wr   (wr),
//       .rd(~w_tx_busy),
//       .wdata(write_data),
//       .rdata(w_tx_rdata),
//       .full(w_tx_full),
//       .empty(w_tx_empty)
//   );

//   uart_tx_s #(
//       .CLK_FREQ (100_000_000),
//       .BAUD_RATE(115200)
//   ) u_uart_tx_s (
//       .clk  (clk),
//       .reset(reset),
//       .data (w_tx_rdata),
//       .valid(~w_tx_empty),  // 1클럭 펄스로 전송 요청
//       .tx   (uart_txd),
//       .busy (w_tx_busy)
//   );


// endmodule







// `timescale 1ns / 1ps

// // 115200 baud, 100MHz 클럭
// // 100_000_000 / 115200 = 868 클럭/비트

module uart_tx_s #(
    parameter CLK_FREQ  = 100_000_000,
    parameter BAUD_RATE = 115200
) (
    input  logic       clk,
    input  logic       reset,
    input  logic [7:0] data,
    input  logic       valid,  // 1클럭 펄스로 전송 요청
    output logic       tx,
    output logic       busy
);
  localparam CLKS_PER_BIT = CLK_FREQ / BAUD_RATE;  // 868

  typedef enum logic [1:0] {
    ST_IDLE  = 2'd0,
    ST_START = 2'd1,
    ST_DATA  = 2'd2,
    ST_STOP  = 2'd3
  } state_t;

  state_t       state;
  logic   [9:0] clk_cnt;
  logic   [2:0] bit_idx;
  logic   [7:0] tx_data;

  always_ff @(posedge clk or posedge reset) begin
    if (reset) begin
      state   <= ST_IDLE;
      tx      <= 1'b1;
      busy    <= 1'b0;
      clk_cnt <= 0;
      bit_idx <= 0;
    end else begin
      case (state)
        ST_IDLE: begin
          tx   <= 1'b1;
          busy <= 1'b0;
          if (valid) begin
            tx_data <= data;
            state   <= ST_START;
            busy    <= 1'b1;
            clk_cnt <= 0;
          end
        end

        ST_START: begin
          tx <= 1'b0;  // start bit
          if (clk_cnt == CLKS_PER_BIT - 1) begin
            clk_cnt <= 0;
            bit_idx <= 0;
            state   <= ST_DATA;
          end else clk_cnt <= clk_cnt + 1;
        end

        ST_DATA: begin
          tx <= tx_data[bit_idx];
          if (clk_cnt == CLKS_PER_BIT - 1) begin
            clk_cnt <= 0;
            if (bit_idx == 3'd7) begin
              state <= ST_STOP;
            end else bit_idx <= bit_idx + 1;
          end else clk_cnt <= clk_cnt + 1;
        end

        ST_STOP: begin
          tx <= 1'b1;  // stop bit
          if (clk_cnt == CLKS_PER_BIT - 1) begin
            clk_cnt <= 0;
            state   <= ST_IDLE;
            busy    <= 1'b0;
          end else clk_cnt <= clk_cnt + 1;
        end
      endcase
    end
  end
endmodule

`timescale 1ns / 1ps

module uart_cnt_sender (
    input  logic        clk,
    input  logic        reset,
    input  logic        frame_done,
    input  logic [15:0] max_cnt,
    input  logic [ 7:0] H,
    input  logic [ 7:0] S,
    input  logic [ 7:0] V,
    input  logic [ 7:0] hint_data,
    input  logic        data_done,
    output logic        uart_txd
);

  // ------------------------------------------------------------
  // hint_data 분해
  // [7:6] = shape
  // [5:4] = color
  // [3:0] = section
  // ------------------------------------------------------------
  logic [ 3:0] section_reg;
  logic [ 1:0] color_reg;
  logic [ 1:0] shape_reg;

  logic [15:0] max_cnt_reg;
  logic [7:0] H_reg, S_reg, V_reg;
  logic [7:0] hint_data_reg;

  // ------------------------------------------------------------
  // UART FIFO 연결 신호
  // ------------------------------------------------------------
  logic       fifo_wr;
  logic       fifo_rd;
  logic [7:0] fifo_wdata;
  logic [7:0] fifo_rdata;
  logic       fifo_full;
  logic       fifo_empty;
  logic       tx_busy;

  assign fifo_rd = ~tx_busy & ~fifo_empty;

  // ------------------------------------------------------------
  // 상태 정의
  // ------------------------------------------------------------
  typedef enum logic [1:0] {
    IDLE,
    WAIT_DATA_DONE,
    DATA_SEND
  } state_t;

  state_t state;

  // ------------------------------------------------------------
  // 메시지 인덱스
  // 총 길이:
  // "SEC:x SHP:x COL:x CNT:dddd H:ddd S:ddd V:ddd\r\n"
  //
  // index:
  //  0 S
  //  1 E
  //  2 C
  //  3 :
  //  4 section
  //  5 ' '
  //  6 S
  //  7 H
  //  8 P
  //  9 :
  // 10 shape
  // 11 ' '
  // 12 C
  // 13 O
  // 14 L
  // 15 :
  // 16 color
  // 17 ' '
  // 18 C
  // 19 N
  // 20 T
  // 21 :
  // 22 max_cnt 천의 자리
  // 23 max_cnt 백의 자리
  // 24 max_cnt 십의 자리
  // 25 max_cnt 일의 자리
  // 26 ' '
  // 27 H
  // 28 :
  // 29 H 백의 자리
  // 30 H 십의 자리
  // 31 H 일의 자리
  // 32 ' '
  // 33 S
  // 34 :
  // 35 S 백의 자리
  // 36 S 십의 자리
  // 37 S 일의 자리
  // 38 ' '
  // 39 V
  // 40 :
  // 41 V 백의 자리
  // 42 V 십의 자리
  // 43 V 일의 자리
  // 44 \r
  // 45 \n
  // ------------------------------------------------------------
  logic [5:0] index;

  // ------------------------------------------------------------
  // 숫자 -> ASCII
  // ------------------------------------------------------------
  function automatic [7:0] to_ascii_digit(input [3:0] num);
    begin
      to_ascii_digit = 8'd48 + num;  // "0" + num
    end
  endfunction

  function automatic [7:0] dec_thousands_16(input [15:0] val);
    begin
      dec_thousands_16 = 8'd48 + ((val / 1000) % 10);
    end
  endfunction

  function automatic [7:0] dec_hundreds_16(input [15:0] val);
    begin
      dec_hundreds_16 = 8'd48 + ((val / 100) % 10);
    end
  endfunction

  function automatic [7:0] dec_tens_16(input [15:0] val);
    begin
      dec_tens_16 = 8'd48 + ((val / 10) % 10);
    end
  endfunction

  function automatic [7:0] dec_ones_16(input [15:0] val);
    begin
      dec_ones_16 = 8'd48 + (val % 10);
    end
  endfunction

  function automatic [7:0] dec_hundreds_8(input [7:0] val);
    begin
      dec_hundreds_8 = 8'd48 + ((val / 100) % 10);
    end
  endfunction

  function automatic [7:0] dec_tens_8(input [7:0] val);
    begin
      dec_tens_8 = 8'd48 + ((val / 10) % 10);
    end
  endfunction

  function automatic [7:0] dec_ones_8(input [7:0] val);
    begin
      dec_ones_8 = 8'd48 + (val % 10);
    end
  endfunction

  // ------------------------------------------------------------
  // 현재 index에 따라 보낼 문자 결정
  // ------------------------------------------------------------
  always_comb begin
    fifo_wdata = 8'h00;

    case (index)
      6'd0: fifo_wdata = "S";
      6'd1: fifo_wdata = "E";
      6'd2: fifo_wdata = "C";
      6'd3: fifo_wdata = ":";
      6'd4: fifo_wdata = to_ascii_digit(section_reg);
      6'd5: fifo_wdata = " ";

      6'd6:  fifo_wdata = "S";
      6'd7:  fifo_wdata = "H";
      6'd8:  fifo_wdata = "P";
      6'd9:  fifo_wdata = ":";
      6'd10: fifo_wdata = to_ascii_digit({2'b00, shape_reg});
      6'd11: fifo_wdata = " ";

      6'd12: fifo_wdata = "C";
      6'd13: fifo_wdata = "O";
      6'd14: fifo_wdata = "L";
      6'd15: fifo_wdata = ":";
      6'd16: fifo_wdata = to_ascii_digit({2'b00, color_reg});
      6'd17: fifo_wdata = " ";

      6'd18: fifo_wdata = "C";
      6'd19: fifo_wdata = "N";
      6'd20: fifo_wdata = "T";
      6'd21: fifo_wdata = ":";
      6'd22: fifo_wdata = dec_thousands_16(max_cnt_reg);
      6'd23: fifo_wdata = dec_hundreds_16(max_cnt_reg);
      6'd24: fifo_wdata = dec_tens_16(max_cnt_reg);
      6'd25: fifo_wdata = dec_ones_16(max_cnt_reg);
      6'd26: fifo_wdata = " ";

      6'd27: fifo_wdata = "H";
      6'd28: fifo_wdata = ":";
      6'd29: fifo_wdata = dec_hundreds_8(H_reg);
      6'd30: fifo_wdata = dec_tens_8(H_reg);
      6'd31: fifo_wdata = dec_ones_8(H_reg);
      6'd32: fifo_wdata = " ";

      6'd33: fifo_wdata = "S";
      6'd34: fifo_wdata = ":";
      6'd35: fifo_wdata = dec_hundreds_8(S_reg);
      6'd36: fifo_wdata = dec_tens_8(S_reg);
      6'd37: fifo_wdata = dec_ones_8(S_reg);
      6'd38: fifo_wdata = " ";

      6'd39: fifo_wdata = "V";
      6'd40: fifo_wdata = ":";
      6'd41: fifo_wdata = dec_hundreds_8(V_reg);
      6'd42: fifo_wdata = dec_tens_8(V_reg);
      6'd43: fifo_wdata = dec_ones_8(V_reg);

      6'd44: fifo_wdata = 8'h0D;  // \r
      6'd45: fifo_wdata = 8'h0A;  // \n

      default: fifo_wdata = 8'h00;
    endcase
  end

  // ------------------------------------------------------------
  // 메인 FSM
  // ------------------------------------------------------------
  localparam CLK_2S = 200_000_000;

  logic [$clog2(CLK_2S)-1:0] clk_count;

  always_ff @(posedge clk or posedge reset) begin
    if (reset) begin
      state         <= IDLE;
      index         <= 0;
      fifo_wr       <= 1'b0;

      max_cnt_reg   <= 16'd0;
      H_reg         <= 8'd0;
      S_reg         <= 8'd0;
      V_reg         <= 8'd0;
      hint_data_reg <= 8'd0;
      section_reg   <= 4'd0;
      color_reg     <= 2'd0;
      shape_reg     <= 2'd0;
    end else begin
      fifo_wr <= 1'b0;  // 기본값

      case (state)
        IDLE: begin
          index <= 0;
          if (clk_count == CLK_2S - 1) begin
            clk_count <= 0;
            state <= WAIT_DATA_DONE;
          end else begin
            clk_count <= clk_count + 1;
          end

        end

        WAIT_DATA_DONE: begin
          if (data_done) begin
            max_cnt_reg   <= max_cnt;
            H_reg         <= H;
            S_reg         <= S;
            V_reg         <= V;
            hint_data_reg <= hint_data;

            section_reg   <= hint_data[3:0];
            color_reg     <= hint_data[5:4];
            shape_reg     <= hint_data[7:6];

            index         <= 0;
            state         <= DATA_SEND;
          end
        end

        DATA_SEND: begin
          // FIFO가 안 찼으면 한 글자씩 넣기
          if (!fifo_full) begin
            fifo_wr <= 1'b1;

            if (index == 6'd45) begin
              index <= 0;
              state <= IDLE;
            end else begin
              index <= index + 1'b1;
            end
          end
        end

        default: begin
          state <= IDLE;
        end
      endcase
    end
  end

  // ------------------------------------------------------------
  // FIFO
  // wr : sender가 넣음
  // rd : uart가 안 바쁠 때 자동으로 하나 꺼냄
  // ------------------------------------------------------------
  FIFO u_UI_PC_tx_fifo (
      .clk  (clk),
      .reset(reset),
      .wr   (fifo_wr),
      .rd   (fifo_rd),
      .wdata(fifo_wdata),
      .rdata(fifo_rdata),
      .full (fifo_full),
      .empty(fifo_empty)
  );

  // ------------------------------------------------------------
  // UART TX
  // valid는 fifo에서 데이터가 있을 때마다 1
  // busy=1이면 전송중
  // ------------------------------------------------------------
  uart_tx_s #(
      .CLK_FREQ (100_000_000),
      .BAUD_RATE(115200)
  ) u_uart_tx_s (
      .clk  (clk),
      .reset(reset),
      .data (fifo_rdata),
      .valid(~fifo_empty && ~tx_busy),
      .tx   (uart_txd),
      .busy (tx_busy)
  );

endmodule

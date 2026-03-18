`timescale 1ns / 1ps

module FIFO (
    input        clk,
    input        reset,
    input        wr,
    input        rd,
    input  [7:0] wdata,
    output [7:0] rdata,
    output       full,
    output       empty
);

    wire [7:0] w_wptr, w_rptr;

    register_file u_register_file (
        .clk(clk),
        .waddr(w_wptr),
        .raddr(w_rptr),
        .wdata(wdata),
        .wr(~full&wr), //이걸 top에서 처리. write하는 조건이 full이 아니여야 하고, wr신호가 들어와야 하잖아.
        //.rd(~empty&rd),
        .rdata(rdata)
    );

    fifo_control_unit u_fifo_control_unit (
        .clk(clk),
        .reset(reset),
        .wr(wr),
        .rd(rd),
        .w_ptr(w_wptr),
        .r_ptr(w_rptr),
        .full(full),
        .empty(empty)
    );
endmodule

module register_file (
    input            clk,
    input      [7:0] waddr,
    input      [7:0] raddr,
    input      [7:0] wdata,
   // input            rd,
    input            wr,
    output reg [7:0] rdata
);
    logic [7:0] register_file[0:255];

    always_ff @(posedge clk) begin
        if (wr) begin
            register_file[waddr] <= wdata;
        end 
        //if (rd) begin
            //rdata <= register_file[raddr];
        //end
    end

    //read, pop combinational logic 
    assign rdata = register_file[raddr];
    
endmodule

module fifo_control_unit (
    input        clk,
    input        reset,
    input        wr,
    input        rd,
    output [7:0] w_ptr,
    output [7:0] r_ptr,
    output       full,
    output       empty
);

    logic c_full, n_full, c_empty, n_empty;
    logic [7:0] c_wptr, n_wptr, c_rptr, n_rptr;

    assign full  = c_full;
    assign empty = c_empty;
    assign w_ptr = c_wptr;
    assign r_ptr = c_rptr;

    //state register logic
    always_ff @(posedge clk, posedge reset) begin
        if (reset) begin
            c_full  <= 1'b0;
            c_empty <= 1'b1;
            c_wptr  <= 0;
            c_rptr  <= 0;
        end else begin
            c_full  <= n_full;
            c_empty <= n_empty;
            c_wptr  <= n_wptr;
            c_rptr  <= n_rptr;
        end
    end

    //next_state logic
    always_comb begin
        //초기화를 통해서 latch를 없애버린다.
        n_full  = c_full;
        n_empty = c_empty;
        n_wptr  = c_wptr;
        n_rptr  = c_rptr;
        case ({
            wr, rd
        })  //state wr,rd or push/pop
            /*2'b00 : begin //IDLE
        할 거 없으니까 삭제
        end*/
            2'b01: begin  //POP
                n_full = 1'b0;
                if (!c_empty) begin
                    n_rptr = c_rptr + 1;
                    if (n_rptr == c_wptr) begin
                        n_empty = 1;
                    end
                end
            end

            2'b10: begin  //PUSH
                n_empty = 1'b0;
                if (!c_full) begin
                    n_wptr = c_wptr + 1;
                    if (c_rptr == n_wptr) begin
                        n_full = 1'b1;
                    end
                end
            end

            2'b11: begin  //PUSH/POP
                if (c_empty) begin
                    n_empty = 1'b0;
                    n_wptr  = c_wptr + 1;
                end else if (c_full) begin
                    n_full = 1'b0;
                    n_rptr = c_rptr + 1;
                end else begin
                    n_wptr = c_wptr + 1;
                    n_rptr = c_rptr + 1;
                end
            end
            //if else를 반복해서 모든 경우의 수를 직접 써줘서 latch를 방지한다기 보다는 
            //초기화를 통해서 latch를 없애버린다.
        endcase
    end
endmodule

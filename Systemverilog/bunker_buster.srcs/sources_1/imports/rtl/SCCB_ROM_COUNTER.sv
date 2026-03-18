module SCCB_ROM_COUNTER(

   input  logic clk,
   input  logic reset,
   input  logic tx_done,   //SCCB 통신 끝나면 받음

   output logic [6:0] addr

);

always_ff @(posedge clk or posedge reset) begin
   if(reset)
       addr <= 0;
   else if(tx_done && addr < 79) //ROM[20]부터는 X값임
       addr <= addr + 1;
end

endmodule

/*
module SCCB_ROM_COUNTER(

   input  logic clk,
   input  logic reset,
   input  logic tx_done,   //SCCB 통신 끝나면 받음

   output logic [6:0] addr

);

always_ff @(posedge clk or posedge reset) begin
   if(reset)
       addr <= 0;
   else if(tx_done && addr < 75) //ROM[20]부터는 X값임
       addr <= addr + 1;
end

endmodule
*/

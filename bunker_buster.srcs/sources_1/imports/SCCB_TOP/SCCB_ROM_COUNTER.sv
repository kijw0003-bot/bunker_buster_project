// module SCCB_ROM_COUNTER (
// 
//     input logic clk,
//     input logic reset,
//     input logic tx_done, //SCCB 통신 끝나면 받음
// 
//     output logic [6:0] addr
// 
// );
// 
//   logic [$clog2(3_000_000)-1:0] counter;  //30ms
// 
//   always_ff @(posedge clk or posedge reset) begin
//     if (reset) begin
//       addr <= 0;
//       counter <= 0;
//     end else begin
//       if (addr == 0) begin
// 
//         if (tx_done) begin
// 
//           if (counter == 3_000_000 - 1) begin
// 
//             addr <= 1;
//             counter <= 0;
// 
//           end
//           begin
//             counter <= counter + 1;
//           end
// 
//         end
// 
//       end else begin
//         if (tx_done && addr < 18) begin
//           addr <= addr + 1;
//         end
//       end
// 
//     end
// 
// 
//   end
// 
// endmodule

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

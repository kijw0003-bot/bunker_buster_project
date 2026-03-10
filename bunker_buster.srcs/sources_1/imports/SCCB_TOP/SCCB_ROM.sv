`timescale 1ns / 1ps
`include "SCCB_Define.vh"

module SCCB_ROM (
    input  logic [6:0] addr,
    output logic [7:0] reg_addr,
    output logic [7:0] reg_data
);

  logic [15:0] rom[0:76];


  initial begin

// [0] Basic Settings
rom[0]  = 16'h3A04;
rom[1]  = 16'h1200;
rom[2]  = 16'h13E7;
rom[3]  = 16'h6F9F;
rom[4]  = 16'hB084;
rom[5]  = 16'h703A;
rom[6]  = 16'h7135;
rom[7]  = 16'h7211;
rom[8]  = 16'h73F0;

// [9-24] Gamma Curve
rom[9]  = 16'h7A20;
rom[10] = 16'h7B10;
rom[11] = 16'h7C1E;
rom[12] = 16'h7D35;
rom[13] = 16'h7E5A;
rom[14] = 16'h7F69;
rom[15] = 16'h8076;
rom[16] = 16'h8180;
rom[17] = 16'h8288;
rom[18] = 16'h838F;
rom[19] = 16'h8496;
rom[20] = 16'h85A3;
rom[21] = 16'h86AF;
rom[22] = 16'h87C4;
rom[23] = 16'h88D7;
rom[24] = 16'h89E8;

// [25-41] AGC / AEC
rom[25] = 16'h0000;
rom[26] = 16'h1000;
rom[27] = 16'h0D40;
rom[28] = 16'h1418;
rom[29] = 16'hA505;
rom[30] = 16'hAB07;
rom[31] = 16'h2495;
rom[32] = 16'h2533;
rom[33] = 16'h26E3;
rom[34] = 16'h9F78;
rom[35] = 16'hA068;
rom[36] = 16'hA103;
rom[37] = 16'hA6D8;
rom[38] = 16'hA7D8;
rom[39] = 16'hA8F0;
rom[40] = 16'hA990;
rom[41] = 16'hAA94;

// [42-49] QVGA
rom[42] = 16'h1211;
rom[43] = 16'h0C04;
rom[44] = 16'h3E19;
rom[45] = 16'h703A;
rom[46] = 16'h7135;
rom[47] = 16'h7211;
rom[48] = 16'h73F1;
rom[49] = 16'hA202;

// [50-55] Frame Control
rom[50] = 16'h1715;
rom[51] = 16'h1803;
rom[52] = 16'h3200;
rom[53] = 16'h1903;
rom[54] = 16'h1A7B;
rom[55] = 16'h0300;

// [56-58] RGB565
rom[56] = 16'h1214;
rom[57] = 16'h40D0;
rom[58] = 16'h8C00;

// [59-65] User
rom[59] = 16'h4200;
rom[60] = 16'h13E7;
rom[61] = 16'hAA14;
rom[62] = 16'h5587;
rom[63] = 16'h1418;
rom[64] = 16'h3F0A;
rom[65] = 16'h5650;

// [66-72] Saturation
rom[66] = 16'h4F8F;
rom[67] = 16'h508F;
rom[68] = 16'h5100;
rom[69] = 16'h5230;
rom[70] = 16'h538C;
rom[71] = 16'h54B6;
rom[72] = 16'h589E;

// [73-75] Clock / Misc
rom[73] = 16'h1101;
rom[74] = 16'h6B4A;
rom[75] = 16'h1E07;


  end


  assign reg_addr = rom[addr][15:8];
  assign reg_data = rom[addr][7:0];

endmodule


//best//
// `timescale 1ns / 1ps
// `include "SCCB_Define.vh"

// module SCCB_ROM (
//     input  logic [5:0] addr,
//     output logic [7:0] reg_addr,
//     output logic [7:0] reg_data
// );

// logic [15:0] rom[0:63];

// initial begin
//     rom[0]  = {`REG_COM7, 8'h80};  // reset

//     rom[1]  = {`REG_CLKRC, 8'h01};

//     rom[2]  = {`REG_TSLB, 8'h04};
//     rom[3]  = {`REG_COM7, 8'h04};   // RGB
//     rom[4]  = {`REG_COM15, 8'hD0};  // RGB565
//     rom[5]  = {`REG_COM13, 8'h88};

//     rom[6]  = {`REG_COM9, 8'h38};

//     rom[7]  = {`REG_COM3, 8'h04};
//     rom[8]  = {`REG_COM14, 8'h19};

//     rom[9]  = {`REG_SCALING_XSC, 8'h3A};
//     rom[10] = {`REG_SCALING_YSC, 8'h35};
//     rom[11] = {`REG_SCALING_DCWCTR, 8'h11};
//     rom[12] = {`REG_SCALING_PCLK_DIV, 8'hF1};

//     rom[13] = {`REG_HSTART, 8'h16};
//     rom[14] = {`REG_HSTOP, 8'h04};
//     rom[15] = {`REG_HREF, 8'h24};

//     rom[16] = {`REG_VSTART, 8'h02};
//     rom[17] = {`REG_VSTOP, 8'h7A};
//     rom[18] = {`REG_VREF, 8'h0A};
// end

// assign reg_addr = rom[addr][15:8];
// assign reg_data = rom[addr][7:0];

// endmodule


// // [0] Dummy
// rom[0]  = 16'h1280; //resety
// //delay30ms
// // [1-9] Basic Settings
// rom[1]  = 16'h3A04;
// rom[2]  = 16'h1200;
// rom[3]  = 16'h13E7;
// rom[4]  = 16'h6F9F;
// rom[5]  = 16'hB084;
// rom[6]  = 16'h703A;
// rom[7]  = 16'h7135;
// rom[8]  = 16'h7211;
// rom[9]  = 16'h73F0;

// // [10-25] Gamma Curve
// rom[10] = 16'h7A20;
// rom[11] = 16'h7B10;
// rom[12] = 16'h7C1E;
// rom[13] = 16'h7D35;
// rom[14] = 16'h7E5A;
// rom[15] = 16'h7F69;
// rom[16] = 16'h8076;
// rom[17] = 16'h8180;
// rom[18] = 16'h8288;
// rom[19] = 16'h838F;
// rom[20] = 16'h8496;
// rom[21] = 16'h85A3;
// rom[22] = 16'h86AF;
// rom[23] = 16'h87C4;
// rom[24] = 16'h88D7;
// rom[25] = 16'h89E8;

// // [26-42] AGC / AEC
// rom[26] = 16'h0000;
// rom[27] = 16'h1000;
// rom[28] = 16'h0D40;
// rom[29] = 16'h1418;
// rom[30] = 16'hA505;
// rom[31] = 16'hAB07;
// rom[32] = 16'h2495;
// rom[33] = 16'h2533;
// rom[34] = 16'h26E3;
// rom[35] = 16'h9F78;
// rom[36] = 16'hA068;
// rom[37] = 16'hA103;
// rom[38] = 16'hA6D8;
// rom[39] = 16'hA7D8;
// rom[40] = 16'hA8F0;
// rom[41] = 16'hA990;
// rom[42] = 16'hAA94;

// // [43-50] QVGA
// rom[43] = 16'h1211;
// rom[44] = 16'h0C04;
// rom[45] = 16'h3E19;
// rom[46] = 16'h703A;
// rom[47] = 16'h7135;
// rom[48] = 16'h7211;
// rom[49] = 16'h73F1;
// rom[50] = 16'hA202;

// // [51-56] Frame Control
// rom[51] = 16'h1715;
// rom[52] = 16'h1803;
// rom[53] = 16'h3200;
// rom[54] = 16'h1903;
// rom[55] = 16'h1A7B;
// rom[56] = 16'h0300;

// // [57-59] RGB565
// rom[57] = 16'h1214;
// rom[58] = 16'h40D0;
// rom[59] = 16'h8C00;

// // [60-66] User
// rom[60] = 16'h4200;
// rom[61] = 16'h13E7;
// rom[62] = 16'hAA14;
// rom[63] = 16'h5587;
// rom[64] = 16'h1418;
// rom[65] = 16'h3F0A;
// rom[66] = 16'h5650;

// // [67-73] Saturation
// rom[67] = 16'h4F8F;
// rom[68] = 16'h508F;
// rom[69] = 16'h5100;
// rom[70] = 16'h5230;
// rom[71] = 16'h538C;
// rom[72] = 16'h54B6;
// rom[73] = 16'h589E;

// // [74-76] Clock
// rom[74] = 16'h1101;
// rom[75] = 16'h6B4A;
// rom[76] = 16'h1E07;





`timescale 1ns / 1ps
`include "SCCB_Define.vh"

module SCCB_ROM (
    input  logic [6:0] addr,
    output logic [7:0] reg_addr,
    output logic [7:0] reg_data
);

  // 암부 붉은기 제거 및 선명도 보강을 위해 90개(0~89) 구성
  logic [15:0] rom[0:89];

  initial begin
    // [0] Software Reset
    rom[0]  = 16'h1280; 

    // [1-9] Basic Settings
    rom[1]  = 16'h3A04;
    rom[2]  = 16'h1200;
    rom[3]  = 16'h13E7; // COM8: AEC, AGC, AWB ON
    rom[4]  = 16'h6F9F;
    rom[5]  = 16'hB084;
    rom[6]  = 16'h703A;
    rom[7]  = 16'h7135;
    rom[8]  = 16'h7211;
    rom[9]  = 16'h73F0;

    // [10-25] Gamma Curve (표준 감마 유지)
    rom[10] = 16'h7A20; rom[11] = 16'h7B10; rom[12] = 16'h7C1E; rom[13] = 16'h7D35;
    rom[14] = 16'h7E5A; rom[15] = 16'h7F69; rom[16] = 16'h8076; rom[17] = 16'h8180;
    rom[18] = 16'h8288; rom[19] = 16'h838F; rom[20] = 16'h8496; rom[21] = 16'h85A3;
    rom[22] = 16'h86AF; rom[23] = 16'h87C4; rom[24] = 16'h88D7; rom[25] = 16'h89E8;

    // [26-42] AGC / AEC / Exposure (노출 및 게인 제어)
    rom[26] = 16'h0000;
    rom[27] = 16'h1000;
    rom[28] = 16'h0D40;
    rom[29] = 16'h1418;
    rom[30] = 16'hA505;
    rom[31] = 16'hAB07;
    rom[32] = 16'h2495;
    rom[33] = 16'h2533;
    rom[34] = 16'h26E3;
    rom[35] = 16'h9F78;
    rom[36] = 16'hA068;
    rom[37] = 16'hA103;
    rom[38] = 16'hA6D8;
    rom[39] = 16'hA7D8;
    rom[40] = 16'hA8F0;
    rom[41] = 16'hA990;
    rom[42] = 16'hAA94;

    // [43-50] QVGA Resolution (320x240)
    rom[43] = 16'h1211;
    rom[44] = 16'h0C04;
    rom[45] = 16'h3E19;
    rom[46] = 16'h703A;
    rom[47] = 16'h7135;
    rom[48] = 16'h7211;
    rom[49] = 16'h73F1;
    rom[50] = 16'hA202;

    // [51-56] Frame Control
    rom[51] = 16'h1715; 
    rom[52] = 16'h1803; 
    rom[53] = 16'h3200; 
    rom[54] = 16'h1903; 
    rom[55] = 16'h1A7B;
    rom[56] = 16'h0300;

    // [57-59] RGB565 Output
    rom[57] = 16'h1214; 
    rom[58] = 16'h40D0; 
    rom[59] = 16'h8C00; 

    // [60-66] 화질 보정 (대비 및 선명도 최적화)
    rom[60] = 16'h4200; 
    rom[61] = 16'h13E7; 
    rom[62] = 16'hAA14; 
    rom[63] = 16'h5500; // Brightness
    rom[64] = 16'h1418; 
    rom[65] = 16'h3F08; // Edge 강도 향상 (04 -> 08): 외곽선을 더 뚜렷하게
    rom[66] = 16'h5650; // Contrast

    // [67-73] Saturation (색상 정확도 유지)
    rom[67] = 16'h4FB3; // MTX1
    rom[68] = 16'h50B3; // MTX2
    rom[69] = 16'h5100; // MTX3
    rom[70] = 16'h523D; // MTX4
    rom[71] = 16'h53B0; // MTX5
    rom[72] = 16'h54E4; // MTX6
    rom[73] = 16'h589E; 

    // [74-76] Clock / Misc
    rom[74] = 16'h1101; 
    rom[75] = 16'h6B4A; 
    rom[76] = 16'h1E07; 

    // [77-89] ★검정색 빨간끼 제거 및 선명도 강화 섹션★
    // rom[77] = 16'h4108; // COM16: Edge Enhancement On
    // rom[78] = 16'h3D80; // COM13: UV 가변 채도 해제 (무지개 노이즈 방지)
    // rom[79] = 16'h1500; // COM10
    // rom[80] = 16'hB10C; // ABLC: Black Level 보정 강화 (검은색 들뜸 및 빨간기 억제)
    // rom[81] = 16'hB20E; // ABLC 오프셋 조정
    // rom[82] = 16'hB380; // ABLC 타겟 설정
    // rom[83] = 16'h138F; // COM8: AWB 알고리즘 최적화
    // rom[84] = 16'h0210; // Red Gain을 표준으로 복구 (검은색 빨간색 번짐 방지)
    // rom[85] = 16'h0110; // Blue Gain 표준
    // rom[86] = 16'h76E1; // OV7670 특정 노이즈 제거 필터링
    // rom[87] = 16'h4E20; // MTX 오프셋 보정 (R-Channel 암부 보정)
    // rom[88] = 16'h4F10; // MTX 오프셋 보정 (G-Channel 암부 보정)
    // rom[89] = 16'h5010; // MTX 오프셋 보정 (B-Channel 암부 보정)
    rom[77] = 16'h4108; // COM16: Edge Enhancement
    rom[78] = 16'h3D00; // COM13: 0x80→0x00 (UV saturation 끄기)
    rom[79] = 16'h1500; // COM10
    rom[80] = 16'hB100; // ABLC OFF (노이즈 원인)
    rom[81] = 16'hB200; // ABLC 오프셋 OFF
    rom[82] = 16'hB300; // ABLC 타겟 OFF
    rom[83] = 16'h13E7; // COM8 원래값 유지
    rom[84] = 16'h0240; // Red Gain
    rom[85] = 16'h0140; // Blue Gain
    rom[86] = 16'h76E1; // 노이즈 필터
    rom[87] = 16'h4F40; // MTX1 원복
    rom[88] = 16'h5034; // MTX2 원복
    rom[89] = 16'h5100; // MTX3 원복
  end

  assign reg_addr = rom[addr][15:8];
  assign reg_data = rom[addr][7:0];

endmodule


/*
`timescale 1ns / 1ps
`include "SCCB_Define.vh"

module SCCB_ROM (
    input  logic [6:0] addr,
    output logic [7:0] reg_addr,
    output logic [7:0] reg_data
);

  // 안정성을 위해 불필요한 보정치를 제거하고 80개(0~79)로 최적화
  logic [15:0] rom[0:79];

  initial begin
    // [0] Software Reset
    rom[0]  = 16'h1280; 

    // [1-9] Basic Settings (안정적인 타이밍 및 클럭 설정)
    rom[1]  = 16'h3A04;
    rom[2]  = 16'h1200;
    rom[3]  = 16'h13E7; // COM8: AEC, AGC, AWB ON
    rom[4]  = 16'h6F9F;
    rom[5]  = 16'hB084;
    rom[6]  = 16'h703A;
    rom[7]  = 16'h7135;
    rom[8]  = 16'h7211;
    rom[9]  = 16'h73F0;

    // [10-25] Gamma Curve (업로드된 OV7670_REG.h의 표준 값 적용)
    // 인위적인 감마 조정보다 센서 표준값이 노이즈 억제에 유리합니다.
    rom[10] = 16'h7A20; rom[11] = 16'h7B10; rom[12] = 16'h7C1E; rom[13] = 16'h7D35;
    rom[14] = 16'h7E5A; rom[15] = 16'h7F69; rom[16] = 16'h8076; rom[17] = 16'h8180;
    rom[18] = 16'h8288; rom[19] = 16'h838F; rom[20] = 16'h8496; rom[21] = 16'h85A3;
    rom[22] = 16'h86AF; rom[23] = 16'h87C4; rom[24] = 16'h88D7; rom[25] = 16'h89E8;

    // [26-42] AGC / AEC / Exposure 제어
    rom[26] = 16'h0000;
    rom[27] = 16'h1000;
    rom[28] = 16'h0D40;
    rom[29] = 16'h1418;
    rom[30] = 16'hA505;
    rom[31] = 16'hAB07;
    rom[32] = 16'h2495;
    rom[33] = 16'h2533;
    rom[34] = 16'h26E3;
    rom[35] = 16'h9F78;
    rom[36] = 16'hA068;
    rom[37] = 16'hA103;
    rom[38] = 16'hA6D8;
    rom[39] = 16'hA7D8;
    rom[40] = 16'hA8F0;
    rom[41] = 16'hA990;
    rom[42] = 16'hAA94;

    // [43-50] QVGA Resolution (320x240) 타이밍
    rom[43] = 16'h1211;
    rom[44] = 16'h0C04;
    rom[45] = 16'h3E19;
    rom[46] = 16'h703A;
    rom[47] = 16'h7135;
    rom[48] = 16'h7211;
    rom[49] = 16'h73F1;
    rom[50] = 16'hA202;

    // [51-56] Frame Control (가장 안정적인 윈도우 설정)
    rom[51] = 16'h1715; 
    rom[52] = 16'h1803; 
    rom[53] = 16'h3200; 
    rom[54] = 16'h1903; 
    rom[55] = 16'h1A7B;
    rom[56] = 16'h0300;

    // [57-59] RGB565 Output 및 Color Matrix
    rom[57] = 16'h1214; 
    rom[58] = 16'h40D0; 
    rom[59] = 16'h8C00; 

    // [60-66] 화질 보정 (노이즈 방지를 위해 보정치 하향 조정)
    rom[60] = 16'h4200; 
    rom[61] = 16'h13E7; 
    rom[62] = 16'hAA14; 
    rom[63] = 16'h5500; // Brightness
    rom[64] = 16'h1418; 
    rom[65] = 16'h3F04; // Edge 강도: 06->04로 하향 (노이즈 감소)
    rom[66] = 16'h5650; // Contrast: 70->50으로 하향 (자연스러운 대비)

    // [67-73] Saturation (업로드 파일의 mtx_rgb 참고)
    rom[67] = 16'h4FB3; // MTX1
    rom[68] = 16'h50B3; // MTX2
    rom[69] = 16'h5100; // MTX3
    rom[70] = 16'h523D; // MTX4
    rom[71] = 16'h53B0; // MTX5
    rom[72] = 16'h54E4; // MTX6
    rom[73] = 16'h589E; 

    // [74-76] Clock / Misc
    rom[74] = 16'h1101; 
    rom[75] = 16'h6B4A; 
    rom[76] = 16'h1E07; 

    // [77-79] 디지털 신호 처리 안정화
    rom[77] = 16'h4108; // COM16: Edge Enhancement On
    rom[78] = 16'h3D80; // COM13: UV 가변 채도 해제 (무지개 노이즈 억제)
    rom[79] = 16'h1500; // COM10: VSYNC/HREF 안정화
  end

  assign reg_addr = rom[addr][15:8];
  assign reg_data = rom[addr][7:0];

endmodule
*/

/*
`timescale 1ns / 1ps
`include "SCCB_Define.vh"

module SCCB_ROM (
    input  logic [6:0] addr,
    output logic [7:0] reg_addr,
    output logic [7:0] reg_data
);

  logic [15:0] rom[0:76];

  initial begin

// [0] Software Reset
rom[0]  = 16'h1280; // Reset

// [1] Basic Settings (기존 0번부터 시작)
rom[1]  = 16'h3A04;
rom[2]  = 16'h1200;
rom[3]  = 16'h13E7;
rom[4]  = 16'h6F9F;
rom[5]  = 16'hB084;
rom[6]  = 16'h703A;
rom[7]  = 16'h7135;
rom[8]  = 16'h7211;
rom[9]  = 16'h73F0;

// [10-25] Gamma Curve
rom[10] = 16'h7A20;
rom[11] = 16'h7B10;
rom[12] = 16'h7C1E;
rom[13] = 16'h7D35;
rom[14] = 16'h7E5A;
rom[15] = 16'h7F69;
rom[16] = 16'h8076;
rom[17] = 16'h8180;
rom[18] = 16'h8288;
rom[19] = 16'h838F;
rom[20] = 16'h8496;
rom[21] = 16'h85A3;
rom[22] = 16'h86AF;
rom[23] = 16'h87C4;
rom[24] = 16'h88D7;
rom[25] = 16'h89E8;

// [26-42] AGC / AEC
rom[26] = 16'h0000;
rom[27] = 16'h1000;
rom[28] = 16'h0D40;
rom[29] = 16'h1418;
rom[30] = 16'hA505;
rom[31] = 16'hAB07;
rom[32] = 16'h2495;
rom[33] = 16'h2533;
rom[34] = 16'h26E3;
rom[35] = 16'h9F78;
rom[36] = 16'hA068;
rom[37] = 16'hA103;
rom[38] = 16'hA6D8;
rom[39] = 16'hA7D8;
rom[40] = 16'hA8F0;
rom[41] = 16'hA990;
rom[42] = 16'hAA94;

// [43-50] QVGA
rom[43] = 16'h1211;
rom[44] = 16'h0C04;
rom[45] = 16'h3E19;
rom[46] = 16'h703A;
rom[47] = 16'h7135;
rom[48] = 16'h7211;
rom[49] = 16'h73F1;
rom[50] = 16'hA202;

// [51-56] Frame Control
rom[51] = 16'h1715;
rom[52] = 16'h1803;
rom[53] = 16'h3200;
rom[54] = 16'h1903;
rom[55] = 16'h1A7B;
rom[56] = 16'h0300;

// [57-59] RGB565
rom[57] = 16'h1214;
rom[58] = 16'h40D0;
rom[59] = 16'h8C00;

// [60-66] User
rom[60] = 16'h4200;
rom[61] = 16'h13E7;
rom[62] = 16'hAA14;
rom[63] = 16'h5587;
rom[64] = 16'h1418;
rom[65] = 16'h3F0A;
rom[66] = 16'h5650;

// [67-73] Saturation
rom[67] = 16'h4F8F;
rom[68] = 16'h508F;
rom[69] = 16'h5100;
rom[70] = 16'h5230;
rom[71] = 16'h538C;
rom[72] = 16'h54B6;
rom[73] = 16'h589E;

// [74-76] Clock / Misc
rom[74] = 16'h1101;
rom[75] = 16'h6B4A;
rom[76] = 16'h1E07;

  end

  assign reg_addr = rom[addr][15:8];
  assign reg_data = rom[addr][7:0];

endmodule
*/

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

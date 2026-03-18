// --- System & Reset ---
`define REG_GAIN 8'h00    // Gain lower 8 bits
`define REG_BLUE 8'h01    // Blue gain
`define REG_RED 8'h02    // Red gain
`define REG_VREF 8'h03    // Pieces of GAIN, VSTART, VSTOP
`define REG_COM1 8'h04    // Control 1
`define REG_BAVE 8'h05    // U/B Average level
`define REG_GbAVE 8'h06    // Y/Gb Average level
`define REG_AECHH 8'h07    // AEC MS 5 bits
`define REG_RAVE 8'h08    // V/R Average level
`define REG_COM2 8'h09    // Control 2
`define REG_PID 8'h0A    // Product ID MSB
`define REG_VER 8'h0B    // Product ID LSB
`define REG_COM3 8'h0C    // Control 3
`define REG_COM4 8'h0D    // Control 4
`define REG_COM5 8'h0E    // Reserved
`define REG_COM6 8'h0F    // Control 6
`define REG_AECH 8'h10    // More bits of AEC value
`define REG_CLKRC 8'h11    // Clock control
`define REG_COM7 8'h12    // Control 7 (Reset)
`define REG_COM8 8'h13    // Control 8
`define REG_COM9 8'h14    // Control 9 - gain ceiling
`define REG_COM10 8'h15    // Control 10

// --- Timing & Geometry ---
`define REG_HSTART 8'h17    // Horiz start high bits
`define REG_HSTOP 8'h18    // Horiz stop high bits
`define REG_VSTART 8'h19    // Vert start high bits
`define REG_VSTOP 8'h1A    // Vert stop high bits
`define REG_PSHFT 8'h1B    // Pixel delay after HREF
`define REG_MVFP 8'h1E    // Mirror / vflip
`define REG_HSYST 8'h30    // HSYNC rising edge delay
`define REG_HSYEN 8'h31    // HSYNC falling edge delay
`define REG_HREF 8'h32    // HREF pieces
`define REG_TSLB 8'h3A    // TSLB
`define REG_COM11 8'h3B    // Control 11
`define REG_COM12 8'h3C    // Control 12
`define REG_COM13 8'h3D    // Control 13
`define REG_COM14 8'h3E    // Control 14

// --- Image Processing & Color ---
`define REG_EDGE 8'h3F    // Edge enhancement factor
`define REG_COM15 8'h40    // Control 15
`define REG_COM16 8'h41    // Control 16
`define REG_COM17 8'h42    // Control 17
`define REG_DNSTH 8'h4C    // De-noise strength
`define REG_MTX1 8'h4F    // Matrix coefficient 1
`define REG_MTX2 8'h50    // Matrix coefficient 2
`define REG_MTX3 8'h51    // Matrix coefficient 3
`define REG_MTX4 8'h52    // Matrix coefficient 4
`define REG_MTX5 8'h53    // Matrix coefficient 5
`define REG_MTX6 8'h54    // Matrix coefficient 6
`define REG_BRIGHT 8'h55    // Brightness control
`define REG_CONTRAS 8'h56    // Contrast control
`define REG_CONTRAS_CENTER 8'h57    // Contrast control
`define REG_MTX_SIGN 8'h58    // Matrix coefficient sign
`define REG_RGB444 8'h8C    // RGB 444 control

// --- Gamma Curve ---
`define REG_GAM1 8'h7A
`define REG_GAM2 8'h7B
`define REG_GAM3 8'h7C
`define REG_GAM4 8'h7D
`define REG_GAM5 8'h7E
`define REG_GAM6 8'h7F
`define REG_GAM7 8'h80
`define REG_GAM8 8'h81
`define REG_GAM9 8'h82
`define REG_GAM10 8'h83
`define REG_GAM11 8'h84
`define REG_GAM12 8'h85
`define REG_GAM13 8'h86
`define REG_GAM14 8'h87
`define REG_GAM15 8'h88
`define REG_GAM16 8'h89

// --- AGC, AEC, AWB ---
`define REG_AEW 8'h24    // AGC upper limit
`define REG_AEB 8'h25    // AGC lower limit
`define REG_VPT 8'h26    // AGC/AEC fast mode op region
`define REG_AWBC1 8'h43    // AWB Control 1
`define REG_GFIX 8'h69    // Fix gain control
`define REG_GGAIN 8'h6A    // G channel AWB gain
`define REG_AWBCTR3 8'h6C    // AWB Control 3
`define REG_AWBCTR2 8'h6D    // AWB Control 2
`define REG_AWBCTR1 8'h6E    // AWB Control 1
`define REG_AWBCTR0 8'h6F    // AWB Control 0
`define REG_HAECC1 8'h9F    // Hist AEC/AGC control 1
`define REG_HAECC2 8'hA0    // Hist AEC/AGC control 2
`define REG_HAECC3 8'hA6    // Hist AEC/AGC control 3
`define REG_HAECC4 8'hA7    // Hist AEC/AGC control 4
`define REG_HAECC5 8'hA8    // Hist AEC/AGC control 5
`define REG_HAECC6 8'hA9    // Hist AEC/AGC control 6
`define REG_HAECC7 8'hAA    // Hist AEC/AGC control 7

// --- Scaling & Clock ---
`define REG_SCALING_XSC 8'h70    // Horizontal scale factor
`define REG_SCALING_YSC 8'h71    // Vertical scale factor
`define REG_SCALING_DCWCTR 8'h72    // DCW Control
`define REG_SCALING_PCLK_DIV 8'h73    // Clock divider control
`define REG_SCALING_PCLK_DELAY 8'hA2    // Pixel Clock delay
`define REG_DBLV 8'h6B    // PLL and regulator control

// --- Banding Filters ---
`define REG_BD50ST 8'h9D    // 50Hz banding filter value
`define REG_BD60ST 8'h9E    // 60Hz banding filter value
`define REG_BD50MAX 8'hA5    // 50hz banding step limit
`define REG_BD60MAX 8'hAB    // 60hz banding step limit

// --- Miscellaneous / Reserved ---
`define REG_RSVDA1 8'hA1    // Reserved/Custom
`define REG_RSVDB0 8'hB0    // Reserved/Custom

//============================================================================
//  ZX Spectrum Next 
//  port for MiSTer
//  Copyright (C) 2021 Alexey Melnikov
//
//  This program is free software; you can redistribute it and/or modify it
//  under the terms of the GNU General Public License as published by the Free
//  Software Foundation; either version 2 of the License, or (at your option)
//  any later version.
//
//  This program is distributed in the hope that it will be useful, but WITHOUT
//  ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
//  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
//  more details.
//
//  You should have received a copy of the GNU General Public License along
//  with this program; if not, write to the Free Software Foundation, Inc.,
//  51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
//
//============================================================================

module emu
(
	//Master input clock
	input         CLK_50M,

	//Async reset from top-level module.
	//Can be used as initial reset.
	input         RESET,

	//Must be passed to hps_io module
	inout  [45:0] HPS_BUS,

	//Base video clock. Usually equals to CLK_SYS.
	output        CLK_VIDEO,

	//Multiple resolutions are supported using different CE_PIXEL rates.
	//Must be based on CLK_VIDEO
	output        CE_PIXEL,

	//Video aspect ratio for HDMI. Most retro systems have ratio 4:3.
	//if VIDEO_ARX[12] or VIDEO_ARY[12] is set then [11:0] contains scaled size instead of aspect ratio.
	output [12:0] VIDEO_ARX,
	output [12:0] VIDEO_ARY,

	output  [7:0] VGA_R,
	output  [7:0] VGA_G,
	output  [7:0] VGA_B,
	output        VGA_HS,
	output        VGA_VS,
	output        VGA_DE,    // = ~(VBlank | HBlank)
	output        VGA_F1,
	output [1:0]  VGA_SL,
	output        VGA_SCALER, // Force VGA scaler

	input  [11:0] HDMI_WIDTH,
	input  [11:0] HDMI_HEIGHT,

`ifdef MISTER_FB
	// Use framebuffer in DDRAM (USE_FB=1 in qsf)
	// FB_FORMAT:
	//    [2:0] : 011=8bpp(palette) 100=16bpp 101=24bpp 110=32bpp
	//    [3]   : 0=16bits 565 1=16bits 1555
	//    [4]   : 0=RGB  1=BGR (for 16/24/32 modes)
	//
	// FB_STRIDE either 0 (rounded to 256 bytes) or multiple of pixel size (in bytes)
	output        FB_EN,
	output  [4:0] FB_FORMAT,
	output [11:0] FB_WIDTH,
	output [11:0] FB_HEIGHT,
	output [31:0] FB_BASE,
	output [13:0] FB_STRIDE,
	input         FB_VBL,
	input         FB_LL,
	output        FB_FORCE_BLANK,

`ifdef MISTER_FB_PALETTE
	// Palette control for 8bit modes.
	// Ignored for other video modes.
	output        FB_PAL_CLK,
	output  [7:0] FB_PAL_ADDR,
	output [23:0] FB_PAL_DOUT,
	input  [23:0] FB_PAL_DIN,
	output        FB_PAL_WR,
`endif
`endif

	output        LED_USER,  // 1 - ON, 0 - OFF.

	// b[1]: 0 - LED status is system status OR'd with b[0]
	//       1 - LED status is controled solely by b[0]
	// hint: supply 2'b00 to let the system control the LED.
	output  [1:0] LED_POWER,
	output  [1:0] LED_DISK,

	// I/O board button press simulation (active high)
	// b[1]: user button
	// b[0]: osd button
	output  [1:0] BUTTONS,

	input         CLK_AUDIO, // 24.576 MHz
	output [15:0] AUDIO_L,
	output [15:0] AUDIO_R,
	output        AUDIO_S,   // 1 - signed audio samples, 0 - unsigned
	output  [1:0] AUDIO_MIX, // 0 - no mix, 1 - 25%, 2 - 50%, 3 - 100% (mono)

	//ADC
	inout   [3:0] ADC_BUS,

	//SD-SPI
	output        SD_SCK,
	output        SD_MOSI,
	input         SD_MISO,
	output        SD_CS,
	input         SD_CD,

	//High latency DDR3 RAM interface
	//Use for non-critical time purposes
	output        DDRAM_CLK,
	input         DDRAM_BUSY,
	output  [7:0] DDRAM_BURSTCNT,
	output [28:0] DDRAM_ADDR,
	input  [63:0] DDRAM_DOUT,
	input         DDRAM_DOUT_READY,
	output        DDRAM_RD,
	output [63:0] DDRAM_DIN,
	output  [7:0] DDRAM_BE,
	output        DDRAM_WE,

	//SDRAM interface with lower latency
	output        SDRAM_CLK,
	output        SDRAM_CKE,
	output [12:0] SDRAM_A,
	output  [1:0] SDRAM_BA,
	inout  [15:0] SDRAM_DQ,
	output        SDRAM_DQML,
	output        SDRAM_DQMH,
	output        SDRAM_nCS,
	output        SDRAM_nCAS,
	output        SDRAM_nRAS,
	output        SDRAM_nWE,

`ifdef MISTER_DUAL_SDRAM
	//Secondary SDRAM
	//Set all output SDRAM_* signals to Z ASAP if SDRAM2_EN is 0
	input         SDRAM2_EN,
	output        SDRAM2_CLK,
	output [12:0] SDRAM2_A,
	output  [1:0] SDRAM2_BA,
	inout  [15:0] SDRAM2_DQ,
	output        SDRAM2_nCS,
	output        SDRAM2_nCAS,
	output        SDRAM2_nRAS,
	output        SDRAM2_nWE,
`endif

	input         UART_CTS,
	output        UART_RTS,
	input         UART_RXD,
	output        UART_TXD,
	output        UART_DTR,
	input         UART_DSR,

	// Open-drain User port.
	// 0 - D+/RX
	// 1 - D-/TX
	// 2..6 - USR2..USR6
	// Set USER_OUT to 1 to read from USER_IN.
	input   [6:0] USER_IN,
	output  [6:0] USER_OUT,

	input         OSD_STATUS
);

assign USER_OUT = '1;
assign {DDRAM_CLK, DDRAM_BURSTCNT, DDRAM_ADDR, DDRAM_DIN, DDRAM_BE, DDRAM_RD, DDRAM_WE} = '0;  

assign AUDIO_S = 0;  // 1 - signed audio samples, 0 - unsigned
assign AUDIO_MIX = status[4:3];

assign LED_DISK = 0;
assign LED_POWER = 0;
assign LED_USER = sd_act & ~vsd_sel;
assign BUTTONS = 0;

assign UART_RTS = 0;
assign UART_DTR = 0;

assign VGA_SCALER = 0;
assign VGA_F1 = 0;

// Status Bit Map:
//              Upper                          Lower
// 0         1         2         3          4         5         6
// 01234567890123456789012345678901 23456789012345678901234567890123
// 0123456789ABCDEFGHIJKLMNOPQRSTUV 0123456789ABCDEFGHIJKLMNOPQRSTUV
// XXXXXXXXXX                XXXX


`include "build_id.v" 
localparam CONF_STR = {
	"ZXNext;;",
	"S0,VHD;",
	"O1,Hard Reset after mount,No,Yes;",
   "-;",
	"O78,Aspect Ratio,Original,Full Screen,[ARC1],[ARC2];",
	"O56,Scandoubler Fx,None,HQ2x,CRT 25%,CRT 50%;",
	"H2d1OS,Vertical Crop,No,Yes;",
	"h2d1OST,Vertical Crop,No,270,216;",
	"OQR,Scale,Normal,V-Integer,Narrower HV-Integer,Wider HV-Integer;",
	"-;",
	"O34,Stereo Mix,none,25%,50%,100%;",
	"-;",
	"O2,Joysticks Swap,No,Yes;",
	"-;",
	"h3-,Current CPU Clock:   3.5MHz;",
	"h4-,Current CPU clock:     7MHz;",
	"h5-,Current CPU clock:    14MHz;",
	"h6-,Current CPU clock:    28MHz;",
	"R0,Soft Reset;",
	"R9,Hard Reset;",
	"J,A,B,C,X,Y,Z,Start;",
 	"V,v",`BUILD_DATE
};

wire clk_sys, CLK_14, CLK_7, CLK_56, CLK_112;
wire pll_locked;

pll pll
(
	.refclk(CLK_50M),
	.outclk_0(clk_sys),
	.outclk_1(CLK_56),
	.outclk_2(CLK_14),
	.outclk_3(CLK_7),
	.outclk_4(CLK_112),
	.locked(pll_locked)
);

reg reset = 0;
always @(posedge clk_sys) reset <= RESET | status[0] | buttons[1];

wire        forced_scandoubler;
wire  [1:0] buttons;
wire [63:0] status;
wire [10:0] ps2_key;
wire [24:0] ps2_mouse;
wire  [7:0] ps2_mouse_ext;
wire [15:0] joy_0, joy_1;

wire [31:0] sd_lba;
wire        sd_rd;
wire        sd_wr;
wire        sd_ack;
wire  [7:0] sd_buff_addr;
wire [15:0] sd_buff_dout;
wire [15:0] sd_buff_din;
wire        sd_buff_wr;
wire        img_mounted;
wire [63:0] img_size;

wire [21:0] gamma_bus;

hps_io #(.STRLEN($size(CONF_STR)>>3), .WIDE(1)) hps_io
(
	.clk_sys(clk_sys),
	.HPS_BUS(HPS_BUS),

	.conf_str(CONF_STR),
	.forced_scandoubler(forced_scandoubler),

	.joystick_0(joy_0),
	.joystick_1(joy_1),

	.buttons(buttons),
	.status(status),
	.status_menumask({cpu_speed==3,cpu_speed==2,cpu_speed==1,cpu_speed==0,en1080p,|vcrop,1'b0}),

	.sd_lba(sd_lba),
	.sd_rd(sd_rd),
	.sd_wr(sd_wr),
	.sd_ack(sd_ack),
	.sd_buff_addr(sd_buff_addr),
	.sd_buff_dout(sd_buff_dout),
	.sd_buff_din(sd_buff_din),
	.sd_buff_wr(sd_buff_wr),
	.img_mounted(img_mounted),
	.img_size(img_size),

	.ps2_key(ps2_key),
	.ps2_mouse(ps2_mouse),
	.ps2_mouse_ext(ps2_mouse_ext),

	.gamma_bus(gamma_bus)
);

wire [20:0] RAM_A_ADDR;
wire        RAM_A_REQ;
wire        RAM_A_RD_n;
wire  [7:0] RAM_A_DI;
wire  [7:0] RAM_A_DO;
wire        RAM_A_WAIT;
wire [20:0] RAM_B_ADDR;
wire        RAM_B_REQ;
wire  [7:0] RAM_B_DO;

sdram sdram(.*, .clk(CLK_112), .init(~pll_locked));

wire [11:0] aud_l, aud_r;
wire  [1:0] cpu_speed;

// active high =  X Z Y START A C B U D L R
wire [10:0] j0 = {joy_0[7],joy_0[9],joy_0[8],joy_0[10],joy_0[4],joy_0[6],joy_0[5],joy_0[3:0]};
wire [10:0] j1 = {joy_1[7],joy_1[9],joy_1[8],joy_1[10],joy_1[4],joy_1[6],joy_1[5],joy_1[3:0]};

zxnext_top zxnext_top
(
	.CLK_28        (clk_sys),
	.CLK_14        (CLK_14),
	.CLK_7         (CLK_7),

	.SW_RESET      (reset),
	.HW_RESET      (status[9] || (status[1] && img_mounted)),

	.CPU_SPEED     (cpu_speed),
	
	.RAM_A_ADDR    (RAM_A_ADDR),
	.RAM_A_REQ     (RAM_A_REQ),
	.RAM_A_RD_n    (RAM_A_RD_n),
	.RAM_A_DO      (RAM_A_DI),
	.RAM_A_DI      (RAM_A_DO),
	.RAM_A_WAIT    (RAM_A_WAIT),
	.RAM_B_ADDR    (RAM_B_ADDR),
	.RAM_B_REQ     (RAM_B_REQ),
	.RAM_B_DI      (RAM_B_DO),

	.ps2_key       (ps2_key),
	.ps2_mouse     (ps2_mouse),
	.ps2_mouse_ext (ps2_mouse_ext),

	.sd_cs0_n_o    (sdss),
	.sd_sclk_o     (sdclk),
	.sd_mosi_o     (sdmosi),
	.sd_miso_i     (sdmiso),
	.sd_octal_i    (sdoctal),

	.audio_L       (aud_l),
	.audio_R       (aud_r),

	.ear_port_i    (~tape_in),

	.joy_left      (status[2] ? j1: j0),
	.joy_right     (status[2] ? j0: j1),

	.uart_rx_i     (UART_RXD),
	.uart_tx_o     (UART_TXD),

	.RGB           ({rgb_r,rgb_g,rgb_b}),
	.RGB_VS_n      (VSync_n),
	.RGB_HS_n      (HSync_n),
	.RGB_VB_n      (VBlank_n),
	.RGB_HB_n      (HBlank_n),
	.RGB_NTSC      (ntsc)
);

assign AUDIO_L = {aud_l, 4'b0000};
assign AUDIO_R = {aud_r, 4'b0000};

assign CLK_VIDEO = CLK_56;

wire [2:0] scale  = status[6:5];
assign     VGA_SL = scale ? scale[1:0] - 1'd1 : 2'd0;

wire HBlank_n, VBlank_n;
wire HSync_n, VSync_n;
wire ntsc;

wire [2:0] rgb_r;
wire [2:0] rgb_g;
wire [2:0] rgb_b;

reg ce_pix;
always @(posedge CLK_VIDEO) begin
	reg [1:0] div;

	div <= div + 1'd1;
	ce_pix <= !div;
end

reg narrow_hbl;
always @(posedge CLK_VIDEO) begin
	reg [10:0] hcnt;

	if(ce_pix) begin
		hcnt <= hcnt + 1'd1;
		if(~HBlank_n) hcnt <= 0;
		narrow_hbl <= narrow && ((hcnt < 20) || (hcnt >= 700));
	end
end

video_mixer #(.LINE_LENGTH(740), .GAMMA(1)) video_mixer
(
	.*,
	
	.hq2x(scale == 1),
	.scandoubler(scale || forced_scandoubler),
	
	.VSync(~VSync_n),
	.HSync(~HSync_n),
	.VBlank(~VBlank_n),
	.HBlank(~HBlank_n | narrow_hbl),
	
	.R({rgb_r,rgb_r,rgb_r[2:1]}),
	.G({rgb_g,rgb_g,rgb_g[2:1]}),
	.B({rgb_b,rgb_b,rgb_b[2:1]}),
	
	.VGA_DE(vga_de)
);

reg [9:0] vcrop;
reg       narrow;
always @(posedge CLK_VIDEO) begin
	vcrop <= 0;
	narrow <= 0;
	if(HDMI_WIDTH >= (HDMI_HEIGHT + HDMI_HEIGHT[11:1]) && !forced_scandoubler && !scale) begin
		if(HDMI_HEIGHT == 480)  vcrop <= 240;
		if(HDMI_HEIGHT == 600)  begin vcrop <= 200; narrow <= 1; end
		if(HDMI_HEIGHT == 720)  vcrop <= 240;
		if(HDMI_HEIGHT == 768)  vcrop <= 256;
		if(HDMI_HEIGHT == 800)  begin vcrop <= 200; narrow <= 1; end
		if(HDMI_HEIGHT == 1080) vcrop <= status[29] ? 10'd216 : 10'd270;
		if(HDMI_HEIGHT == 1200) vcrop <= 240;
	end
end

reg en1080p;
always @(posedge CLK_VIDEO) en1080p <= (HDMI_WIDTH == 1920) && (HDMI_HEIGHT == 1080);

wire [1:0] ar = status[8:7];
wire vcrop_en = en1080p ? |status[29:28] : status[28];
wire vga_de;
video_freak video_freak
(
	.*,
	.VGA_DE_IN(vga_de),
	.ARX((!ar) ? (narrow ? 12'd340 : 12'd360) : (ar - 1'd1)),
	.ARY((!ar) ? (ntsc ? 12'd256 : 12'd303) : 12'd0),
	.CROP_SIZE(vcrop_en ? vcrop : 10'd0),
	.CROP_OFF(0),
	.SCALE(status[27:26])
);


localparam VSD_OCTAL = 0;

wire       sdclk;
wire       sdoctal = vsd_sel && VSD_OCTAL;
wire [7:0] sdmosi;
wire [7:0] sdmiso = vsd_sel ? vsdmiso : {7'b1111111, SD_MISO};
wire       sdss;

reg vsd_sel = 0;
always @(posedge clk_sys) begin
	if(img_mounted) vsd_sel <= |img_size;
	if(RESET) vsd_sel <= 0;
end

wire [7:0] vsdmiso;
sd_card #(.WIDE(1), .OCTAL(VSD_OCTAL)) sd_card
(
	.*,
	.clk_spi(clk_sys),
	.sdhc(1),
	.sck(sdclk),
	.ss(sdss | ~vsd_sel),
	.mosi(sdmosi),
	.miso(vsdmiso)
);

assign SD_CS   = sdss      |  vsd_sel;
assign SD_SCK  = sdclk     & ~vsd_sel;
assign SD_MOSI = sdmosi[0] & ~vsd_sel;

reg sd_act;
always @(posedge clk_sys) begin
	reg old_clk;
	integer timeout = 0;

	old_clk <= sdclk;

	sd_act <= 0;
	if(timeout < 1000000) begin
		timeout <= timeout + 1;
		sd_act <= 1;
	end

	if(sdss & (old_clk ^ sdclk)) timeout <= 0;
end

wire tape_in;
wire tape_adc, tape_adc_act;

assign tape_in = tape_adc_act & tape_adc;

ltc2308_tape #(.CLK_RATE(28000000)) ltc2308_tape
(
  .clk(clk_sys),
  .ADC_BUS(ADC_BUS),
  .dout(tape_adc),
  .active(tape_adc_act)
);

endmodule

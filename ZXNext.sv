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
	inout  [48:0] HPS_BUS,

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
	output        VGA_DISABLE, // analog out is off

	input  [11:0] HDMI_WIDTH,
	input  [11:0] HDMI_HEIGHT,
	output        HDMI_FREEZE,
	output        HDMI_BLACKOUT,
	
`ifdef MISTER_FB
	// Use framebuffer in DDRAM
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

assign AUDIO_S = 0;  // 1 - signed audio samples, 0 - unsigned
assign AUDIO_MIX = status[4:3];

assign LED_DISK = 0;
assign LED_POWER = 0;
assign LED_USER = sd_act | tape_led;
assign BUTTONS = 0;

assign UART_RTS = 0;
assign UART_DTR = 0;

assign VGA_SCALER = 0;
assign VGA_DISABLE = 0;
assign VGA_F1 = 0;
assign HDMI_FREEZE = 0;
assign HDMI_BLACKOUT = 0;

// Status Bit Map:
//              Upper                          Lower
// 0         1         2         3          4         5         6
// 01234567890123456789012345678901 23456789012345678901234567890123
// 0123456789ABCDEFGHIJKLMNOPQRSTUV 0123456789ABCDEFGHIJKLMNOPQRSTUV
// XXXXXXXXXXXXX              XXXX


`include "build_id.v" 
localparam CONF_STR = {
	"ZXNext;;",
	"SC0,VHD,Mount C:;",
	"SC1,VHD,Mount D:;",
	"O1,Hard Reset on C: mount,No,Yes;",
   "-;",
	"F1,TZXCSW,Load Tape,30000000;",
   "-;",
	"O78,Aspect Ratio,Original,Full Screen,[ARC1],[ARC2];",
	"O56,Scandoubler Fx,None,HQ2x,CRT 25%,CRT 50%;",
	"H2d1OS,Vertical Crop,No,Yes;",
	"h2d1OST,Vertical Crop,No,270,216;",
	"OQR,Scale,Normal,V-Integer,Narrower HV-Integer,Wider HV-Integer;",
	"O34,Stereo Mix,none,25%,50%,100%;",
	"O2,Joysticks Swap,No,Yes;",
	"-;",
	"h3TA,CPU Clock:           3.5MHz;",
	"h4TA,CPU Clock:             7MHz;",
	"h5TA,CPU Clock:            14MHz;",
	"h6TA,CPU Clock:            28MHz;",
	"R0,Soft Reset;",
	"R9,Hard Reset;",
	
	"h7-;",
	"h7P3,Debug;",
	"h7P3-;",
	"h7P3O[11],Machine,Mister,Next;",
	"h7P3O[12],Issue,2,4;",
	"-   ;",
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
always @(posedge clk_sys) reset <= RESET | status[0] | buttons[1] | hw_reset;

wire        forced_scandoubler;
wire  [1:0] buttons;
wire [63:0] status;
wire [10:0] ps2_key;
wire [24:0] ps2_mouse;
wire  [7:0] ps2_mouse_ext;
wire [15:0] joy_0, joy_1;

wire [31:0] sd_lba[2];
wire  [1:0] sd_rd;
wire  [1:0] sd_wr;
wire  [1:0] sd_ack;
wire  [7:0] sd_buff_addr;
wire [15:0] sd_buff_dout;
wire [15:0] sd_buff_din[2];
wire        sd_buff_wr;
wire  [1:0] img_mounted;
wire [63:0] img_size;

wire [21:0] gamma_bus;

wire [64:0] RTC;

wire        ioctl_wr;
wire [24:0] ioctl_addr;
wire [15:0] ioctl_dout;
wire        ioctl_download;
wire  [7:0] ioctl_index;
wire        ioctl_wait;

reg dbg_enabled = 0;


hps_io #(.CONF_STR(CONF_STR), .VDNUM(2), .WIDE(1)) hps_io
(
	.clk_sys(clk_sys),
	.HPS_BUS(HPS_BUS),

	.forced_scandoubler(forced_scandoubler),

	.joystick_0(joy_0),
	.joystick_1(joy_1),

	.buttons(buttons),
	.status(status),
	.status_menumask({dbg_enabled,cpu_speed==3,cpu_speed==2,cpu_speed==1,cpu_speed==0,en1080p,|vcrop,1'b0}),

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

	.ioctl_wr(ioctl_wr),
	.ioctl_addr(ioctl_addr),
	.ioctl_dout(ioctl_dout),
	.ioctl_download(ioctl_download),
	.ioctl_index(ioctl_index),
	.ioctl_wait(ioctl_wait),

	.ps2_key(ps2_key),
	.ps2_mouse(ps2_mouse),
	.ps2_mouse_ext(ps2_mouse_ext),

	.RTC(RTC),

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
	.g_machine_id(g_machine_id),
	.g_board_issue(g_board_issue),
	
	.CLK_28        (clk_sys),
	.CLK_14        (CLK_14),
	.CLK_7         (CLK_7),

	.SW_RESET      (reset),
	.HW_RESET      (hw_reset),

	.CPU_SPEED_SW  (status[10]),
	.CPU_SPEED     (cpu_speed),
	.CPU_WAIT      (RAM_A_WAIT || sd_wait),

	.RAM_A_ADDR    (RAM_A_ADDR),
	.RAM_A_REQ     (RAM_A_REQ),
	.RAM_A_RD_n    (RAM_A_RD_n),
	.RAM_A_DO      (RAM_A_DI),
	.RAM_A_DI      (RAM_A_DO),
	.RAM_B_ADDR    (RAM_B_ADDR),
	.RAM_B_REQ     (RAM_B_REQ),
	.RAM_B_DI      (RAM_B_DO),

	.ps2_key       (ps2_key),
	.ps2_mouse     (ps2_mouse),
	.ps2_mouse_ext (ps2_mouse_ext),

	.sd_cs0_n_o    (sdss0),
	.sd_cs1_n_o    (sdss1),
	.sd_sclk_o     (sdclk),
	.sd_mosi_o     (sdmosi),
	.sd_miso_i     (sdmiso),

	.audio_L       (aud_l),
	.audio_R       (aud_r),

	.ear_port_i    (~tape_in),

	.joy_left      (status[2] ? j1: j0),
	.joy_right     (status[2] ? j0: j1),

	.uart_rx_i     (UART_RXD),
	.uart_tx_o     (UART_TXD),

	.i2c_scl_o     (i2c_scl_o),
	.i2c_sda_o     (i2c_sda_o),
	.i2c_sda_i     (i2c_sda_i),

	.RGB           ({rgb_r,rgb_g,rgb_b}),
	.RGB_VS_n      (VSync_n),
	.RGB_HS_n      (HSync_n),
	.RGB_VB_n      (VBlank_n),
	.RGB_HB_n      (HBlank_n),
	.RGB_NTSC      (ntsc)
);

reg hw_reset = 0;
always @(posedge clk_sys) begin
	reg [15:0] cnt = 0;
	
	if(cnt) cnt <= cnt - 1'd1;
	if(status[9] || (status[1] && img_mounted[0])) cnt <= '1;
	
	hw_reset <= |cnt;
end

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
	.freeze_sync(),
	
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


wire sdclk;
wire sdmosi;
wire sdmiso = ~sdss1 ? vsdmiso1 : vsd_sel0 ? vsdmiso0 : SD_MISO;

reg vsd_sel0 = 0;
always @(posedge clk_sys) begin
	if(img_mounted[0]) vsd_sel0 <= |img_size;
	if(RESET) vsd_sel0 <= 0;
end

wire        sdss0;
wire        vsdmiso0;

sd_card #(.WIDE(1)) sd_card_0
(
	.*,

	.img_mounted(img_mounted[0]),

	.sd_lba(sd_lba[0]),
	.sd_rd(sd_rd[0]),
	.sd_wr(sd_wr[0]),
	.sd_ack(sd_ack[0]),
	.sd_buff_din(sd_buff_din[0]),

	.clk_spi(clk_sys),
	.sdhc(1),
	.sck(sdclk),
	.ss(sdss0 | ~vsd_sel0),
	.mosi(sdmosi),
	.miso(vsdmiso0)
);

reg vsd_sel1 = 0;
always @(posedge clk_sys) begin
	if(img_mounted[1]) vsd_sel1 <= |img_size;
	if(RESET) vsd_sel1 <= 0;
end

wire        sdss1;
wire        vsdmiso1;

sd_card #(.WIDE(1)) sd_card_1
(
	.*,

	.img_mounted(img_mounted[1]),

	.sd_lba(sd_lba[1]),
	.sd_rd(sd_rd[1]),
	.sd_wr(sd_wr[1]),
	.sd_ack(sd_ack[1]),
	.sd_buff_din(sd_buff_din[1]),

	.clk_spi(clk_sys),
	.sdhc(1),
	.sck(sdclk),
	.ss(sdss1 | ~vsd_sel1),
	.mosi(sdmosi),
	.miso(vsdmiso1)
);

reg [1:0] sd_wait;
always @(posedge clk_sys) sd_wait <= (sd_wait & sd_ack) | sd_wr;

assign SD_CS   = sdss0  |  vsd_sel0;
assign SD_SCK  = sdclk  & ~vsd_sel0;
assign SD_MOSI = sdmosi |  vsd_sel0;

reg sd_act;
always @(posedge clk_sys) begin
	reg old_clk;
	integer timeout = 0;

	old_clk <= SD_SCK;

	sd_act <= 0;
	if(timeout < 1000000) begin
		timeout <= timeout + 1;
		sd_act <= 1;
	end

	if(~SD_CS & (old_clk ^ SD_SCK)) timeout <= 0;
end

wire i2c_scl_o;
wire i2c_sda_o;
wire i2c_sda_i;

rtc #(28000000) rtc
(
	.clk(clk_sys),
	.reset(reset),
	.RTC(RTC),
	.scl_i(i2c_scl_o),
	.sda_i(i2c_sda_o),
	.sda_o(i2c_sda_i)
);


wire tape_in;
wire tape_adc, tape_adc_act;

assign tape_in = tape_adc_act ? tape_adc : audio_out;

ltc2308_tape #(.CLK_RATE(28000000)) ltc2308_tape
(
  .clk(clk_sys),
  .ADC_BUS(ADC_BUS),
  .dout(tape_adc),
  .active(tape_adc_act)
);

/////////////////////////////////////////////////////////////////////

assign DDRAM_CLK = CLK_112;
wire clk_tape = CLK_112;

reg tape_ce;
always @(posedge clk_tape) begin
	reg [4:0] div;
	reg [1:0] speed;
	
	div <= div + 1'd1;
	if(&div) speed <= cpu_speed;
	case(speed)
		0: tape_ce <= !div[4:0];
		1: tape_ce <= !div[3:0];
		2: tape_ce <= !div[2:0] & ~RAM_A_WAIT;
		3: tape_ce <= !div[1:0] & ~RAM_A_WAIT;
	endcase
end

ddram ddram
(
	.*,

	.reset(tape_restart),

	.wraddr(ioctl_addr[24:1]),
	.din(ioctl_dout),
	.we_req(ddram_we_req),
	.we_ack(ddram_we_ack),

	.rdaddr(tape_addr),
	.dout(tape_data),
	.rom_req(tape_req),
	.rom_ack(tape_ack)
);

reg  ddram_we_req;
wire ddram_we_ack;
always @(posedge clk_sys) if(ioctl_wr) ddram_we_req <= ~ddram_we_req;

assign ioctl_wait = ddram_we_req ^ ddram_we_ack;
wire   tape_download = ioctl_download && (ioctl_index[4:0] == 1);

wire tzx_stop, tzx_stop48k, tzx_loop_start, tzx_loop_next, tzx_audio, tzx_req;

tzxplayer #(.TZX_MS(3500)) tzxplayer
(
	.clk(clk_tape),
	.ce(tape_ce),
	.tzx_req(tzx_req),
	.tzx_ack(tape_ack),
	.loop_start(tzx_loop_start),
	.loop_next(tzx_loop_next),
	.stop(tzx_stop),
	.stop48k(tzx_stop48k),
	.restart_tape(~tape_ready | tape_restart),
	.host_tap_in(tape_data),
	.cass_read(tzx_audio),
	.cass_motor(!play_pause)
);

wire [7:0] tape_data;
reg        tape_req;
wire       tape_ack;

reg        key_restart, tape_restart, play_pause;
reg        audio_out;
reg [24:0] tape_addr;
reg        tape_ready;
always @(posedge clk_tape) begin
	reg        old_download;
	reg [24:0] tape_len, tzx_loop_addr;
	reg        key_stb1, key_stb2;
	reg [24:0] addr;
	
	tape_restart <= tape_download;

	key_stb1 <= ps2_key[10];
	key_stb2 <= key_stb1;
	if(key_stb1 ^ key_stb2) begin
		if(ps2_key[8:0] == 'h03 && ps2_key[9]) play_pause   <= ~play_pause; // F5
		if(ps2_key[8:0] == 'h0B)               tape_restart <= 1;           // F6
		if(ps2_key[8:0] == 'h83)               tape_ready   <= 0;           // F7
	end

	if(reset) tape_ready <= 0;
	if(!tape_ready) play_pause <= 1;

	tape_req <= tzx_req;
	if(tape_restart) begin
		addr <= 0;
		tape_addr  <= 0;
		play_pause <= 1;
	end
	else if(tape_req ^ tzx_req) begin
		tape_addr <= addr;
		addr <= addr + 1'd1;
		if(addr >= tape_len) tape_ready <= 0;
	end
	
	audio_out <= tzx_audio;
	if(tzx_stop | tzx_stop48k) play_pause <= 1;
	if(tzx_loop_start) tzx_loop_addr <= addr;
	if(tzx_loop_next) begin
		addr      <= tzx_loop_addr + 1'd1;
		tape_addr <= tzx_loop_addr;
	end
	
	old_download <= tape_download;
	if(old_download & ~tape_download) begin
		tape_len <= ioctl_addr;
		tape_ready <= 1;
		play_pause <= 0;
	end
end

wire tape_led = act_cnt[22] ? act_cnt[21:14] > act_cnt[7:0] : act_cnt[21:14] <= act_cnt[7:0];

reg [22:0] act_cnt;
always @(posedge clk_sys) if(~play_pause || ~(tape_ready ^ act_cnt[22]) || act_cnt[21:0]) act_cnt <= act_cnt + 1'd1;

reg [7:0] g_machine_id =8'h0A;
reg [3:0] g_board_issue =4'h0;
	
always @(posedge clk_sys) begin
 if (joy_0[10] && joy_0[10]) dbg_enabled <= 1;  // menu + Start + y for debug menu
	
	if(status[11]) 
		g_machine_id= 8'h0A;
	else 
		g_machine_id =8'hDA;

	if(status[12])
		g_board_issue =4'h2;
	else 
		g_board_issue =4'h0;  
end

endmodule

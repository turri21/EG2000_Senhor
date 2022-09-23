`timescale 1ps / 1ps
/*============================================================================
	Aznable (custom 8-bit computer system) - Verilator emu module

	Author: Jim Gregory - https://github.com/JimmyStones/
	Version: 1.1
	Date: 2021-10-17

	This program is free software; you can redistribute it and/or modify it
	under the terms of the GNU General Public License as published by the Free
	Software Foundation; either version 3 of the License, or (at your option)
	any later version.

	This program is distributed in the hope that it will be useful,
	but WITHOUT ANY WARRANTY; without even the implied warranty of
	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
	GNU General Public License for more details.

	You should have received a copy of the GNU General Public License along
	with this program. If not, see <http://www.gnu.org/licenses/>.
===========================================================================*/

module emu (

	input clk_sys,
	input reset,
	input soft_reset,
	input menu,
	
	input [31:0] joystick_0,
	input [31:0] joystick_1,
	input [31:0] joystick_2,
	input [31:0] joystick_3,
	input [31:0] joystick_4,
	input [31:0] joystick_5,
	
	input [15:0] joystick_l_analog_0,
	input [15:0] joystick_l_analog_1,
	input [15:0] joystick_l_analog_2,
	input [15:0] joystick_l_analog_3,
	input [15:0] joystick_l_analog_4,
	input [15:0] joystick_l_analog_5,
	
	input [15:0] joystick_r_analog_0,
	input [15:0] joystick_r_analog_1,
	input [15:0] joystick_r_analog_2,
	input [15:0] joystick_r_analog_3,
	input [15:0] joystick_r_analog_4,
	input [15:0] joystick_r_analog_5,

	input [7:0] paddle_0,
	input [7:0] paddle_1,
	input [7:0] paddle_2,
	input [7:0] paddle_3,
	input [7:0] paddle_4,
	input [7:0] paddle_5,

	input [8:0] spinner_0,
	input [8:0] spinner_1,
	input [8:0] spinner_2,
	input [8:0] spinner_3,
	input [8:0] spinner_4,
	input [8:0] spinner_5,

	// ps2 alternative interface.
	// [8] - extended, [9] - pressed, [10] - toggles with every press/release
	input [10:0] ps2_key,

	// [24] - toggles with every event
	input [24:0] ps2_mouse,
	input [15:0] ps2_mouse_ext, // 15:8 - reserved(additional buttons), 7:0 - wheel movements

	// [31:0] - seconds since 1970-01-01 00:00:00, [32] - toggle with every change
	input [32:0] timestamp,

	output [7:0] VGA_R,
	output [7:0] VGA_G,
	output [7:0] VGA_B,
	
	output VGA_HS,
	output VGA_VS,
	output VGA_HB,
	output VGA_VB,

	output CE_PIXEL,
	
	output	[15:0]	AUDIO_L,
	output	[15:0]	AUDIO_R,
	
	input			ioctl_download,
	input			ioctl_wr,
	input [24:0]		ioctl_addr,
	input [7:0]		ioctl_dout,
	input [7:0]		ioctl_index,
	output reg		ioctl_wait=1'b0,

	output [31:0] 		sd_lba[2],
	output [9:0] 		sd_rd,
	output [9:0] 		sd_wr,
	input [9:0] 		sd_ack,
	input [8:0] 		sd_buff_addr,
	input [7:0] 		sd_buff_dout,
	output [7:0] 		sd_buff_din[2],
	input 			sd_buff_wr,
	input [9:0] 		img_mounted,
	input 			img_readonly,

	input [63:0] 		img_size,

	input                   tape_play


);
wire [15:0] joystick_a0 =  joystick_l_analog_0;

wire UART_CTS;
wire UART_RTS;
wire UART_RXD;
wire UART_TXD;
wire UART_DTR;
wire UART_DSR;

wire CLK_VIDEO = clk_sys;

wire  [7:0] pdl  = {~paddle_0[7], paddle_0[6:0]};
wire [15:0] joys = joystick_a0;
wire [15:0] joya = {joys[15:8], joys[7:0]};
wire  [5:0] joyd = joystick_0[5:0] & {2'b11, {2{~|joys[7:0]}}, {2{~|joys[15:8]}}};



/*
localparam CONF_STR = {
	"eg2000;;",
	"-;",
	"F1,CAS,Load Cassette;",
	"-;",
	"O1,Play,Off,On;",
	"-;",
	"O89,Aspect ratio,Original,Full Screen,[ARC1],[ARC2];",
    "OAC,Scandoubler Fx,None,CRT 25%,CRT 50%,CRT 75%,HQ2x;",
	"OFG,Scale,Normal,V-Integer,Narrower HV-Integer,Wider HV-Integer;",
    "-;",
	"T0,Reset;",
	"R0,Reset and close OSD;",
	"V,v",`BUILD_DATE 
};
*/

//////////////////////////////////////////////////////////////////


wire HBlank;
wire HSync;
wire VBlank;
wire VSync;
wire ce_pix;
wire led;
wire pixel;

reg[5:0] rs;
wire power = rs[5] &  ~reset;
always @(posedge clk_sys) if(!power) rs <= rs+1'd1;

wire[3:0] color;

// signals from loader
wire loader_wr;		
wire loader_download;
wire [15:0] loader_addr;
wire [7:0] loader_data;
wire [15:0] execute_addr;
wire execute_enable;
wire loader_wait;



eg2000 eg2000
(
	.clock  (clk_sys),
	//.reset	(reset),
	.power  (power  ),
	.hsync  (VGA_HS),
	.vsync  (VGA_VS),
	.hblank  (VGA_HB),
	.vblank  (VGA_VB),

	.ce_pix (ce_pix ),
	.pixel  (pixel  ),
	.color  (color  ),
	.crtcDe (crtcDe_tmp),
	.tape   (~tape_in),
	.audio_l(AUDIO_L),
	.audio_r(AUDIO_R),
	.led    (led    ),
	.ps2_key    (ps2_key    ),

	.tape_play(tape_play),
    .dn_clk	(clk_sys),
    .dn_go (ioctl_download),
    .dn_wr (ioctl_wr),
    .dn_addr (ioctl_addr),
    .dn_data (ioctl_dout)
    
);


reg[17:0] palette[15:0];
initial begin
	palette[15] = 18'b111111_111111_111111; // FF FF FF // 16 // white
	palette[14] = 18'b100110_001000_111111; // 98 20 FF //  8 // magenta
	palette[13] = 18'b000111_110001_100011; // 1F C4 8C // 14 // turquise
	palette[12] = 18'b100011_100011_100011; // 8C 8C 8C // 13 // grey
	palette[11] = 18'b100010_011001_111111; // 8A 67 FF // 12 // violet
	palette[10] = 18'b110001_010011_111111; // C7 4E FF // 15 // pink
	palette[ 9] = 18'b101111_110111_111111; // BC DF FF //  9 // light blue
	palette[ 8] = 18'b001011_010100_111111; // 2F 53 FF //  8 // blue
	palette[ 7] = 18'b111010_111111_001001; // EA FF 27 // 11 // yellow/green
	palette[ 6] = 18'b111010_011011_001010; // EB 6F 2B //  5 // orange
	palette[ 5] = 18'b101010_111111_010010; // AB FF 4A //  2 // green
	palette[ 4] = 18'b111111_111100_001111; // FF F2 3D //  4 // yellow
	palette[ 3] = 18'b111010_111010_111010; // EA EA EA //  1 // light grey
	palette[ 2] = 18'b110010_001001_010111; // CB 26 5E //  3 // red
	palette[ 1] = 18'b011011_111111_111010; // 7C FF EA //  7 // cyan
	palette[ 0] = 18'b010111_010111_010111; // 5E 5E 5E // 10 // dark grey
end

wire[17:0] rgbQ = pixel ? palette[color] : 18'd0;

assign CLK_VIDEO = clk_sys;

wire ce_pix_out;
wire crtcDe_tmp;

// YOM Sin Video_Mixer ni Video_Freak
assign CE_PIXEL = ce_pix;
assign VGA_R = {rgbQ[17:12],2'b0};
assign VGA_G = {rgbQ[11: 6],2'b0};
assign VGA_B = {rgbQ[ 5: 0],2'b0};
//assign VGA_VS = VSync;
//assign VGA_HS = HSync;
//assign VGA_DE = crtcDe_tmp;//~(VBlank | HBlank);
//
//assign VIDEO_ARX = 4;
//assign VIDEO_ARY = 3;

// YOM Sin Video_Freak pero si con video_mixer
//assign VIDEO_ARX = 4;
//assign VIDEO_ARY = 3;
//assign VGA_DE = crtcDe_tmp;




//Mister TapeIn

wire tape_in;
wire tape_adc, tape_adc_act;

assign tape_in = 1'b0;



endmodule


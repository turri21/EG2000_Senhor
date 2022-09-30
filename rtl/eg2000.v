`timescale 1ps / 1ps

//-------------------------------------------------------------------------------------------------
module eg2000
//-------------------------------------------------------------------------------------------------
(
	input  wire        clock,
	input  wire        power,

	output wire        hsync,
	output wire        vsync,

`ifdef USE_CE_PIX
	output wire        ce_pix,
`endif	

`ifdef USE_BLANK
	output wire        hblank,
	output wire        vblank,
`endif	

	output wire        pixel,
	output wire [ 3:0] color,
	output wire		   crtcDe,

	input  wire        tape,

`ifdef USE_DAC
	output wire        sound,
`else
	output wire [15:0] audio_l,
	output wire [15:0] audio_r,
`endif

`ifdef MISTER
	input  wire [10:0] ps2_key, // [7:0] - scancode,
	input  wire [31:0] joy0,
	input  wire [31:0] joy1,
	input  wire [15:0] joya0,
	input  wire [15:0] joya1,
	input  wire [ 1:0] joyAD, // Select Analog or DPAD for Joysticks [0] = Player 1, [1] = Player 2
`else
    input  wire [ 1:0] ps2,
`endif
	output wire        led,

`ifdef ZX1
	output wire        boot,
	output wire        ramWe,
	inout  wire [ 7:0] ramDQ,
	output wire [20:0] ramA,
`elsif USE_SDRAM
	output wire        ramCk,
	output wire        ramCe,
	output wire        ramCs,
	output wire        ramWe,
	output wire        ramRas,
	output wire        ramCas,
	output wire [ 1:0] ramDqm,
	inout  wire [15:0] ramDQ,
	output wire [ 1:0] ramBA,
	output wire [12:0] ramA,
`endif

	input wire  [ 1:0] tape_vol

);
//-------------------------------------------------------------------------------------------------

always @(negedge clock) ce <= ce+1'd1;

`ifdef VERILATOR
reg [ 3:0] ce;

assign ce_pix =pe8M8;
wire pe8M8 = ce[0] ;
wire ne8M8 = ~ce[0];

wire ne4M4 = ~ce[0] & ~ce[1] ;

wire pe2M2 = ~ce[0] & ~ce[1] & ce[2];
wire ne2M2 = ~ce[0] & ~ce[1] & ~ce[2];

wire pe1M1 = ~ce[0] & ~ce[1] & ~ce[2] &  ce[3];
wire ne1M1 = ~ce[0] & ~ce[1] & ~ce[2] & ~ce[3];
`else
reg [ 4:0] ce;
assign ce_pix = pe8M8;
wire pe8M8 = ~ce[0] &  ce[1];
wire ne8M8 = ~ce[0] & ~ce[1];

wire ne4M4 = ~ce[0] & ~ce[1] & ~ce[2];

wire pe2M2 = ~ce[0] & ~ce[1] & ~ce[2] &  ce[3];
wire ne2M2 = ~ce[0] & ~ce[1] & ~ce[2] & ~ce[3];

wire pe1M1 = ~ce[0] & ~ce[1] & ~ce[2] & ~ce[3] &  ce[4];
`endif

//-------------------------------------------------------------------------------------------------

wire ioF8 = !(!iorq && a[7:0] == 8'hF8); // psg addr
wire ioF9 = !(!iorq && a[7:0] == 8'hF9); // psg data

wire ioFA = !(!iorq && a[7:0] == 8'hFA); // crtc addr
wire ioFB = !(!iorq && a[7:0] == 8'hFB); // crtc data

wire ioFF = !(!iorq && a[7:0] == 8'hFF);

//-------------------------------------------------------------------------------------------------

wire reset = power & kreset;

assign led = reset;
wire [ 7:0] d;
wire [ 7:0] q;
wire [15:0] a;

wire rfsh, mreq, iorq, rd, wr;

cpu Cpu
(
	.clock  (clock  ),
	.cep    (pe2M2  ),
	.cen    (ne2M2  ),
	.reset  (reset  ),
	.rfsh   (rfsh   ),
	.mreq   (mreq   ),
	.iorq   (iorq   ),
	.rd     (rd     ),
	.wr     (wr     ),
	.m1     (m1     ),
	.nmi    (nmi    ),
	.d      (d      ),
	.q      (q      ),
	.a      (a      )
);

//-------------------------------------------------------------------------------------------------

wire crtcCs = !(!ioFA || !ioFB);
wire crtcRs = a[0];
wire crtcRw = wr;
wire m1;

wire [ 7:0] crtcQ;

wire [13:0] crtcMa;
wire [ 4:0] crtcRa;

wire cursor;

UM6845R Crtc
(
	.TYPE   (1'b0   ),
	.CLOCK  (clock  ),
	.CLKEN  (pe1M1  ),
	.nRESET (reset  ),
	.ENABLE (1'b1   ),
	.nCS    (crtcCs ),
	.R_nW   (crtcRw ),
	.RS     (crtcRs ),
	.DI     (q      ),
	.DO     (crtcQ  ),
	.VSYNC  (vsync  ),
	.HSYNC  (hsync  ),

`ifdef USE_BLANK
	.HBLANK (hblank ),
	.VBLANK (vblank ),
`endif	

	.DE     (crtcDe ),
	.FIELD  (       ),
	.CURSOR (cursor ),
	.MA     (crtcMa ),
	.RA     (crtcRa )
);

reg [ 1:0] cur;
always @(posedge clock) if(pe1M1) cur <= { cur[0], cursor };

//-------------------------------------------------------------------------------------------------

wire bdir = (!wr && !ioF8) || (!wr && !ioF9);
wire bc1  = (!wr && !ioF8) || (!rd && !ioF9);

wire [11:0] psgA;
wire [11:0] psgB;
wire [11:0] psgC;
wire [ 7:0] psgQ;


psg Psg
(
	.clock     (clock),
	.sel       (1'b1 ),
	.ce        (pe2M2),

	.reset     (reset),
	.bdir      (bdir ),
	.bc1       (bc1  ),
	.d         (q    ),
	.q         (psgQ ),

	.a         (psgA ),
	.b         (psgB ),
	.c         (psgC ),
	.mix       (mix  ),

	.ioad      (ioad ),
	.ioaq      (ioaq ),

	.iobd      (iobd ),
	.iobq      (iobq )
);
wire[13:0] mix;

wire[ 7:0] ioad;
wire[ 7:0] ioaq;

wire[ 7:0] iobd;
wire[ 7:0] iobq;


`ifdef MISTER

//JOYSTICKS

eg2000_joystick joysticks
(
	.clk    (clock    ),
	
	.p1_dpad(joyAD[0] ),
	.p2_dpad(joyAD[1] ),
	
	.portA_i(ioaq[5:0]),
	.portB_o(iobd     ),
	
	.ps2_key(ps2_key  ),
	
	.joy0   (joy0     ),
	.joy1   (joy1     ),
	.joya0  (joya0    ),
	.joya1  (joya1    )
);

`endif

//-------------------------------------------------------------------------------------------------

	
`ifdef USE_DAC
wire [ 11:0] dacD = psgA + psgB + psgC  + { 1'b0, |tape_vol ? (tape_vol == 2'd1 ? {1'b0,tape} : {tape,1'b0} ): 2'b00, 9'b0 };

dac #(.MSBI(9)) Dac
(
	.clock  (clock  ),
	.reset  (reset  ),
	.d      (dacD   ),
	.q      (sound  )
);
`else
assign audio_l = {mix + { 1'b0, |tape_vol ? (tape_vol == 2'd1 ? {1'b0,tape} : {tape,1'b0} ): 2'b00, 9'b0 },2'b0};
assign audio_r = audio_l;
`endif

//-------------------------------------------------------------------------------------------------

wire [ 7:0] keyQ;
wire [ 7:0] keyA = a[ 7:0];
wire nmi,boot,kreset;

`ifdef ZX1
	keyboard Keyboard
`else
	keyboard #(.BOOT(8'h0A), .RESET(8'h78)) Keyboard //Boot(F8) - Reset(F11)
`endif
(
	.clock  (clock  ),
	.ce     (pe8M8  ),

`ifdef MISTER
	.ps2_key(ps2_key),
`else
	.ps2    (ps2    ),
`endif

	.nmi    (nmi    ),
	.boot   (boot   ),
	.reset  (kreset ),
	.q      (keyQ   ),
	.a      (keyA   )
);

//-------------------------------------------------------------------------------------------------

reg mode, c, b;
always @(posedge clock) if(pe2M2) if(!ioFF && !wr) { mode, c, b } <= q[5:3];

//-------------------------------------------------------------------------------------------------

wire [13:0] vma = crtcMa;
wire [ 2:0] vra = crtcRa[2:0];

wire [ 7:0] memQ;
wire ven;

memory Memory
(
	.clock  (clock  ),
	.hsync  (hsync  ),
	.vcep   (pe8M8  ),
	.vcen   (ne8M8  ),
	.hrce   (ne4M4  ),
	.vma    (vma    ),
	.vra    (vra    ),
	.b      (b      ),
	.c      (c      ),
	.mode   (mode   ),
	.ven    (ven    ),
	.color  (color  ),
	.ce     (pe2M2  ),
	.rfsh   (rfsh   ),
	.mreq   (mreq   ),
	.rd     (rd     ),
	.wr     (wr     ),
	.d      (q      ),
	.q      (memQ   ),
	.a      (a      ),
	.keyQ   (keyQ   ),

`ifdef ZX1 
	.ramWe  (ramWe  ),
	.ramDQ  (ramDQ  ),
	.ramA   (ramA   )
`elsif USE_SDRAM
	.ramCk  (ramCk  ),
	.ramCe  (ramCe  ),
	.ramCs  (ramCs  ),
	.ramWe  (ramWe  ),
	.ramRas (ramRas ),
	.ramCas (ramCas ),
	.ramDqm (ramDqm ),
	.ramDQ  (ramDQ  ),
	.ramBA  (ramBA  ),
	.ramA   (ramA   )
`endif

);

assign pixel = (ven || cur[1]) && crtcDe;

//-------------------------------------------------------------------------------------------------

assign d
	= !mreq ? memQ
	: !ioF9 ? psgQ
	: !ioFB ? crtcQ
	: !ioFF ? { 7'b0, tape}
	: 8'hFF;

//-------------------------------------------------------------------------------------------------


endmodule

////-------------------------------------------------------------------------------------------------

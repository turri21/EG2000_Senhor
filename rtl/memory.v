`timescale 1ps / 1ps

//-------------------------------------------------------------------------------------------------
module memory
//-------------------------------------------------------------------------------------------------
(
	input  wire       clock,

	input  wire       hsync,
	input  wire       vcep,
	input  wire       vcen,
	input  wire       hrce,
	input  wire[13:0] vma,
	input  wire[ 2:0] vra,
	input  wire       b,
	input  wire       c,
	input  wire       mode,
	output wire       ven,
	output wire[ 3:0] color,

	input  wire       ce,
	input  wire       rfsh,
	input  wire       mreq,
	input  wire       rd,
	input  wire       wr,
	input  wire[ 7:0] d,
	output wire[ 7:0] q,
	input  wire[15:0] a,

	input  wire[ 7:0] keyQ,
`ifdef ZX1
	output wire       ramWe,
	inout  wire[ 7:0] ramDQ,
	output wire[20:0] ramA
`elsif USE_BRAM
   output wire       filler
`elsif USE_SDRAM 
	output wire       ramCk,
	output wire       ramCe,
	output wire       ramCs,
	output wire       ramWe,
	output wire       ramRas,
	output wire       ramCas,
	output wire[ 1:0] ramDqm,
	inout  wire[15:0] ramDQ,
	output wire[ 1:0] ramBA,
	output wire[12:0] ramA	
`endif
);
//-------------------------------------------------------------------------------------------------

reg[2:0] hCount;
always @(posedge clock) if(hsync) hCount <= 1'd0; else if(vcep) hCount <= hCount+1'd1;

//-------------------------------------------------------------------------------------------------

wire[ 7:0] romQ;
wire[13:0] romA = a[13:0];

rom #(.KB(16), .FN("basic.hex")) Rom
(
	.clock  (clock  ),
	.ce     (ce     ),
	.q      (romQ   ),
	.a      (romA   )
);

//-------------------------------------------------------------------------------------------------

wire[ 7:0] fntQ;
wire[10:0] fntA = { video, vra };

rom #(.KB(2), .FN("font.hex")) Font
(
	.clock  (clock  ),
	.ce     (vcep   ),
	.q      (fntQ   ),
	.a      (fntA   )
);

//-------------------------------------------------------------------------------------------------
`ifdef ZX1

assign ramWe = !(!mreq && !wr);
assign ramDQ = ramWe ? 8'bZ : d;
assign ramA  = { 5'd0, a };

wire[7:0] ramQ = ramDQ;
`elsif USE_BRAM
//-------------------------------------------------------------------------------------------------

wire extWe = !(!mreq && !wr);
wire[ 7:0] ramQ;
//wire[13:0] extA = a[13:0];

ram #(.KB(64)) ExtendedRam
(
        .clock  (clock  ),
        .ce     (ce     ),
        .we     (extWe  ),
        .d      (d      ),
        .q      (ramQ   ),
        .a      (a      )
);

`elsif USE_SDRAM

wire sdrRd = !(!mreq && !rd);
wire sdrWr = !(!mreq && !wr);

wire[15:0] sdrD = {2{d}};
wire[15:0] sdrQ;
wire[23:0] sdrA  = { 8'd0, a };

wire[7:0] ramQ = ramDQ[7:0];

sdram SDram
(
	.clock  (clock  ),
	.reset  (reset  ),
	.ready  (ready  ),
	.refresh(rfsh   ),
	.write  (sdrWr  ),
	.read   (sdrRd  ),
	.portD  (sdrD   ),
	.portQ  (sdrQ   ),
	.portA  (sdrA   ),
	.ramCk  (ramCk  ),
	.ramCe  (ramCe  ),
	.ramCs  (ramCs  ),
	.ramRas (ramRas ),
	.ramCas (ramCas ),
	.ramWe  (ramWe  ),
	.ramDqm (ramDqm ),
	.ramDQ  (ramDQ  ),
	.ramBA  (ramBA  ),
	.ramA   (ramA   )
);

`endif
//-------------------------------------------------------------------------------------------------

wire[ 7:0] ramQ1;
wire[13:0] ramA1 = vma;

wire ramWe2 = !(!mreq && !wr && a[15:14] == 2'b01);
wire[13:0] ramA2 = a[13:0];

dprs #(.KB(16)) Ram
(
	.clock  (clock  ),
	.ce1    (vcep   ),
	.q1     (ramQ1  ),
	.a1     (ramA1  ),
	.ce2    (ce     ),
	.we2    (ramWe2 ),
	.d2     (d      ),
	.a2     (ramA2  )
);

reg[7:0] video;
always @(posedge clock) if(vcen) if(hCount == 0) video <= ramQ1;

//-------------------------------------------------------------------------------------------------

wire[7:0] colQ1;
wire[9:0] colA1 = vma[9:0];

wire colWe2 = !(!mreq && !wr && a[15:10] == 6'b111100);
wire[9:0] colA2 = a[9:0];

dprs #(.KB(1)) Color
(
	.clock  (clock  ),
	.ce1    (vcep   ),
	.q1     (colQ1  ),
	.a1     (colA1  ),
	.ce2    (ce     ),
	.we2    (colWe2 ),
	.d2     (d      ),
	.a2     (colA2  )
);

reg[7:0] csr;
always @(posedge clock) if(vcen) if(hCount == 0) csr <= { csr[3:0], colQ1[3:0] };

//-------------------------------------------------------------------------------------------------

wire[7:0] chrQ1;
wire[9:0] chrA1 = { video[6:0], vra };

wire chrWe2 = !(!mreq && !wr && a[15:10] == 6'b111101);
wire[9:0] chrA2 = a[9:0];

dprs #(.KB(1)) Char
(
	.clock  (clock  ),
	.ce1    (vcep   ),
	.q1     (chrQ1  ),
	.a1     (chrA1  ),
	.ce2    (ce     ),
	.we2    (chrWe2 ),
	.d2     (d      ),
	.a2     (chrA2  )
);


//-------------------------------------------------------------------------------------------------

reg[7:0] psr;
wire ds = video[7] && ((!c && !video[6]) || (!b && video[6]));
always @(posedge clock) if(vcen) if(hCount == 0) psr <= ds ? chrQ1 : fntQ; else psr <= { psr[6:0], 1'b0 };

reg[3:0] hrsr1;
reg[3:0] hrsr0;
always @(posedge clock) if(hrce)
if(hCount == 0) begin
	hrsr1 <= { video[7], video[5], video[3], video[1] };
	hrsr0 <= { video[6], video[4], video[2], video[0] };
end else begin
	hrsr1 <= { hrsr1[2:0], 1'b0 };
	hrsr0 <= { hrsr0[2:0], 1'b0 };
end

wire[1:0] hrcol = { hrsr1[3], hrsr0[3] };

//-------------------------------------------------------------------------------------------------

assign ven = mode ? |hrcol : psr[7];
assign color
	= mode && hrcol == 1 ? 4'h8
	: mode && hrcol == 2 ? 4'h2
	: mode && hrcol == 3 ? 4'h5
	: csr[7:4];


assign q
	= a[15:14] == 2'b00 ? romQ
	: a[15:14] == 2'b01 ? ramQ
	: a[15:14] == 2'b10 ? ramQ
	: a[15:10] == 6'b111100 ? ramQ
	: a[15:10] == 6'b111101 ? ramQ
	: a[15:10] == 6'b111110 ? keyQ
	: 8'hFF;

//-------------------------------------------------------------------------------------------------
endmodule
//-------------------------------------------------------------------------------------------------

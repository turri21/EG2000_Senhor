`timescale 1ps / 1ps

//-------------------------------------------------------------------------------------------------
module cpu
//-------------------------------------------------------------------------------------------------
(
	input  wire       clock,
	input  wire       cep,
	input  wire       cen,
	input  wire       reset,
	output wire       rfsh,
	output wire       mreq,
	output wire       iorq,
	input  wire       nmi,
	output wire       wr,
	output wire       rd,
	output wire       m1,
	input  wire[ 7:0] d,
	output wire[ 7:0] q,
	output wire[15:0] a
);
//-------------------------------------------------------------------------------------------------
`ifdef VERILATOR
tv80e Z80CPU (
        .m1_n(m1),
        .mreq_n(mreq),
        .iorq_n(iorq),
        .rd_n(rd),
        .wr_n(wr),
        .rfsh_n(rfsh),
        .halt_n(),
        .busak_n(),
        .A(a),
        .dout(q),
        .reset_n(reset),
        .clk(clock),
        .cen(cen),
        .wait_n(1'b1),
        .int_n(1'b1),
        .nmi_n(nmi),
        .busrq_n(1'b1),
        .di(d),
        .dir(1'b0),
        .dirset(212'd0)

);
`else

T80pa Cpu
(
	.CLK    (clock),
	.CEN_p  (cep  ),
	.CEN_n  (cen  ),
	.RESET_n(reset),
	.BUSRQ_n(1'b1 ),
	.WAIT_n (1'b1 ),
	.BUSAK_n(     ),
	.HALT_n (     ),
	.RFSH_n (rfsh ),
	.MREQ_n (mreq ),
	.IORQ_n (iorq ),
	.NMI_n  (nmi  ),
	.INT_n  (1'b1 ),
	.WR_n   (wr   ),
	.RD_n   (rd   ),
	.M1_n   (m1   ),
	.DI     (d    ),
	.DO     (q    ),
	.A      (a    ),
	.OUT0   (1'b0 ),
	.REG    (     ),
	.DIRSet (1'b0 ),
	.DIR    (212'd0)
);
`endif
//-------------------------------------------------------------------------------------------------
endmodule
//-------------------------------------------------------------------------------------------------

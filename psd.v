`default_nettype none
//-------------------------------------------------------------------------------------------------
module psd
//-------------------------------------------------------------------------------------------------
(
	input  wire       clock50,

	output wire[ 2:0] led,

	output wire[17:0] rgb,
	output wire[ 1:0] sync,

	input  wire       ear,

	output wire       i2sCk,
	output wire       i2sWs,
	output wire       i2sQ,

	output wire       dramCk,
	output wire       dramCe,
	output wire       dramCs,
	output wire       dramWe,
	output wire       dramRas,
	output wire       dramCas,
	output wire[ 1:0] dramDQM,
	inout  wire[15:0] dramDQ,
	output wire[ 1:0] dramBA,
	output wire[12:0] dramA,

	input  wire       spiCk,
	input  wire       spiSs1,
	input  wire       spiSs2,
	input  wire       spiSs3,
	input  wire       spiMosi,
	output wire       spiMiso
);
//--- clock ---------------------------------------------------------------------------------------

	wire clock;
	wire power;

	pll48 pll48(clock50, clock, power);

	reg[4:0] ce;
	always @(negedge clock, negedge power) if(!power) ce <= 1'd0; else ce <= ce+1'd1;

	wire pe24M = ce[0:0] == 0;
	wire pe12M = ce[1:0] == 1;

	wire ne6M0 = ce[2:0] == 7;
	wire pe6M0 = ce[2:0] == 3;

	wire pe1M5 = ce[4:0] == 15;

//--- video ---------------------------------------------------------------------------------------

	wire r;
	wire g;
	wire b;
	wire hsync;
	wire vsync;

//--- audio ---------------------------------------------------------------------------------------

	wire[5:0] sound;
	wire[15:0] mix = { 4'd0, sound, 4'd0 }+{ 4'd0, {12{ tape && status[4] }} };

	i2s i2s(clock50, mix, mix, i2sCk, i2sWs, i2sQ);

//--- keyboard ------------------------------------------------------------------------------------

	wire      ps2kCk;
	wire      ps2kD;
	wire      strb;
	wire[7:0] code;

	ps2k ps2k(clock, ps2kCk, ps2kD, strb, code);

	wire[3:0] row;
	wire[7:0] col;
	wire F9, play, stop, break;

	matrix matrix(clock, strb, code, row, col, F9, play, stop, break);

//--- mist ----------------------------------------------------------------------------------------

	wire       ready;
	wire[63:0] status;

	wire[ 7:0] joy0;
	wire[ 7:0] joy1;

	wire       dioE;
	wire[26:0] dioA;
	wire[ 7:0] dioD;
	wire       dioW;

	wire[ 1:0] fdcA;
	wire[ 7:0] fdcD;
	wire[ 7:0] fdcQ;
	wire       fdcR;
	wire       fdcW;
	wire       fdcSel;
	wire       fdcSide;

	wire tzxEar;
	wire tzxBusy;
	wire motor;

	mist #(.RGBW(6)) mist
	(
		.clock  (clock  ),
		.pe24M  (pe24M  ),
		.pe12M  (pe12M  ),
		.pe6M0  (pe6M0  ),
		.reset  (reset  ),
		.spiCk  (spiCk  ),
		.spiSs1 (spiSs1 ),
		.spiSs2 (spiSs2 ),
		.spiSs3 (spiSs3 ),
		.spiMosi(spiMosi),
		.spiMiso(spiMiso),
		.ready  (ready  ),
		.status (status ),
		.r      (r      ),
		.g      (g      ),
		.b      (b      ),
		.hsync  (hsync  ),
		.vsync  (vsync  ),
		.rgb    (rgb    ),
		.sync   (sync   ),
		.ps2kCk (ps2kCk ),
		.ps2kD  (ps2kD  ),
		.joy0   (joy0   ),
		.joy1   (joy1   ),
		.dioE   (dioE   ),
		.dioA   (dioA   ),
		.dioD   (dioD   ),
		.dioW   (dioW   ),
		.fdcA   (fdcA   ),
		.fdcD   (fdcD   ),
		.fdcQ   (fdcQ   ),
		.fdcR   (fdcR   ),
		.fdcW   (fdcW   ),
		.fdcSel (fdcSel ),
		.fdcSide(fdcSide),
		.tzxEar (tzxEar ),
		.tzxBusy(tzxBusy),
		.tzxPlay(~play  ),
		.tzxStop(~stop  ),
		.tzxMotor(motor )
	);

//--- memory --------------------------------------------------------------------------------------

	wire[15:0] mem0A;
	wire[ 7:0] mem0Q = sdrQ[7:0];
	wire       mem0R;

	wire[15:0] mem1A;
	wire[ 7:0] mem1D;
	wire[ 7:0] mem1Q = sdrQ[7:0];
	wire       mem1R;
	wire       mem1W;

	wire[15:0] mem2A1;
	wire[ 7:0] mem2Q1;

	wire[15:0] mem2A2;
	wire[ 7:0] mem2D2;
	wire[ 7:0] mem2Q2;
	wire       mem2W2;

	wire[15:0] mem4A;
	wire[ 7:0] mem4D;
	wire[ 7:0] mem4Q = sdrQ[7:0];
	wire       mem4R;
	wire       mem4W;

	reg[1:0] romP;
	always @*
		casex(mem0A[15:13])
			3'd0: romP = 2'd0; // rom.0
			3'd1: romP = 2'd1; // rom.1
			3'd2: romP = 2'd2; // rom.2
			3'd7: romP = 2'd3; // xdos
			default: romP = 2'd3;
		endcase
	
	dprf #(64) mem2
	(
		.clock1 (clock  ),
		.a1     (mem2A1 ),
		.d1     (8'hFF  ),
		.q1     (mem2Q1 ),
		.w1     (1'b0   ),
		.clock2 (clock  ),
		.a2     (mem2A2 ),
		.d2     (mem2D2 ),
		.q2     (mem2Q2 ),
		.w2     (mem2W2 )
	);

	wire[23:0] sdrA  = { 6'd0, dioE ? { 2'd0, dioA[15:0] } : mem0R ? { 2'd0, romP, mem0A[12:0]} : mem1R || mem1W ? { 2'd1, mem1A } : { 2'd2, mem4A } };
	wire[15:0] sdrD =  { 8'hFF, dioE ? dioD : mem1W ? mem1D : mem4D };
	wire[15:0] sdrQ;
	wire       sdrR = mem0R || mem1R || mem4R;
	wire       sdrW = dioE ? dioW : mem1W || mem4W;

	sdram sdram
	(
		.clock  (clock  ),
		.ready  (       ),
		.reset  (power  ),
		.rfsh   (rfsh   ),
		.a      (sdrA   ),
		.d      (sdrD   ),
		.q      (sdrQ   ),
		.rd     (sdrR   ),
		.wr     (sdrW   ),
		.dramCe (dramCe ),
		.dramCs (dramCs ),
		.dramWe (dramWe ),
		.dramRas(dramRas),
		.dramCas(dramCas),
		.dramDQM(dramDQM),
		.dramDQ (dramDQ ),
		.dramBA (dramBA ),
		.dramA  (dramA  )
	);

	assign dramCk = clock;

//--- lynx -----------------------------------------------------------------------------------------

	wire reset = power && ready && F9 && !status[0];
	wire rfsh;

	wire tape = tzxBusy ? tzxEar : ~ear;

	lynx lynx
	(
		.clock  (clock  ),
		.pe12M  (pe12M  ),
		.ne6M0  (ne6M0  ),
		.pe6M0  (pe6M0  ),
		.pe1M5  (pe1M5  ),
		.reset  (reset  ),
		.rfsh   (rfsh   ),
		.r      (r      ),
		.g      (g      ),
		.b      (b      ),
		.blank  (       ),
		.hsync  (hsync  ),
		.vsync  (vsync  ),
		.sound  (sound  ),
		.row    (row    ),
		.col    (col    ),
		.break  (break  ),
		.joy0   (joy0   ),
		.joy1   (joy1   ),
		.mem0A  (mem0A  ),
		.mem0Q  (mem0Q  ),
		.mem0R  (mem0R  ),
		.mem1A  (mem1A  ),
		.mem1D  (mem1D  ),
		.mem1Q  (mem1Q  ),
		.mem1R  (mem1R  ),
		.mem1W  (mem1W  ),
		.mem2A1 (mem2A1 ),
		.mem2Q1 (mem2Q1 ),
		.mem2A2 (mem2A2 ),
		.mem2D2 (mem2D2 ),
		.mem2Q2 (mem2Q2 ),
		.mem2W2 (mem2W2 ),
		.mem4A  (mem4A  ),
		.mem4D  (mem4D  ),
		.mem4Q  (mem4Q  ),
		.mem4R  (mem4R  ),
		.mem4W  (mem4W  ),
		.tape   (tape   ),
		.motor  (motor  ),
		.fdcA   (fdcA   ),
		.fdcD   (fdcD   ),
		.fdcQ   (fdcQ   ),
		.fdcR   (fdcR   ),
		.fdcW   (fdcW   ),
		.fdcSel (fdcSel ),
		.fdcSide(fdcSide)
	);

//-------------------------------------------------------------------------------------------------

	assign led = ~{ tape, 2'b00 };

//-------------------------------------------------------------------------------------------------
endmodule
//-------------------------------------------------------------------------------------------------

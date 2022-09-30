//-------------------------------------------------------------------------------------------------
// Parallel Port Joysticks for EACA EG2000 Colour Genie by Flandango
// Analog or Digital (Dpad) input
// Player 1 keypad mapping : 0-9, - (#), = (*) on Keyboard
// Player 2 keypad mapping : 0-9, / (#), *     on NumPad


module eg2000_joystick
(
	input  wire        clk,

	input  wire        p1_dpad,
	input  wire        p2_dpad,
	input  wire [ 5:0] portA_i,
	output wire [ 7:0] portB_o,
	input  wire [10:0] ps2_key, // [7:0] - scancode,
	input  wire [31:0] joy0,
	input  wire [31:0] joy1,
	input  wire [15:0] joya0,
	input  wire [15:0] joya1
);

wire [ 5:0] j_select;  //Joystick Line to Read (from PortA)
wire [ 3:0] j_data;    //Joystick Data
wire [ 7:0] joy0_x, joy0_y, joy1_x, joy1_y;
wire [ 3:0] keypad[6];
reg  [ 5:0] joyd0_x, joyd0_y, joyd1_x, joyd1_y;

always @(posedge clk) begin
	if(joy0[1]) joyd0_x <= 6'h0;
	else if(joy0[0]) joyd0_x <= 6'h3F;
	else joyd0_x <= 6'h1F;

	if(joy0[2]) joyd0_y <= 6'h0;
	else if(joy0[3]) joyd0_y <= 6'h3F;
	else joyd0_y <= 6'h1F;
	
	if(joy1[1]) joyd1_x <= 6'h0;
	else if(joy1[0]) joyd1_x <= 6'h3F;
	else joyd1_x <= 6'h1F;

	if(joy1[2]) joyd1_y <= 6'h0;
	else if(joy1[3]) joyd1_y <= 6'h3F;
	else joyd1_y <= 6'h1F;
end

// * # 0 1 2 3 4  5  6  7  8  9   - Keypad
// 4 5 6 7 8 9 10 11 12 13 14 15  - Joystick Button Index
assign keypad[0] = {joy0[5] | p1_hash, joy0[15] | p1_9, joy0[12] | p1_6, joy0[9] | p1_3};
assign keypad[1] = {joy0[6] | p1_0   , joy0[14] | p1_8, joy0[11] | p1_5, joy0[8] | p1_2};
assign keypad[2] = {joy0[4] | p1_ast , joy0[13] | p1_7, joy0[10] | p1_4, joy0[7] | p1_1};
assign keypad[3] = {joy1[5] | p2_hash, joy1[15] | p2_9, joy1[12] | p2_6, joy1[9] | p2_3};
assign keypad[4] = {joy1[6] | p2_0   , joy1[14] | p2_8, joy1[11] | p2_5, joy1[8] | p2_2};
assign keypad[5] = {joy1[4] | p2_ast , joy1[13] | p2_7, joy1[10] | p2_4, joy1[7] | p2_1};


assign joy0_x  = p1_dpad ? joyd0_x : (8'd127 + joya0[ 7:0]) / 8'd4;
assign joy0_y  = p1_dpad ? joyd0_y : (8'h3F - ((8'd127 + joya0[15:8]) / 8'd4));
assign joy1_x  = p2_dpad ? joyd1_x : (8'd127 + joya1[ 7:0]) / 8'd4;
assign joy1_y  = p2_dpad ? joyd1_y : (8'h3F - ((8'd127 + joya1[15:8]) / 8'd4));

assign j_select = portA_i;

assign j_data[3] = joy0_x > j_select ? 1'b1 : 1'b0;
assign j_data[2] = joy0_y > j_select ? 1'b1 : 1'b0;
assign j_data[1] = joy1_x > j_select ? 1'b1 : 1'b0;
assign j_data[0] = joy1_y > j_select ? 1'b1 : 1'b0;


assign portB_o[7:4] = j_data;
assign portB_o[3:0] = ~j_select[0] ? ~keypad[0] :
                      ~j_select[1] ? ~keypad[1] :
                      ~j_select[2] ? ~keypad[2] :
                      ~j_select[3] ? ~keypad[3] :
                      ~j_select[4] ? ~keypad[4] :
                      ~j_select[5] ? ~keypad[5] : 4'hF;


//Keypads
wire       pressed = ps2_key[9];
wire [8:0] code    = ps2_key[8:0];


always @(posedge clk) begin
	reg old_state;
	old_state <= ps2_key[10];
	
	if(old_state != ps2_key[10]) begin
		casex(code[7:0])
			'h16: p1_1     <= pressed; // 1
			'h1E: p1_2     <= pressed; // 2
			'h26: p1_3     <= pressed; // 3
			'h25: p1_4     <= pressed; // 4
			'h2E: p1_5     <= pressed; // 5
			'h36: p1_6     <= pressed; // 6
			'h3D: p1_7     <= pressed; // 7
			'h3E: p1_8     <= pressed; // 8
			'h46: p1_9     <= pressed; // 9
			'h45: p1_0     <= pressed; // 0
			'h4E: p1_hash  <= pressed; // - => #
			'h55: p1_ast   <= pressed; // = => *

			'h69: p2_1     <= pressed; // 1-NUMPAD
			'h72: p2_2     <= pressed; // 2-NUMPAD
			'h7A: p2_3     <= pressed; // 3-NUMPAD
			'h6B: p2_4     <= pressed; // 4-NUMPAD
			'h73: p2_5     <= pressed; // 5-NUMPAD
			'h74: p2_6     <= pressed; // 6-NUMPAD
			'h6C: p2_7     <= pressed; // 7-NUMPAD
			'h75: p2_8     <= pressed; // 8-NUMPAD
			'h7D: p2_9     <= pressed; // 9-NUMPAD
			'h70: p2_0     <= pressed; // 0-NUMPAD
			'h4A: p2_hash  <= pressed; // /-NUMPAD => #
			'h7C: p2_ast   <= pressed; // *-NUMPAD

		endcase
	end
end

// Keypads
reg p1_1 = 0;
reg p1_2 = 0;
reg p1_3 = 0;
reg p1_4 = 0;
reg p1_5 = 0;
reg p1_6 = 0;
reg p1_7 = 0;
reg p1_8 = 0;
reg p1_9 = 0;
reg p1_0 = 0;
reg p1_hash = 0;
reg p1_ast = 0;

reg p2_1 = 0;
reg p2_2 = 0;
reg p2_3 = 0;
reg p2_4 = 0;
reg p2_5 = 0;
reg p2_6 = 0;
reg p2_7 = 0;
reg p2_8 = 0;
reg p2_9 = 0;
reg p2_0 = 0;
reg p2_hash = 0;
reg p2_ast = 0;
							 
endmodule

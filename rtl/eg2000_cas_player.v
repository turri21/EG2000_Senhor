// CAS Virtual Tape File Player for EACA EG2000 Colour Genie by Flandango

module eg2000_cas_player
#( parameter
	CLK_RATE = 35467980      // Clock Rate Default = 35.467980
)
(
	input  wire              clk,
	input  wire              reset,
	input  wire              ioctl_download,
	input  wire [23:0]       ioctl_addr,
	input  wire  [7:0]       ioctl_dout,
	input  wire              ioctl_wr,
	output reg               ioctl_wait,
	input  wire              play,
	input  wire              rewind,
	input  wire              eject,
	output wire  [12:0]      status, // [12:3]  = Tape Counter (in ~seconds), [2:0] = [2]1=Eot Reached [1] 1=Playing/0=Stopped [0] 1=Tape Loaded/0=Not Loaded(Ejected)
	output wire   [1:0]      tape_type, // 0 - No tape loaded, 1 - Basic, 2 - System, 3 - Data
	output reg   [47:0]      system_tape_filename,
	output reg               tape
);

localparam CPP = CLK_RATE / 1200; //Clk Cycles Per Pulse (Clock Rate divided by Baud Rate)

wire [16:0]      ram_addr;
wire [ 7:0]      ram_dout;

assign ram_addr = ioctl_download ? tape_ram_addr : erasing ? erase_addr : io_ram_addr;
assign tape_type = basic_tape_found ? 2'd1 : system_tape_found ? 2'd2 : data_tape_found ? 2'd3 : 2'd0;

//-------------------------------------------------------------------------------------------------

ram #(.KB(128)) taperam
(
        .clock  (clk  ),
        .ce     (1'b1   ),
        .we     (~(tape_cas_downloading ? tape_ram_wr : erasing ? erase_wr :1'b0)    ),
        .d      (erasing ? 8'h00 : tape_ram_din      ),
        .q      (ram_dout   ),
        .a      (ram_addr      )
);
reg [16:0] tape_length;

//Process CAS file
localparam CL_IDLE          = 0;
localparam CL_CREATE_HEADER = 1;
localparam CL_FIND_BOT      = 2;
localparam CL_LOAD_TAPE     = 3;
localparam CL_WRITE_EOT     = 4;

reg [2:0]  cl_state = CL_IDLE;

reg [16:0] tape_ram_addr;
reg [16:0] io_ram_addr;
reg        tape_ram_wr = 1'b0;
reg [7:0]  tape_ram_din;
reg        tape_playing;
reg        eot = 1'b0;

reg old_ioctl_download;
reg old_ram_wr;
reg [16:0] old_ioctl_addr;
reg tape_cas_downloading;
// Logic for gathering System Tape Filename
reg [16:0] bot_marker_pos;
reg        system_tape_found;
reg        basic_tape_found;
reg        data_tape_found;


always @(posedge clk) begin
	old_ioctl_download <= ioctl_download;
	old_ram_wr <= tape_ram_wr;
	old_ioctl_addr <= ioctl_addr[16:0];
	if(reset) begin
		cl_state <= CL_IDLE;
		ioctl_wait <= 1'b0;
		tape_cas_downloading <= 1'b0;
		bot_marker_pos <= 17'h00000;
//		system_tape_found <= 1'b0;
//		system_tape_filename <= 48'd0;
	end
	else if(done_erasing_ram) tape_length <= 17'h00000;
	else if(eject) begin
		system_tape_found <= 1'b0;
		basic_tape_found <= 1'b0;
		data_tape_found <= 1'b0;
	end
	else begin
		case (cl_state)
			CL_IDLE: begin
				if(~old_ioctl_download && ioctl_download) begin
					tape_cas_downloading <= 1'b1;
					ioctl_wait <= 1'b1;						//Pause downloading
					tape_ram_addr <= 17'h00000;         //Reset Tape Ram address to x000000
					tape_ram_din <= 8'hAA;
					system_tape_found <= 1'b0;          //Reset Flag;
					basic_tape_found <= 1'b0;
					data_tape_found <= 1'b0;
					system_tape_filename <= 48'd0;      //Clear out System File Name
					cl_state <= CL_CREATE_HEADER;
				end
			end
			CL_CREATE_HEADER: begin
				if(tape_ram_addr < 17'h00100) begin
					if(tape_ram_wr && old_ram_wr) begin
						tape_ram_wr <= 1'b0;
					end
					if(~tape_ram_wr && old_ram_wr) tape_ram_addr <= tape_ram_addr + 1'b1;
					else if(~tape_ram_wr && ~old_ram_wr) tape_ram_wr <= 1'b1;
				end
				else begin
					cl_state <= CL_FIND_BOT;
					tape_ram_wr <= 1'b0;
				end
			end
			CL_FIND_BOT: begin
			   ioctl_wait <= 1'b0;                    //Resume Downloading
				if(ioctl_dout == 8'h66) begin
					bot_marker_pos <= ioctl_addr[16:0];
					ioctl_wait <= 1'b1;
					tape_ram_din   <= 8'h66;
					tape_ram_wr    <= 1'b1;
				end
				if(ioctl_wait && tape_ram_din == 8'h66 && tape_ram_wr && old_ram_wr) begin
					cl_state       <= CL_LOAD_TAPE;
					tape_ram_wr    <= 1'b0;
				end
			end
			CL_LOAD_TAPE: begin
				ioctl_wait <= 1'b0;
				if(ioctl_addr[16:0] == (bot_marker_pos + 1'b1)) begin
					if(ioctl_dout == 8'h55) system_tape_found <= 1'b1;
					else if(ioctl_dout > 8'h19 && ioctl_dout < 8'h7B) basic_tape_found <= 1'b1;
					else data_tape_found <= 1'b1;
				end
				//If this is a System tape, capture the 6 byte filename
				if(system_tape_found && ioctl_addr[16:0] < (bot_marker_pos + 17'd8) && ioctl_addr[16:0] != old_ioctl_addr) system_tape_filename <= (system_tape_filename << 8) + ioctl_dout;
				if(ioctl_download && ioctl_wr) begin
					tape_ram_addr <= tape_ram_addr + 1'b1;
					tape_ram_din <= ioctl_dout;
					tape_ram_wr <= ioctl_wr;
				end
				else tape_ram_wr <= 1'b0;
				if(~ioctl_download) begin
					tape_length <= tape_ram_addr + 1'b1;
					cl_state <= CL_WRITE_EOT;
				end
			end
			CL_WRITE_EOT: begin					      //Write 3 bytes of 00s at end of tape data incase the CAS file
				tape_ram_din <= 8'h00;					//with basic data doesn't have them, which will cause CLOAD to hang.
				if(tape_ram_addr <= tape_length + 17'd3) begin
					if(~tape_ram_wr) begin
						tape_ram_addr <= tape_ram_addr + 1'b1;
						tape_ram_wr <= 1'b1;
					end
					else if(old_ram_wr && tape_ram_wr) tape_ram_wr <= 1'b0;
				end
				else begin
					tape_length <= tape_ram_addr + 1'b1;
					tape_ram_wr <= 1'b0;
					tape_cas_downloading <= 1'b0;
					//If this is a System Tape, check the first byte of the Filename, if not a valid character, change type to Basic
					if(system_tape_found && (system_tape_filename[47:40] < 8'h21 || system_tape_filename[47:40] > 8'h7A)) begin
						system_tape_found <= 1'b0;
						basic_tape_found <= 1'b1;
						system_tape_filename <= 48'd0;
					end
					cl_state <= CL_IDLE;
				end
			end
		endcase
	end
end

reg [15:0] tape_div;

always @(posedge clk) begin
	if(reset && (eject && ~tape_playing)) begin
		tape_div <= 16'h0000;
		tape <= 1'b0;
	end
	else if(tape_loaded && tape_playing && io_ram_addr != tape_length) begin
		if(tape_div == CPP) begin
			tape_div <= 16'h0000;
			tape <= ~tape;
		end
		else if(tape_div == CPP/2) begin
			if(tape_byte[tape_byte_ptr]) tape <= ~tape;
			tape_div <= tape_div + 1'b1;
		end
	   else tape_div <= tape_div + 1'b1;
	end
end

always @(posedge clk) begin
	if(reset || ioctl_download || rewind || (eject && ~tape_playing)) begin
		io_ram_addr <= 17'h000000;  //On reset or tape load, start at beginning of Tape Ram
		tape_byte_ptr <= 3'd7;
		eot <= 1'b0;
	end
	else if(tape_loaded && tape_playing && io_ram_addr != tape_length && tape_div == ((CPP / 2) + 1)) begin
		if(tape_byte_ptr == 3'd0) begin
			tape_byte_ptr <= 3'd7;
			io_ram_addr <= io_ram_addr + 1'b1;
		end
		else tape_byte_ptr <= tape_byte_ptr - 1'b1;
	end
	if(io_ram_addr == tape_length) eot <= 1'b1;
	else eot <= 1'b0;
end


reg  [7:0] tape_byte;
reg  [2:0] tape_byte_ptr;
reg [15:0] tape_size;
wire       tape_loaded;

assign tape_loaded = |tape_length;


always @(posedge clk) begin
	if(reset || ioctl_download) begin
	end
	else begin
		if(tape_loaded && tape_playing && io_ram_addr != (tape_length + 1'b1)) begin
			if(tape_byte_ptr == 3'd7) begin  //Byte pointer at 0, read byte in from tape ram
				tape_byte <= ram_dout;
			end
		end
		else tape_byte <= 8'd0;
	end
end

reg old_play;
always @(posedge clk) begin
	old_play <= play;
	if(~old_play && play && tape_loaded) tape_playing <= ~tape_playing;
	if(io_ram_addr == tape_length) tape_playing <= 1'b0;
end

reg old_eject;
always @(posedge clk) begin
	old_eject <= eject;
	if(~old_eject && eject && ~tape_playing) erase_tape_ram <= 1'b1;
	if(erase_tape_ram && done_erasing_ram) erase_tape_ram <= 1'b0;
end

reg erase_tape_ram;
reg done_erasing_ram;
reg [16:0] erase_addr;
reg erase_wr;
reg erasing;
always @(posedge clk) begin
	erasing <= erase_tape_ram;
	erase_wr <= 1'b0;
	if(~erasing && erase_tape_ram) begin
		erase_addr <= 17'h00000;
		done_erasing_ram <= 1'b0;
	end
	if(erasing && erase_addr <= tape_length) erase_wr <= 1'b1;
	if(erasing && erase_wr) begin
		if(erase_addr != tape_length) begin
			erase_addr <= erase_addr + 1'b1;
			erase_wr <= 1'b0;
		end
		else if(erase_addr == tape_length) begin
			erase_wr <= 1'b0;
			done_erasing_ram <= 1'b1;
			erasing <= 1'b0;
		end
	end
	if(~erase_tape_ram && done_erasing_ram) done_erasing_ram <= 1'b0;
end


wire [9:0] tape_pos;
assign tape_pos = io_ram_addr / 10'd150;
assign status = {tape_pos,eot && tape_loaded,tape_playing,tape_loaded};

endmodule

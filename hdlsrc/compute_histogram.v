// synthesis translate_off
`timescale 1ns / 1ps
// synthesis translate_on

module compute_histogram
#(	
	parameter ADDR_WIDTH = 9,
	parameter DATA_WIDTH = 16
)
(
	//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	/////////////////////////////////////////////// 	Clocks & Reset	 		//////////////////////////////////////////
	//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	input 							clk,
	input 							reset,
	output wire 					bram_reset_done,
	//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	////////////////////////// Handshake Signals with Pulse Width Counter (PWC) //////////////////////////////////////////
	//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	input 		[DATA_WIDTH-1:0] 	data_packet_from_PWC,
	//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	/////////////////////////////////////////////// Handshake Signals with FIFO //////////////////////////////////////////
	//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	output reg 						rdreq_to_FIFO,
	input 							rdempty_from_FIFO,
	//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	/////////////////////////////////////////////// Handshake Signals with PC 	//////////////////////////////////////////
	//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	input							clear_from_pc,
	input 		[ADDR_WIDTH-1:0]	bin_address_from_pc,
	output wire [DATA_WIDTH-1:0]	data_to_pc
);

/*
	This module does 2 things:
	(1) find_the_bin: Computes the correct bin address to update corresponding to:
		(a) The current channel
		(b) The current value to be added to the histogram
	(2) update_the_bin: Fetches the current bin value and increments by 1.
*/

// BRAM interface
wire [ADDR_WIDTH-1:0] 	bram_address;
reg						bram_write_read;
wire [DATA_WIDTH-1:0] 	bram_read_data;
wire [DATA_WIDTH-1:0]	bram_write_data;

/////////////////////////////////////////////////////////////////////////////////////////////////////////////
// State machine to process the PWC values:
localparam RESET_BRAM 			= 2'd0;
localparam READ_FROM_FIFO 		= 2'd1;
localparam SET_BRAM_RDCNTRLS 	= 2'd2;
localparam WRITE_BRAM_WDATA 	= 2'd3;

localparam WAIT_NUM_CLOCKS_FIFO_RD = 3'd3;

reg [1:0] update_bin_state;
reg [ADDR_WIDTH:0] reset_addr_to_bram;
reg	reset_done_to_PWC;
reg [2:0] counter_wait_for_fifo_rddata;

assign bram_reset_done = reset_done_to_PWC;

// STATE MACHINE LOGIC
always @(posedge clk)
begin
	if(reset)
	begin
		update_bin_state 	  <= RESET_BRAM;
		rdreq_to_FIFO 		  <= 1'b0;
		bram_write_read		  <= 1'b0;
		reset_addr_to_bram	  <=  'd0;
		reset_done_to_PWC	  <= 1'b0;
		counter_wait_for_fifo_rddata	<= 'd0;
	end
	else
		case(update_bin_state)
			RESET_BRAM			: 	begin
										counter_wait_for_fifo_rddata <= 'd0;
										if(reset_addr_to_bram == 'd512)
										begin
											update_bin_state 	<= READ_FROM_FIFO;
											reset_addr_to_bram	<= 'd0;
											reset_done_to_PWC	<= 1'b1;
											bram_write_read		<= 1'b0;
										end
										else
										begin
											bram_write_read		<= 1'b1;
											reset_addr_to_bram 	<= reset_addr_to_bram + 1;
											update_bin_state	<= RESET_BRAM;
										end
									end
			READ_FROM_FIFO		:	begin
										bram_write_read		  <= 1'b0;
										reset_addr_to_bram	  <= 'd0;
										reset_done_to_PWC	  <= reset_done_to_PWC;
										counter_wait_for_fifo_rddata <= 'd0;
										if(clear_from_pc == 1'b1)
										begin
											update_bin_state <= RESET_BRAM;
											rdreq_to_FIFO    <= 1'b0;
										end
										else if(!rdempty_from_FIFO) 
										begin
											update_bin_state <= SET_BRAM_RDCNTRLS;
											rdreq_to_FIFO <= 1'b1;
										end
										else begin
											update_bin_state <= READ_FROM_FIFO;
											rdreq_to_FIFO <= 1'b0;
										end
									end
			SET_BRAM_RDCNTRLS	:	begin
										reset_addr_to_bram    <=  'd0;
										rdreq_to_FIFO         <= 1'b0;
										bram_write_read		  <= 1'b0;
										reset_done_to_PWC	  <= reset_done_to_PWC;
										if(clear_from_pc == 1'b1)
										begin
											update_bin_state <= RESET_BRAM;
											counter_wait_for_fifo_rddata <= 'd0;
										end
										else if(counter_wait_for_fifo_rddata < WAIT_NUM_CLOCKS_FIFO_RD)
										begin
											// for sync purposes, the FIFO has 3 stage synchronizer on the read side. So, wait for 3 clocks before sampling the data
											counter_wait_for_fifo_rddata <= counter_wait_for_fifo_rddata + 1'b1;
											update_bin_state <= SET_BRAM_RDCNTRLS;
										end
										else
										begin
											counter_wait_for_fifo_rddata <= 'd0;
											update_bin_state <= WRITE_BRAM_WDATA;
										end
									end
			WRITE_BRAM_WDATA	:	begin
										reset_addr_to_bram	  <= 'd0;
										rdreq_to_FIFO 		  <= 1'b0;
										bram_write_read		  <= 1'b1;
										reset_done_to_PWC	  <= reset_done_to_PWC;
										if(clear_from_pc == 1'b1)
											update_bin_state <= RESET_BRAM;
										else
											update_bin_state <= READ_FROM_FIFO;
									end
		endcase
end

// Controls to BRAM
assign bram_address    = (update_bin_state == RESET_BRAM) ? reset_addr_to_bram[8:0] 	: data_packet_from_PWC[8:0];
assign bram_write_data = (update_bin_state == RESET_BRAM) ? 'd0  						: bram_read_data + 1; // data_from_bin_address

bram_onchip_memory RAM_MODULE(
	.clock(clk),
	.enable(1'b1),
	.aclr(reset),
	.address_a(bram_address),
	.wren_a(bram_write_read),
	.rden_a(!bram_write_read),
	.data_a(bram_write_data),
	.q_a(bram_read_data),

	.address_b(bin_address_from_pc),
	.wren_b(1'b0),
	.rden_b(1'b1),
	.data_b(16'd0),
	.q_b(data_to_pc)
);

endmodule
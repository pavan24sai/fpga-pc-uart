module UART_CONTROLLER
#(
	parameter UART_CLKS_PER_BIT  = 1085,
	parameter HIST_BIN_DATAWIDTH = 16
)
(
	input 								clk,
	input 								reset,
	input								bram_reset_done,
	//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	////////////////////////////////// 		Handshake Signals with PC 		//////////////////////////////////////////////
	//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	input 								UART_RX_FROM_PC,
	output wire 						UART_TX_TO_PC,
	//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	////////////////////////////////// Handshake Signals with hist_system  ///////////////////////////////////////////////
	//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	input [HIST_BIN_DATAWIDTH-1:0] 		histogram_bin_data,
	output wire 						start_sig_to_hist,	// NEED TO DRIVE AT HIGHER CLOCK
	output wire							stop_sig_to_hist,	// NEED TO DRIVE AT HIGHER CLOCK
	output wire							clear_sig_to_hist,
	output wire [8:0] 					address_to_hist
);

/*
	This module receives UART command from the PC to read the histogram contents from the FPGA through UART interface.
	This module contains:
	->	UART RX 	  - To receive UART commands from the PC
	->	UART TX 	  - To send data on UART interface
	->	State Machine - Controls when to send the data to the UART interface, select the data to send. etc.,
*/

/*
	This is how the UART communication works.
	-> FPGA receives any of the following commands from the PC:
		->	START_UPLOAD : Indicates the bin address from which FPGA needs to send data to the PC.
		->	SET_BINADDR	 : Address to start the capture from. [DEFAULT: 0000_0000]
		-> 	SET_NUMBINS	 : Number of bins to capture from the FPGA. [DEFAULT: FULL HISTOGRAM SIZE]
		->	STOP_HIST    : Stops the FPGA from performing the histogram binning operation.
		->	CLEAR_RESULTS: Resets the FPGA histogram memory & starts the histogram operation over again.
		-> 	END_COMMAND	 : Informs FPGA that PC is done with sending all the necessary commands to the FPGA. When PC sends any of the above commands, the command sequence should end with an END_COMMAND

	=========================================
	| 	COMMAND_TYPE	|	COMMAND_BITS	|
	=========================================
	|	END_COMMAND		|	0000_0000		|
	|	START_HIST		|	0000_0010		|
	|	STOP_HIST		|	0000_0011		|
	|	CLEAR_RESULTS	|	0000_0100		|
	|	START_UPLOAD	|	0000_0101 		|
	|	SET_BINADDR		|	0000_0110		|
	/	SET_NUMBINS		|	0000_0111		|
	=========================================
*/

wire 								uart_rx_done, uart_tx_done, uart_tx_active;
wire	[7:0] 						uart_rx_byte;
reg 								uart_start_tx;
reg 	[7:0] 						uart_tx_byte;

reg 	[3:0] 						uart_ctrl_state, from_state_to_end_cmd, uart_tx_state;	// State Machine To Handle COMMAND Detection
reg 	[HIST_BIN_DATAWIDTH-1:0] 	data_to_transfer;
reg 								wait_cmd_state_attained;

reg 	[9:0] 						no_of_bins_to_read;
reg		[8:0]						current_bin_num;
wire 	[8:0] 						no_of_bins_to_read_minus_one;
reg 	[8:0] 						base_address_to_hist;

reg 	[4:0] 						byte_counter;
wire 	[4:0] 						byte_counter_start_value, expected_final_byte_count_val;
reg 	[7:0] 						byte_setting_lsb;

// Command Definitions
localparam CMD_END_COMMAND   	= 8'b11111111;
localparam CMD_START_HIST    	= 8'd2;
localparam CMD_STOP_HIST     	= 8'd3;
localparam CMD_CLEAR_RESULTS 	= 8'd4;
localparam CMD_START_UPLOAD  	= 8'd5;
localparam CMD_SET_BINADDR   	= 8'd6;
localparam CMD_SET_NUMBINS   	= 8'd7;

// State Machine - States [UART COMMAND DECODE]
localparam S0_CMD_CHECK  		= 4'd0;
localparam S1_START_HIST		= 4'd1;
localparam S2_STOP_HIST     	= 4'd2;
localparam S3_CLEAR_RESULTS 	= 4'd3;
localparam S4_START_UPLOAD  	= 4'd4;
localparam S5_SET_START_ADDR    = 4'd5;
localparam S6_SET_NUMBINS   	= 4'd6;
localparam S7_STR_PC_SETTING1 	= 4'd7;
localparam S8_STR_PC_SETTING2	= 4'd8;
localparam S9_WAIT_END_CMD		= 4'd9;

// State Machine - States [UART TRANSMIT]
localparam X0_IDLE				= 4'd0;
localparam X1_TX_END_CMD		= 4'd1;
localparam X2_TX_END_CMD_DONE 	= 4'd2;
localparam X3_TX_ACK_SET		= 4'd3;
localparam X4_HIST_ADDR			= 4'd4;
localparam X5_REGISTER_DATA		= 4'd5;
localparam X6_WAIT_FOR_CLRDONE  = 4'd6;
localparam X7_SEND_BYTE 		= 4'd7;
localparam X8_BYTE_DONE			= 4'd8;

// Other constants
localparam READ_ALL_BINS_SETTING = 10'd512;

// UART TRANSMIT MODULE
UART_TX
#(
	.CLKS_PER_BIT(UART_CLKS_PER_BIT)
)
tx_module
(
	.i_Rst(reset),
    .i_Clock(clk),
    .i_TX_DV(uart_start_tx),
    .i_TX_Byte(uart_tx_byte),
    .o_TX_Active(uart_tx_active),
    .o_TX_Serial(UART_TX_TO_PC),
    .o_TX_Done(uart_tx_done)
);

// UART RECEIVE MODULE
UART_RX
#(
	.CLKS_PER_BIT(UART_CLKS_PER_BIT)
)
rx_module
(
	.i_Clock(clk),
	.i_RX_Serial(UART_RX_FROM_PC),
	.o_RX_DV(uart_rx_done),
	.o_RX_Byte(uart_rx_byte)
);

// State Machine - To Decode UART Commands
always @(posedge clk or posedge reset) 
begin
    if (reset) 
	begin
        uart_ctrl_state			<= S0_CMD_CHECK;
		from_state_to_end_cmd	<= S0_CMD_CHECK;
		wait_cmd_state_attained	<= 1'b0;
		no_of_bins_to_read		<= READ_ALL_BINS_SETTING;
		base_address_to_hist 	<= 'd0;
		byte_setting_lsb		<= 'd0;
    end 
	else 
	begin
		case(uart_ctrl_state)
		S0_CMD_CHECK	:		begin
									wait_cmd_state_attained <= 1'b0;
									from_state_to_end_cmd   <= from_state_to_end_cmd;
									if(uart_rx_done)
										case(uart_rx_byte)
										CMD_CLEAR_RESULTS	:	uart_ctrl_state	<= S3_CLEAR_RESULTS;
										CMD_SET_NUMBINS		:	uart_ctrl_state	<= S6_SET_NUMBINS;
										CMD_SET_BINADDR		:	uart_ctrl_state	<= S5_SET_START_ADDR;
										CMD_START_UPLOAD	:	uart_ctrl_state	<= S4_START_UPLOAD;
										CMD_START_HIST		:	uart_ctrl_state <= S1_START_HIST;
										CMD_STOP_HIST		:	uart_ctrl_state	<= S2_STOP_HIST;
										default				:	uart_ctrl_state	<= S0_CMD_CHECK;
										endcase
									else
										uart_ctrl_state	<= S0_CMD_CHECK;
								end
		S1_START_HIST	:		begin
									uart_ctrl_state	<= S9_WAIT_END_CMD;
									from_state_to_end_cmd <= S1_START_HIST;
								end
		S2_STOP_HIST	:		begin
									uart_ctrl_state	<= S9_WAIT_END_CMD;
									from_state_to_end_cmd <= S2_STOP_HIST;
								end
		S3_CLEAR_RESULTS:		begin
									uart_ctrl_state	<= S9_WAIT_END_CMD;
									from_state_to_end_cmd <= S3_CLEAR_RESULTS;
								end
		S4_START_UPLOAD:		begin
									uart_ctrl_state	<= S9_WAIT_END_CMD;
									from_state_to_end_cmd <= S4_START_UPLOAD;
								end
		S5_SET_START_ADDR:		begin
									uart_ctrl_state	<= S7_STR_PC_SETTING1;
									from_state_to_end_cmd <= S5_SET_START_ADDR;
								end
		S6_SET_NUMBINS	:		begin
									uart_ctrl_state	<= S7_STR_PC_SETTING1;
									from_state_to_end_cmd <= S6_SET_NUMBINS;
								end
		S7_STR_PC_SETTING1:		begin
									from_state_to_end_cmd   <= from_state_to_end_cmd;
									wait_cmd_state_attained <= wait_cmd_state_attained;
									if(uart_rx_done)
									begin
										byte_setting_lsb <= uart_rx_byte;
										uart_ctrl_state	<= S8_STR_PC_SETTING2;
									end
									else
										uart_ctrl_state	<= S7_STR_PC_SETTING1;
								end
		S8_STR_PC_SETTING2:	begin
									from_state_to_end_cmd   <= from_state_to_end_cmd;
									wait_cmd_state_attained <= wait_cmd_state_attained;
									if(uart_rx_done)
									begin
										uart_ctrl_state	<= S9_WAIT_END_CMD;
										case(from_state_to_end_cmd)
										S5_SET_START_ADDR	:	begin
																	// scenario where the {current_byte, byte_setting_lsb} exceeds NUM_BINS limit
																	if(uart_rx_byte	> 'd1)
																		base_address_to_hist <= 'd511;
																	else
																		base_address_to_hist <= {uart_rx_byte[0], byte_setting_lsb};
																end
										S6_SET_NUMBINS		:	begin
																	// scenario where the {current_byte, byte_setting_lsb} exceeds NUM_BINS limit
																	if(uart_rx_byte	> 8'b00000010)
																		no_of_bins_to_read <= READ_ALL_BINS_SETTING;
																	else
																		no_of_bins_to_read <= {uart_rx_byte[1:0], byte_setting_lsb};
																end
										default				:	begin
																	base_address_to_hist <= base_address_to_hist;
																	no_of_bins_to_read   <= no_of_bins_to_read;
																end
										endcase
									end
									else
										uart_ctrl_state	<= S8_STR_PC_SETTING2;
								end
		S9_WAIT_END_CMD	:	begin
									from_state_to_end_cmd   <= from_state_to_end_cmd;
									if(uart_rx_done)
									begin
										case(uart_rx_byte)
										CMD_END_COMMAND		:	begin
																	uart_ctrl_state	<= S0_CMD_CHECK;
																	wait_cmd_state_attained <= 1'b1;
																end
										default				:	begin
																	uart_ctrl_state	<= S9_WAIT_END_CMD;
																	wait_cmd_state_attained <= 1'b0;
																end
										endcase
									end
									else
									begin
										uart_ctrl_state	<= S9_WAIT_END_CMD;
										wait_cmd_state_attained <= 1'b0;
									end
								end
		default			:		begin
									uart_ctrl_state	<= S0_CMD_CHECK;
									from_state_to_end_cmd   <= S0_CMD_CHECK;
								end
		endcase
    end
end

assign clear_sig_to_hist 	= (from_state_to_end_cmd == S3_CLEAR_RESULTS && wait_cmd_state_attained) 	? 1'b1 : 1'b0;
assign stop_sig_to_hist  	= (from_state_to_end_cmd == S2_STOP_HIST && wait_cmd_state_attained) 	 	? 1'b1 : 1'b0;
assign start_sig_to_hist  	= (from_state_to_end_cmd == S1_START_HIST && wait_cmd_state_attained)		? 1'b1 : 1'b0;

// State Machine - For UART TX to PC
always @(posedge clk or posedge reset)
begin
    if (reset)
	begin
		uart_tx_state 			<= X0_IDLE;
		uart_tx_byte  			<= 'd0;
		current_bin_num 		<= 'd0;
		uart_start_tx 			<= 1'b0;
		byte_counter			<= 'd0;
	end
	else
	begin
		case(uart_tx_state)
		X0_IDLE				: 	begin
									uart_start_tx <= 1'b0;
									if(wait_cmd_state_attained == 1'b1)
									begin
										if(from_state_to_end_cmd == S4_START_UPLOAD)
											uart_tx_state <= X4_HIST_ADDR;
										else if(from_state_to_end_cmd == S3_CLEAR_RESULTS)
											uart_tx_state <= X6_WAIT_FOR_CLRDONE;
										else if(from_state_to_end_cmd == S1_START_HIST 	||
											from_state_to_end_cmd == S2_STOP_HIST 		||
											from_state_to_end_cmd == S5_SET_START_ADDR	||
											from_state_to_end_cmd == S6_SET_NUMBINS)
											uart_tx_state <= X3_TX_ACK_SET;
										else
											uart_tx_state <= X0_IDLE;
									end
									else
										uart_tx_state <= X0_IDLE;
								end
		X1_TX_END_CMD		:	begin
									uart_start_tx <= 1'b1;
									uart_tx_byte  <= CMD_END_COMMAND;
									uart_tx_state <= X2_TX_END_CMD_DONE;
								end
		X2_TX_END_CMD_DONE	:	begin
									uart_start_tx <= 1'b0;
									if(uart_tx_done == 1'b1)
										uart_tx_state <= X0_IDLE;
									else
										uart_tx_state <= X2_TX_END_CMD_DONE;
								end
		X3_TX_ACK_SET		:	begin
									uart_tx_state <= X1_TX_END_CMD;
									uart_start_tx <= 1'b0;
								end
		X4_HIST_ADDR		:	begin
									// tranmsits the address to read from to the histogram module
									uart_tx_state   <= X5_REGISTER_DATA;
									byte_counter    <= byte_counter_start_value;
								end
		X5_REGISTER_DATA	:	begin
									data_to_transfer 	<= histogram_bin_data;
									uart_tx_state		<= X7_SEND_BYTE;
								end
		X6_WAIT_FOR_CLRDONE:	begin
									if(bram_reset_done)
										uart_tx_state <= X1_TX_END_CMD;
									else
										uart_tx_state <= X6_WAIT_FOR_CLRDONE;
								end
		X7_SEND_BYTE		:	begin
									uart_start_tx		<= 	1'b1;
									case (byte_counter)
										5'd0 : uart_tx_byte <= data_to_transfer[7:0];
										5'd1 : uart_tx_byte <= data_to_transfer[15:8];
									endcase
									uart_tx_state <= X8_BYTE_DONE;
								end
		X8_BYTE_DONE		:	begin
									uart_start_tx <= 1'b0;
									if(uart_tx_done == 1'b1)
									begin
										if(byte_counter != expected_final_byte_count_val)
										begin
											/// CHECK-1 : If the current bin of the current channel is transferred
											// ALSO GOOD TIME TO INCREMENT THE byte_counter IF AT ALL THERE ARE SOME UNTRANSFERRED BYTES
											uart_tx_state <= X7_SEND_BYTE;
											byte_counter  <= byte_counter + 1;
										end
										else if(current_bin_num < no_of_bins_to_read_minus_one)
										begin
											/// CHECK-2 : If all the bins of the histogram are transferred
											// ALSO GOOD TIME TO INCREMENT THE ADDRESS IF AT ALL THERE ARE MORE REQUESTED BINS
											uart_tx_state	<= X4_HIST_ADDR;
											current_bin_num <= current_bin_num + 1;
											byte_counter	<= byte_counter;
										end
										else
										begin
											// This is hit when:
											// (1) Both the bytes of a given bin are transferred.
											// (2) All the bins in the histogram are transferred.
											// Now, send an end command
											current_bin_num <= 'd0;
											uart_tx_state   <= X1_TX_END_CMD;
											byte_counter	<= byte_counter;
										end
									end
									else
										uart_tx_state	<=	X8_BYTE_DONE;
								end
		default				:	uart_tx_state <= X0_IDLE;
		endcase
	end
end

assign address_to_hist = base_address_to_hist + current_bin_num;
assign no_of_bins_to_read_minus_one = no_of_bins_to_read - 1'b1;

// Logic to deal with finding whether transfer of all the required bins is done
assign byte_counter_start_value      = 5'd0;
assign expected_final_byte_count_val = 5'd1;

endmodule
// synthesis translate_off
`timescale 1ns / 1ps
// synthesis translate_on
module hist_system
#(
	parameter ADDR_WIDTH 		= 9,
	parameter DATA_WIDTH 		= 16,
	parameter UART_CLKS_PER_BIT = 435, // 50 MHz/ 115200
	parameter NUM_PULSES 		= 1500 ////////////////// WHILE SYNTHESIZING ENSURE THAT THIS SETTING IS SAME AS THAT CONFIGURED IN THE TB FOR TESTING /////////////////////
)
(
	//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	////////////////////////////////// 			Clocks & Reset			   ///////////////////////////////////////////////
	//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	input 				clk,
	input 				areset_n,
	output wire			clk_slowest,
	output wire 		clk_fastest,
	//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	////////////////////////////////// 	  UART Interface with the PC       ///////////////////////////////////////////////
	//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	input  				UART_RX_FROM_PC,
	output wire 		UART_TX_TO_PC,
	//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	//////////////////////////////////        Connect to LEDs for Status      ////////////////////////////////////////////
	//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	output wire 		pulse_out,
	output wire 		done_out
);

wire clk_Histogram, clk_PWC, reset, ready_to_capture;
wire pulse_in;
wire start, stop;

wire [ADDR_WIDTH-1:0] 	bram_address;
wire					bram_write_read;
wire [DATA_WIDTH-1:0] 	bram_read_data;
wire [DATA_WIDTH-1:0]	bram_write_data;

wire rdreq_from_histogram, wrreq_from_PWC, reset_done;
wire [DATA_WIDTH-1:0] count_val_ch0;
wire reset_to_pulse_gen;

wire [DATA_WIDTH-1:0] histogram_data;
wire start_sig_received_from_pc;
wire [ADDR_WIDTH-1:0] bin_address_from_pc;

// UART system //
hist_uart_system 
#(
	.ADDR_WIDTH(ADDR_WIDTH),
	.DATA_WIDTH(DATA_WIDTH),
	.UART_CLKS_PER_BIT(UART_CLKS_PER_BIT)
)
SYS
(
	.clk(clk),
	.areset_n(areset_n),
	.clk_fastest(clk_PWC),
	.clk_slowest(clk_Histogram),
	.reset_out(reset),
	
	.pulse_in(pulse_in),
	
	.UART_RX_FROM_PC(UART_RX_FROM_PC),
	.UART_TX_TO_PC(UART_TX_TO_PC),
	.histogram_data(histogram_data),
	
	.start_pulse_generator(start),
	.stop_pulse_generator(stop),
	.bram_reset_done(reset_done)
);

// Pulse Input to the PWC
pulse_gen_top 
#(
	.NUM_BITS(9),
	.NUM_PULSES(NUM_PULSES)
)
pwm_module
(
	.clk(clk_PWC),
	.reset(reset_to_pulse_gen),
	.start(start),
	.stop(stop),
	.pulse_out(pulse_out),
	.done_out(done_out)
);

assign pulse_in 			= pulse_out;
assign clk_fastest	 		= clk_PWC;
assign clk_slowest   		= clk_Histogram;
assign reset_to_pulse_gen 	= reset || (!reset_done);

endmodule
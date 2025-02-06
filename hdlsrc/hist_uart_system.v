// synthesis translate_off
`timescale 1ns / 1ps
// synthesis translate_on
module hist_uart_system
#(
	parameter ADDR_WIDTH 		= 9,
	parameter DATA_WIDTH 		= 16,
	parameter UART_CLKS_PER_BIT = 435
)
(
	//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	////////////////////////////////// 			Clocks & Reset			   ///////////////////////////////////////////////
	//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	input 										clk,
	input 										areset_n,
	output wire									clk_fastest,
	output wire									clk_slowest,
	output wire									reset_out,
	//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	////////////////////////////////// Handshake Signals with Pulse Generator ////////////////////////////////////////////
	//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	input       				 			 	pulse_in,
	//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	////////////////////////////////// 	  Interface with UART controller   ///////////////////////////////////////////////
	//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	input										UART_RX_FROM_PC,
	output wire									UART_TX_TO_PC,
	output wire [DATA_WIDTH-1:0] 				histogram_data,
	//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	////////////////////////////////// 	  Interface with Pulse Generator   ///////////////////////////////////////////////
	//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	output wire 								start_pulse_generator,
	output wire									stop_pulse_generator,
	output wire									bram_reset_done
);

wire clk_Histogram, clk_PWC, reset;
wire fifo_empty_to_histogram, fifo_full_to_PWC;

/// Control signals from UART controller
wire start_signal_from_pc, start_signal_from_pc_sync;
wire stop_signal_from_pc, stop_signal_from_pc_sync;
wire clear_signal_from_pc;
wire [ADDR_WIDTH-1:0] bin_address_from_pc;

assign clk_fastest = clk_PWC;			// 250 MHz
assign clk_slowest = clk_Histogram; 	// 50 MHz
assign reset_out   = reset;

// CLK, RESET, PLL:
clk_reset_module CLK_RST_MODULE(
	.p_clk(clk),
	.p_reset_n(areset_n),
	.clk_fast(clk_PWC),
	.clk(clk_Histogram),
	.reset(reset)
);

// I/O
wire [DATA_WIDTH-1:0] data_from_PWC;
wire [DATA_WIDTH-1:0] FIFO_out;
wire [DATA_WIDTH-1:0] data_from_hist;

// PULSE_WIDTH CALCULATE MODULE
pulse_width_calculate PWC_LOGIC(
	.clk(clk_PWC),
	.reset(reset),
	.reset_done_from_hist(reset_done_to_hist_module),
	.pulse_sig_in(pulse_in), 
	.data_to_compute_histogram(data_from_PWC),
	.wrreq_to_FIFO(wrreq_from_PWC),
	.wrfull_from_FIFO(fifo_full_to_PWC),
	.start_from_pc(start_signal_from_pc_sync),
	.stop_from_pc(stop_signal_from_pc_sync)
);

// FIFO
fifo_module FIFO_BLOCK(
	.aclr(reset),
	.data(data_from_PWC),
	.rdclk(clk_Histogram),
	.rdreq(rdreq_from_histogram),
	.wrclk(clk_PWC),
	.wrreq(wrreq_from_PWC),
	.q(FIFO_out),
	.wrfull(fifo_full_to_PWC),		
	.rdempty(fifo_empty_to_histogram)
);

// HISTOGRAM MODULE
compute_histogram HIST_MODULE(
	.clk(clk_Histogram),
	.reset(reset),
	.bram_reset_done(reset_done_to_hist_module),
	.data_packet_from_PWC(FIFO_out),
	.rdreq_to_FIFO(rdreq_from_histogram),
	.rdempty_from_FIFO(fifo_empty_to_histogram),
	.clear_from_pc(clear_signal_from_pc),
	.bin_address_from_pc(bin_address_from_pc),
	.data_to_pc(data_from_hist)
);

/// UART CONTROLLER ///
UART_CONTROLLER 
#(
	.UART_CLKS_PER_BIT(UART_CLKS_PER_BIT)
)
ctrl_blk(
	.clk(clk_Histogram),
	.reset(reset),
	.bram_reset_done(reset_done_to_hist_module),
	.UART_RX_FROM_PC(UART_RX_FROM_PC),
	.UART_TX_TO_PC(UART_TX_TO_PC),
	.histogram_bin_data(data_from_hist),
	.start_sig_to_hist(start_signal_from_pc),
	.stop_sig_to_hist(stop_signal_from_pc),
	.clear_sig_to_hist(clear_signal_from_pc),
	.address_to_hist(bin_address_from_pc)
);

synchronizer SYNC_1(
    .clk(clk_PWC),
    .reset(reset),
    .sig_in(start_signal_from_pc),
    .sig_sync_out(start_signal_from_pc_sync)
);

synchronizer SYNC_2(
    .clk(clk_PWC),
    .reset(reset),
    .sig_in(stop_signal_from_pc),
    .sig_sync_out(stop_signal_from_pc_sync)
);

assign start_pulse_generator = start_signal_from_pc_sync;
assign stop_pulse_generator  = stop_signal_from_pc_sync;
assign histogram_data 		 = data_from_hist;
assign bram_reset_done		 = reset_done_to_hist_module;
endmodule
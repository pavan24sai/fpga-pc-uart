module pulse_width_calculate
#(
	parameter DATA_WIDTH = 16
)
(
	input 							clk,
	input 							reset,
	input 							reset_done_from_hist,
	//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	////////////////////////////////// Handshake Signals with Pulse Generator ////////////////////////////////////////////
	//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	input 							pulse_sig_in,
	//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	////////////////////////////////// Handshake Signals with compute_histogram //////////////////////////////////////////
	//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	output reg [DATA_WIDTH-1:0] 	data_to_compute_histogram,
	//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	/////////////////////////////////////////////// Handshake Signals with FIFO //////////////////////////////////////////
	//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	output reg	 					wrreq_to_FIFO,
	input 							wrfull_from_FIFO,
	//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	/////////////////////////////////////////////// Handshake Signals with pc  //////////////////////////////////////////
	//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	input							start_from_pc,
	input							stop_from_pc
);

// counter interface signals
wire reset_counter, count_enable;
wire [DATA_WIDTH-1:0] count_val;

// sample inputs from pulse generator
reg sampled_input_to_consider, start_PWC, stop_PWC;

// state machine states to process the pulses from analog board
localparam WAIT_FOR_HIST_RESET_DONE = 2'd0;
localparam WAIT_FOR_START_PWC       = 2'd1;
localparam WAIT_FOR_HIGH_PULSE 		= 2'd2;
localparam WAIT_FOR_LOW_PULSE  		= 2'd3;

reg [1:0] pulse_counter_state; // STORE_COUNT

// Register the inputs
always @(posedge clk)
begin
	if(reset)
	begin
		start_PWC <= 1'b0;
		stop_PWC  <= 1'b0;
		sampled_input_to_consider <= 1'b0;
	end
	else
	begin
		start_PWC <= start_from_pc;
		stop_PWC  <= stop_from_pc;
		sampled_input_to_consider <= pulse_sig_in;
	end
end

// STATE MACHINE LOGIC
always @(posedge clk)
begin
	if(reset)
	begin
		pulse_counter_state <= WAIT_FOR_HIST_RESET_DONE;
		wrreq_to_FIFO <= 1'b0;
		data_to_compute_histogram <= 'd0;
	end
	else
		case(pulse_counter_state)
			WAIT_FOR_HIST_RESET_DONE	: 	begin
												wrreq_to_FIFO <= 1'b0;
												data_to_compute_histogram <= 'd0;
												if(reset_done_from_hist	== 1'b1)
													pulse_counter_state <= WAIT_FOR_START_PWC;
												else
													pulse_counter_state <= WAIT_FOR_HIST_RESET_DONE;
											end
			WAIT_FOR_START_PWC			:	begin
												wrreq_to_FIFO <= 1'b0;
												data_to_compute_histogram <= 'd0;
												if(start_PWC == 1'b1)
													pulse_counter_state <= WAIT_FOR_HIGH_PULSE;
												else
													pulse_counter_state <= WAIT_FOR_START_PWC;
											end
			WAIT_FOR_HIGH_PULSE			:	begin
												wrreq_to_FIFO <= 1'b0;
												data_to_compute_histogram <= data_to_compute_histogram;
												if(stop_PWC == 1'b1)
													pulse_counter_state <= WAIT_FOR_START_PWC;
												else if(sampled_input_to_consider == 1'b1)
													pulse_counter_state <= WAIT_FOR_LOW_PULSE;
												else
													pulse_counter_state <= WAIT_FOR_HIGH_PULSE;
											end
			WAIT_FOR_LOW_PULSE			:	begin
												if(stop_PWC == 1'b1)
												begin
													wrreq_to_FIFO <= 1'b0;
													data_to_compute_histogram <= data_to_compute_histogram;
													pulse_counter_state <= WAIT_FOR_START_PWC;
												end
												else if(sampled_input_to_consider == 1'b0)
												begin
													data_to_compute_histogram <= count_val + 1'b1; // SAMPLING ONE CYCLE AHEAD. SO ADD 1 TO THE CURRENT COUNT
													wrreq_to_FIFO 			  <= 1'b1;
													pulse_counter_state 	  <= WAIT_FOR_HIGH_PULSE;
												end
												else
												begin
													pulse_counter_state <= WAIT_FOR_LOW_PULSE;
													wrreq_to_FIFO <= 1'b0;
													data_to_compute_histogram <= data_to_compute_histogram;
												end
											end
			default						:	begin
												pulse_counter_state <= pulse_counter_state;
												wrreq_to_FIFO <= wrreq_to_FIFO;
												data_to_compute_histogram <= data_to_compute_histogram;
											end
		endcase
end

// CONTROL SIGNALS TO counter
assign count_enable 	= (pulse_counter_state == WAIT_FOR_LOW_PULSE) 			? 1'b1 : 1'b0;
assign reset_counter  	= ((pulse_counter_state != WAIT_FOR_LOW_PULSE) || reset) 	? 1'b1 : 1'b0;

// COUNT THE PULSE WIDTH
counter 
#(
	.DATA_WIDTH(DATA_WIDTH)
)
CNT0(
	.clk(clk),
	.enable(count_enable),
	.rst(reset_counter),
	.count_val(count_val)
);
endmodule
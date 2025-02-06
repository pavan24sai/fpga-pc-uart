module pulse_gen_top #(parameter NUM_BITS = 9, parameter NUM_PULSES = 10)
  (
   input clk,
   input reset,
   input start,
   input stop,
   output wire pulse_out,
   output wire done_out
  );

  wire [NUM_BITS-1:0] w_LFSR_Data;
  wire w_LFSR_Enable, w_LFSR_Done;

  // LFSR Instance
  LFSR #(.NUM_BITS(NUM_BITS)) LFSR_inst
  (
    .clk(clk),
    .reset(reset),
    .enb(w_LFSR_Enable),
    .i_Seed_DV(1'b0),
    .i_Seed_Data({NUM_BITS{1'b0}}),
    .o_LFSR_Data(w_LFSR_Data),
    .o_LFSR_Done(w_LFSR_Done)
  );

  // Pulse Controller Instance
  pulse_controller #(.NUM_BITS(NUM_BITS), .NUM_PULSES(NUM_PULSES)) pulse_controller_inst
  (
    .clk(clk),
    .reset(reset),
	.start(start),
	.stop(stop),
    .LFSR_Data(w_LFSR_Data),
    .LFSR_Enable(w_LFSR_Enable),
    .pulse_out(pulse_out),
    .done_out(done_out)
  );

endmodule
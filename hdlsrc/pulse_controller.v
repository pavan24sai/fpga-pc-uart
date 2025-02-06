module pulse_controller #(parameter NUM_BITS = 9, parameter NUM_PULSES = 10)
  (
   input clk,
   input reset,
   input start,
   input stop,
   input [NUM_BITS-1:0] LFSR_Data,  // LFSR random value (pulse width)
   output reg LFSR_Enable,
   output reg pulse_out,            // Pulse output
   output reg done_out              // Done signal after NUM_PULSES pulses
  );

  reg [NUM_BITS-1:0] r_Pulse_Counter = 0;  // Counter for pulse width
  reg [15:0] r_Num_Pulses = 0;             // Counter for number of pulses
  reg [2:0] r_State = 0;                   // State machine

  localparam WAIT_FOR_START = 3'b000;
  localparam ENABLE_LFSR    = 3'b001;  // Enable LFSR for one clock cycle
  localparam SAMPLE_DATA    = 3'b010;  // Sample the LFSR value
  localparam GENERATE_PULSE = 3'b011;  // Generate the pulse
  localparam DONE_STATE     = 3'b100;  // Done state after NUM_PULSES pulses

  always @(posedge clk)
    begin
      if (reset)
        begin
          r_State <= WAIT_FOR_START;
          r_Pulse_Counter <= 0;
          r_Num_Pulses <= 0;
          LFSR_Enable <= 0;
          pulse_out <= 0;
          done_out <= 0;
        end
      else
        begin
          case (r_State)
		    WAIT_FOR_START:
			  begin
				LFSR_Enable <= 1'b0;
				if(start == 1'b1)
					r_State <= ENABLE_LFSR;
				else
					r_State <= WAIT_FOR_START;
			  end
            // Enable LFSR for one clock cycle to generate a random value
            ENABLE_LFSR:
              begin
				if(stop == 1'b1)
				  begin
					r_State <= WAIT_FOR_START;
					LFSR_Enable <= 0;
					pulse_out <= 0;
				  end
				else if (r_Num_Pulses < NUM_PULSES)
                  begin
                    LFSR_Enable <= 1;  // Enable LFSR for one clock cycle
                    r_State <= SAMPLE_DATA;
                  end
                else
                  begin
                    done_out <= 1;  // Assert done signal
                    r_State <= DONE_STATE;  // Go to done state
                  end
              end

            // Latch the random value and disable LFSR
            SAMPLE_DATA:
              begin
			    if(stop == 1'b1)
				  begin
					r_State <= WAIT_FOR_START;
					LFSR_Enable <= 0;
					pulse_out <= 0;
				  end
				else
				  begin
					LFSR_Enable <= 0;  // Disable LFSR after sampling the value
					r_Pulse_Counter <= LFSR_Data;  // Latch the pulse width
					pulse_out <= 1;  // Start pulse
					r_State <= GENERATE_PULSE;
				  end
              end

            // Generate pulse for `r_Pulse_Counter` clock cycles
            GENERATE_PULSE:
              begin
				if(stop == 1'b1)
				  begin
					r_State <= WAIT_FOR_START;
					LFSR_Enable <= 0;
					pulse_out <= 0;
				  end
				else if (r_Pulse_Counter > 1)
                  begin
                    r_Pulse_Counter <= r_Pulse_Counter - 1;  // Decrement counter
					pulse_out <= 1;
                  end
                else
                  begin
                    pulse_out <= 0;  // End pulse after specified width
                    r_Num_Pulses <= r_Num_Pulses + 1;  // Increment pulse count
                    r_State <= ENABLE_LFSR;  // Re-enable LFSR for the next value
                  end
              end

            // Done state: stop generating pulses
            DONE_STATE:
              begin
                pulse_out <= 0;  // Keep pulse low
                LFSR_Enable <= 0;  // Keep LFSR disabled
                done_out <= 1;  // Keep done signal high
              end
          endcase
        end
    end
endmodule
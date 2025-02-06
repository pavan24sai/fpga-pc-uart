`timescale 1ns / 1ps

module hist_system_tb();

// Parameters
parameter NUM_PULSES = 1500; // Number of pulses to generate
localparam UART_CLKS_PER_BIT = 435;

reg clk, reset;

wire pulse_out, clk_fastest, clk_slowest;
wire done;
integer i;

// Pulse widths storage (to hold widths of all the pulses generated)
reg [15:0] pulse_widths [0:NUM_PULSES-1];  // Array to store pulse widths
integer pulse_index; // Index to store the pulse width in the array

// Variables for pulse width calculation (16-bit)
reg [31:0] pulse_start_time;    // Time when pulse starts
reg [31:0] pulse_end_time;      // Time when pulse ends

// Signal tracking for pulse edges
reg prev_pulse_out;  // To store the previous state of pulse_out

wire UART_TX_TO_PC, uart_tx_active, uart_tx_done, uart_rx_done;
wire UART_RX_FROM_PC, UART_TX_TO_CTRL;
reg [7:0] uart_tx_byte;
wire [7:0] uart_rx_byte;
reg uart_start_tx;

reg [15:0] rx_done_count;

// Command Definitions
localparam CMD_END_COMMAND   	= 8'b11111111;
localparam CMD_START_HIST    	= 8'd2;
localparam CMD_STOP_HIST     	= 8'd3;
localparam CMD_CLEAR_RESULTS 	= 8'd4;
localparam CMD_START_UPLOAD  	= 8'd5;
localparam CMD_SET_BINADDR   	= 8'd6;
localparam CMD_SET_NUMBINS   	= 8'd7;

hist_system
#(
    .NUM_PULSES(NUM_PULSES),
	.UART_CLKS_PER_BIT(UART_CLKS_PER_BIT)
) 
SYS_MOD
(
    .clk(clk),
    .areset_n(reset),
	.UART_RX_FROM_PC(UART_RX_FROM_PC),
	.UART_TX_TO_PC(UART_TX_TO_PC),
    .pulse_out(pulse_out),
    .done_out(done),
    .clk_slowest(clk_slowest),
    .clk_fastest(clk_fastest)
);

UART_TX 
#(
	.CLKS_PER_BIT(UART_CLKS_PER_BIT)
)
pc_tx_module
(
	.i_Rst(~reset),
    .i_Clock(clk_slowest),
    .i_TX_DV(uart_start_tx),
    .i_TX_Byte(uart_tx_byte),
    .o_TX_Active(uart_tx_active),
    .o_TX_Serial(UART_TX_TO_CTRL),
    .o_TX_Done(uart_tx_done)
);

// UART RECEIVE MODULE
UART_RX
#(
	.CLKS_PER_BIT(UART_CLKS_PER_BIT)
)
pc_rx_module
(
	.i_Clock(clk_slowest),
	.i_RX_Serial(UART_TX_TO_PC),
	.o_RX_DV(uart_rx_done),
	.o_RX_Byte(uart_rx_byte)
);

assign UART_RX_FROM_PC = uart_tx_active ? UART_TX_TO_CTRL : 1'b1;

always #10 clk = !clk;

integer file_handle;       // File handle for writing pulse widths
integer pulse_values_file; // File handle for writing pulse values

initial 
begin
    clk = 1'b0;
    reset = 1'b0;
    pulse_index = 0;
	rx_done_count = 0;

    // Initialize pulse_widths array to 0
    for (i = 0; i < NUM_PULSES; i = i + 1) begin
        pulse_widths[i] = 0;
    end

    waitClocks_50MHz(20);
    reset = 1'b1;
    waitClocks_Hist(1000);
	
	TEST_CMD_CLEAR_RESULTS();
	wait(uart_rx_done);
	
	TEST_CMD_START_HIST();
	wait(uart_rx_done);

    wait(done);
	
    waitClocks_Hist(100);
	
	TEST_CMD_STOP_HIST();
	wait(uart_rx_done);
	
	TEST_CMD_SET_NUM_BINS(8'b00100011, 8'd0); // 00_0010_0011
	wait(uart_rx_done);
	TEST_CMD_SET_ADDRESS(8'd10 , 8'd0);
	wait(uart_rx_done);
	
	waitClocks_Hist(400);

	TEST_CMD_START_DATA_UPLOAD();
    repeat(71) // 2*35 + 1
	begin
		wait(uart_rx_done);
		rx_done_count = rx_done_count + 1;
		$display("%0d RX_DONE CAPTURED", rx_done_count);
		waitClocks_Hist(2);
	end

	waitClocks_Hist(50000);

    // Open a file for writing pulse widths
    file_handle = $fopen("pulse_widths.txt", "w");
    if (file_handle == 0) begin
        $display("Error: Unable to open file for writing.");
        $finish;
    end

    // Write pulse widths to the file
    $fdisplay(file_handle, "Pulse Widths:");
    for (i = 0; i < pulse_index; i = i + 1) begin
        $fdisplay(file_handle, "Pulse %d Width: %d", i + 1, pulse_widths[i]);
    end

    // Close the file
    $fclose(file_handle);

    $finish;
end

task TEST_CMD_STOP_HIST();
begin
	UART_WRITE_TX(CMD_STOP_HIST);
	waitClocks_Hist(50);
	UART_WRITE_TX(CMD_END_COMMAND);
end
endtask

task TEST_CMD_START_HIST();
begin
	UART_WRITE_TX(CMD_START_HIST);
	waitClocks_Hist(50);
	UART_WRITE_TX(CMD_END_COMMAND);
end
endtask

task TEST_CMD_START_DATA_UPLOAD();
begin
	UART_WRITE_TX(CMD_START_UPLOAD);
	waitClocks_Hist(50);
	UART_WRITE_TX(CMD_END_COMMAND);
end
endtask

task TEST_CMD_CLEAR_RESULTS();
begin
	UART_WRITE_TX(CMD_CLEAR_RESULTS);
	waitClocks_Hist(50);
	UART_WRITE_TX(CMD_END_COMMAND);
end
endtask

task TEST_CMD_SET_NUM_BINS(input reg [7:0] lsb_byte, input reg [7:0] msb_byte);
begin
	UART_WRITE_TX(CMD_SET_NUMBINS);
	waitClocks_Hist(50);
	UART_WRITE_TX(lsb_byte);
	waitClocks_Hist(50);
	UART_WRITE_TX(msb_byte);
	waitClocks_Hist(50);
	UART_WRITE_TX(CMD_END_COMMAND);
end
endtask

task TEST_CMD_SET_ADDRESS(input reg [7:0] lsb_byte, input reg [7:0] msb_byte);
begin
	UART_WRITE_TX(CMD_SET_BINADDR);
	waitClocks_Hist(50);
	UART_WRITE_TX(lsb_byte);
	waitClocks_Hist(50);
	UART_WRITE_TX(msb_byte);
	waitClocks_Hist(50);
	UART_WRITE_TX(CMD_END_COMMAND);
end
endtask

task UART_WRITE_TX(input reg [7:0] addr_to_transfer);
begin
	// Tell UART to send a command (exercise TX)
    @(negedge clk_slowest);
    @(negedge clk_slowest);
    uart_start_tx   <= 1'b1;
    uart_tx_byte	<= addr_to_transfer;
    @(negedge clk_slowest);
    uart_start_tx 	<= 1'b0;
	wait(uart_tx_done);
end
endtask

task waitClocks_50MHz(input reg [31:0] numEdges);
begin
    repeat(numEdges) @(posedge clk);
end
endtask

task waitClocks_PWC(input reg [31:0] numEdges);
begin
    repeat(numEdges) @(posedge clk_fastest);
end
endtask

task waitClocks_Hist(input reg [31:0] numEdges);
begin
    repeat(numEdges) @(posedge clk_slowest);
end
endtask

// Task to capture the start time of the pulse
task capture_start_time;
    begin
        pulse_start_time = $time;  // Capture the current simulation time using $time
    end
endtask

// Task to capture the end time of the pulse and calculate width
task capture_end_time;
    begin
        pulse_end_time = $time;  // Capture the current simulation time using $time
        
        // Ensure start time is less than end time
        if (pulse_start_time < pulse_end_time) begin
            // Calculate the pulse width and store it
            if (pulse_index < NUM_PULSES) begin
                pulse_widths[pulse_index] = (pulse_end_time - pulse_start_time);  // Store pulse width in consistent units
                pulse_index = pulse_index + 1; // Move to next index
            end
        end else begin
            // Handle invalid time captures or log an error
            $display("Error: Invalid pulse time capture at time %0t", pulse_end_time);
        end
    end
endtask

always @(posedge pulse_out) 
begin 
	capture_start_time; 
end

always @(negedge pulse_out) 
begin 
	capture_end_time;
end

// Additional logic for pulse value logging
initial begin
    pulse_values_file = $fopen("pulse_values.txt", "w");
    if (pulse_values_file == 0) begin
        $display("Error: Unable to open file for writing pulse values.");
        $finish;
    end
end

always @(posedge clk_fastest) begin
    if (!reset || done) begin
        // Close the file when reset is low or done is asserted
        if (pulse_values_file) begin
            $fclose(pulse_values_file);
            pulse_values_file = 0;
        end
    end else begin
        // Log pulse value to the file
        $fdisplay(pulse_values_file, "Time: %0t, Pulse Value: %b", $time, pulse_out);
    end
end

endmodule
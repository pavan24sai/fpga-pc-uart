module synchronizer (
    input wire clk,
    input wire reset,
    input wire sig_in,
    output reg sig_sync_out
);

    // Intermediate flip-flop stages
    reg sync_stage1;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            sync_stage1 <= 1'b0;
            sig_sync_out <= 1'b0;
        end else begin
            sync_stage1 <= sig_in;  // First stage
            sig_sync_out <= sync_stage1; // Second stage
        end
    end

endmodule

module counter #(parameter DATA_WIDTH=16) (clk, enable, rst, count_val);

input clk, enable, rst;
output reg [DATA_WIDTH-1:0] count_val;

always@(posedge clk)
begin
	if(rst)
		count_val <= 'd0;
	else begin
		if(enable)
			count_val <= count_val + 1'b1;
		else
			count_val <= count_val;
	end
end

endmodule
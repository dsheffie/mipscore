module ram1r1w (
	clk,
	rd_addr,
	wr_addr,
	wr_data,
	wr_en,
	rd_data
);
	input wire clk;
	parameter WIDTH = 1;
	parameter LG_DEPTH = 1;
	input wire [LG_DEPTH - 1:0] rd_addr;
	input wire [LG_DEPTH - 1:0] wr_addr;
	input wire [WIDTH - 1:0] wr_data;
	input wire wr_en;
	output reg [WIDTH - 1:0] rd_data;
	localparam DEPTH = 1 << LG_DEPTH;
	reg [WIDTH - 1:0] r_ram [DEPTH - 1:0];
	always @(posedge clk) begin
		rd_data <= r_ram[rd_addr];
		if (wr_en)
			r_ram[wr_addr] <= wr_data;
	end
endmodule

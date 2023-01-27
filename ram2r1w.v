module ram2r1w (
	clk,
	rd_addr0,
	rd_addr1,
	wr_addr,
	wr_data,
	wr_en,
	rd_data0,
	rd_data1
);
	input wire clk;
	parameter WIDTH = 1;
	parameter LG_DEPTH = 1;
	input wire [LG_DEPTH - 1:0] rd_addr0;
	input wire [LG_DEPTH - 1:0] rd_addr1;
	input wire [LG_DEPTH - 1:0] wr_addr;
	input wire [WIDTH - 1:0] wr_data;
	input wire wr_en;
	output wire [WIDTH - 1:0] rd_data0;
	output wire [WIDTH - 1:0] rd_data1;
	ram1r1w #(
		.WIDTH(WIDTH),
		.LG_DEPTH(LG_DEPTH)
	) b0(
		.clk(clk),
		.rd_addr(rd_addr0),
		.wr_addr(wr_addr),
		.wr_data(wr_data),
		.wr_en(wr_en),
		.rd_data(rd_data0)
	);
	ram1r1w #(
		.WIDTH(WIDTH),
		.LG_DEPTH(LG_DEPTH)
	) b1(
		.clk(clk),
		.rd_addr(rd_addr1),
		.wr_addr(wr_addr),
		.wr_data(wr_data),
		.wr_en(wr_en),
		.rd_data(rd_data1)
	);
endmodule

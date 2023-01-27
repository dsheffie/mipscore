module fair_sched (
	clk,
	rst,
	in,
	y
);
	parameter LG_N = 2;
	localparam N = 1 << LG_N;
	input wire clk;
	input wire rst;
	input wire [N - 1:0] in;
	output reg [LG_N:0] y;
	reg any_valid = |in;
	reg [LG_N - 1:0] r_cnt;
	wire [LG_N - 1:0] n_cnt;
	reg [(2 * N) - 1:0] t_in2;
	reg [(2 * N) - 1:0] t_in_shift;
	reg [N - 1:0] t_in;
	wire [LG_N:0] t_y;
	always @(*) begin
		t_in2 = {in, in};
		t_in_shift = t_in2 << r_cnt;
		t_in = t_in_shift[(2 * N) - 1:N];
	end
	always @(posedge clk)
		if (rst)
			r_cnt <= 'd0;
		else
			r_cnt <= (any_valid ? r_cnt + 'd1 : r_cnt);
	find_first_set #(LG_N) f(
		.in(t_in),
		.y(t_y)
	);
	reg [LG_N - 1:0] t_yy = t_y[LG_N - 1:0] - r_cnt;
	always @(*) begin
		y = {LG_N + 1 {1'b1}};
		if (any_valid)
			y = {1'b0, t_yy};
	end
	always @(negedge clk)
		if (any_valid)
			if (in[y[LG_N - 1:0]] == 1'b0) begin
				$display("input %b, r_cnt %d, t_in %b, t_y = %d, y = %d", in, r_cnt, t_in, t_y, y);
				$display("t_in_shift = %b", t_in_shift);
				$display("t_in2 = %b", t_in2);
				$stop;
			end
endmodule

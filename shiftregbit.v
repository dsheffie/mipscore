module dffen (
	q,
	d,
	clk,
	reset,
	en
);
	parameter N = 1;
	input wire [N - 1:0] d;
	input wire clk;
	input wire reset;
	input wire en;
	output reg [N - 1:0] q;
	always @(posedge clk)
		if (reset)
			q <= 1'b0;
		else
			q <= (en ? d : q);
endmodule
module shiftregbit (
	clk,
	reset,
	b,
	valid,
	out
);
	input wire clk;
	input wire reset;
	input wire b;
	input wire valid;
	parameter W = 32;
	output wire [W - 1:0] out;
	genvar i;
	generate
		for (i = 0; i < W; i = i + 1) begin : sr
			if (i == 0) begin : genblk1
				dffen #(.N(1)) ff(
					.clk(clk),
					.reset(reset),
					.en(valid),
					.d(b),
					.q(out[0])
				);
			end
			else begin : genblk1
				dffen #(.N(1)) ff(
					.clk(clk),
					.reset(reset),
					.en(valid),
					.d(out[i - 1]),
					.q(out[i])
				);
			end
		end
	endgenerate
endmodule

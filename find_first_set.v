module find_first_set (
	in,
	y
);
	parameter LG_N = 2;
	localparam N = 1 << LG_N;
	localparam N2 = 1 << (LG_N - 1);
	input wire [N - 1:0] in;
	output reg [LG_N:0] y;
	wire [LG_N - 1:0] t0;
	wire [LG_N - 1:0] t1;
	reg lo_z = in[N2 - 1:0] == 'd0;
	reg hi_z = in[N - 1:N2] == 'd0;
	generate
		if (LG_N == 2) begin : genblk1
			always @(*) begin
				y = 3'b111;
				casez (in)
					4'b0001: y = 3'd0;
					4'b001z: y = 3'd1;
					4'b01zz: y = 3'd2;
					4'b1zzz: y = 3'd3;
					default: y = 3'b111;
				endcase
			end
		end
		else begin : genblk1
			find_first_set #(.LG_N(LG_N - 1)) f0(
				.in(in[N2 - 1:0]),
				.y(t0)
			);
			find_first_set #(.LG_N(LG_N - 1)) f1(
				.in(in[N - 1:N2]),
				.y(t1)
			);
			always @(*) begin
				y = N;
				if (lo_z && hi_z)
					y = N;
				else if (!hi_z)
					y = N2 + t1;
				else if (!lo_z)
					y = {1'b0, t0};
			end
		end
	endgenerate
endmodule

module dff (
	q,
	d,
	clk
);
	parameter N = 1;
	input wire [N - 1:0] d;
	input wire clk;
	output reg [N - 1:0] q;
	always @(posedge clk) q <= d;
endmodule
module shiftreg (
	clk,
	in,
	out
);
	parameter W = 32;
	parameter D = 4;
	input wire clk;
	input wire [W - 1:0] in;
	output wire [W - 1:0] out;
	wire [W - 1:0] t_delay [D - 1:0];
	assign out = t_delay[D - 1];
	dff #(.N(W)) ff0(
		.clk(clk),
		.d(in),
		.q(t_delay[0])
	);
	genvar i;
	generate
		for (i = 1; i < D; i = i + 1) begin : delay
			dff #(.N(W)) ff(
				.clk(clk),
				.d(t_delay[i - 1]),
				.q(t_delay[i])
			);
		end
	endgenerate
endmodule
module fracmul (
	y,
	a,
	b
);
	parameter W = 24;
	localparam W2 = W * 2;
	input [W - 1:0] a;
	input [W - 1:0] b;
	output wire [W2 - 1:0] y;
	wire [W2 - 1:0] w_comb_mul = a * b;
	assign y = w_comb_mul;
endmodule
module expadd (
	y,
	a,
	b
);
	parameter L = 3;
	parameter W = 8;
	input wire [W - 1:0] a;
	input wire [W - 1:0] b;
	output wire [W:0] y;
	wire [W - 1:0] w_bias = (1 << (W - 1)) - 1;
	wire [W:0] w_comb_add = (a + b) - w_bias;
	assign y = w_comb_add;
endmodule
module detection (
	zero,
	nan,
	infinity,
	a,
	b
);
	parameter E = 11;
	parameter F = 52;
	localparam W = (E + F) + 1;
	input wire [W - 1:0] a;
	input wire [W - 1:0] b;
	output wire zero;
	output wire nan;
	output wire infinity;
	wire w_nan = 1'b0;
	reg t_az;
	reg t_bz;
	wire [2:0] t_detect;
	wire [2:0] t_out;
	wire [E - 1:0] w_exp_a = a[W - 2:F];
	wire [E - 1:0] w_exp_b = b[W - 2:F];
	wire [F - 1:0] w_mant_a = a[F - 1:0];
	wire [F - 1:0] w_mant_b = b[F - 1:0];
	wire w_infinity_a = &w_exp_a & (w_mant_a == 'd0);
	wire w_infinity_b = &w_exp_b & (w_mant_b == 'd0);
	always @(*) begin
		t_az = a == 'd0;
		t_bz = b == 'd0;
	end
	assign zero = t_az | t_bz;
	assign nan = w_nan;
	assign infinity = w_infinity_a | w_infinity_b;
endmodule
module normalize (
	exp_out,
	mant_out,
	exp_in,
	mant_in
);
	parameter E = 8;
	parameter F = 23;
	input wire [E:0] exp_in;
	output reg [E:0] exp_out;
	input wire [F + 4:0] mant_in;
	output reg [F + 4:0] mant_out;
	always @(*) begin
		mant_out = mant_in;
		exp_out = exp_in;
		if (mant_in[F + 4]) begin
			mant_out = {1'b0, mant_in[F + 4:2], mant_in[1] & mant_in[0]};
			exp_out = exp_in + 'd1;
		end
	end
endmodule
module round (
	exp_out,
	mant_out,
	exp_in,
	mant_in
);
	parameter E = 8;
	parameter F = 23;
	input wire [E:0] exp_in;
	output reg [E:0] exp_out;
	input wire [F + 4:0] mant_in;
	output reg [F + 4:0] mant_out;
	reg [F + 1:0] t_one = {{F + 1 {1'b0}}, 1'b1};
	always @(*) begin
		exp_out = exp_in;
		mant_out = mant_in;
		if (mant_in[2])
			mant_out = {mant_in[F + 4:3] + t_one, 3'd0};
	end
endmodule
module sign (
	y,
	clk,
	a,
	b
);
	input clk;
	input a;
	input b;
	output wire y;
	parameter L = 4;
	shiftreg #(
		.W(1),
		.D(L)
	) d(
		.clk(clk),
		.in(a ^ b),
		.out(y)
	);
endmodule
module fp_mul (
	y,
	clk,
	a,
	b,
	en
);
	parameter W = 32;
	parameter MUL_LAT = 4;
	localparam FW = (W == 32 ? 23 : 52);
	localparam EW = (W == 32 ? 8 : 11);
	localparam INFINITY = (1 << EW) - 1;
	input wire clk;
	input wire [W - 1:0] a;
	input wire [W - 1:0] b;
	input wire en;
	output wire [W - 1:0] y;
	wire [EW:0] w_rnd_exp_out;
	wire [EW:0] w_rnd_exp_in;
	wire [FW + 4:0] w_rnd_mant_out;
	wire [FW + 4:0] w_rnd_mant_in;
	wire [FW + 4:0] w_nrm_mant_out;
	wire [EW:0] w_nrm_exp_out;
	wire [(2 * (FW + 1)) - 1:0] w_prod;
	wire [EW:0] w_exp;
	wire [FW:0] w_mant_a = {1'b1, a[FW - 1:0]};
	wire [FW:0] w_mant_b = {1'b1, b[FW - 1:0]};
	wire [EW - 1:0] w_exp_a = a[W - 2:FW];
	wire [EW - 1:0] w_exp_b = b[W - 2:FW];
	wire w_sign;
	wire w_zero;
	wire w_nan;
	wire w_infinity;
	reg [EW - 1:0] t_exp;
	reg [FW - 1:0] t_mant;
	reg t_sign;
	fracmul #(.W(FW + 1)) m0(
		.y(w_prod),
		.a(w_mant_a),
		.b(w_mant_b)
	);
	expadd #(.W(EW)) e0(
		.y(w_exp),
		.a(w_exp_a),
		.b(w_exp_b)
	);
	detection #(
		.E(EW),
		.F(FW)
	) d0(
		.a(a),
		.b(b),
		.zero(w_zero),
		.nan(w_nan),
		.infinity(w_infinity)
	);
	normalize #(
		.E(EW),
		.F(FW)
	) n0(
		.exp_out(w_rnd_exp_in),
		.mant_out(w_rnd_mant_in),
		.exp_in(w_exp),
		.mant_in(w_prod[(2 * (FW + 1)) - 1:FW - 3])
	);
	round #(
		.E(EW),
		.F(FW)
	) r0(
		.exp_out(w_rnd_exp_out),
		.mant_out(w_rnd_mant_out),
		.exp_in(w_rnd_exp_in),
		.mant_in(w_rnd_mant_in)
	);
	normalize #(
		.E(EW),
		.F(FW)
	) n1(
		.exp_out(w_nrm_exp_out),
		.mant_out(w_nrm_mant_out),
		.exp_in(w_rnd_exp_out),
		.mant_in(w_rnd_mant_out)
	);
	always @(*) begin
		t_exp = w_nrm_exp_out[EW - 1:0];
		t_mant = w_nrm_mant_out[FW + 2:3];
		t_sign = a[W - 1] ^ b[W - 1];
		if (w_zero) begin
			t_exp = 'd0;
			t_mant = 'd0;
		end
		else if (w_infinity) begin
			t_exp = INFINITY;
			t_mant = 'd0;
		end
	end
	shiftreg #(
		.W(W),
		.D(MUL_LAT)
	) sr0(
		.clk(clk),
		.in({t_sign, t_exp, t_mant}),
		.out(y)
	);
endmodule

module fp_compare (
	clk,
	pc,
	a,
	b,
	start,
	cmp_type,
	y
);
	parameter W = 32;
	parameter D = 4;
	input wire clk;
	input wire [63:0] pc;
	input wire [W - 1:0] a;
	input wire [W - 1:0] b;
	input wire start;
	input wire [3:0] cmp_type;
	output wire y;
	localparam F = (W == 32 ? 23 : 52);
	localparam E = (W == 32 ? 8 : 11);
	reg t_y;
	wire w_a_is_zero = a[W - 2:0] == 'd0;
	wire w_b_is_zero = b[W - 2:0] == 'd0;
	wire w_sign_a = (w_a_is_zero ? 1'b0 : a[W - 1]);
	wire w_sign_b = (w_b_is_zero ? 1'b0 : b[W - 1]);
	wire w_both_neg = w_sign_a && w_sign_b;
	wire a_is_nan;
	wire a_is_inf;
	wire a_is_denorm;
	wire b_is_nan;
	wire b_is_inf;
	wire b_is_denorm;
	fp_special_cases #(.W(W)) fsc(
		.in_a(a),
		.in_b(b),
		.a_is_nan(a_is_nan),
		.a_is_inf(a_is_inf),
		.a_is_denorm(a_is_denorm),
		.a_is_zero(),
		.b_is_nan(b_is_nan),
		.b_is_inf(b_is_inf),
		.b_is_denorm(b_is_denorm),
		.b_is_zero()
	);
	wire [E - 1:0] w_exp_a = a[W - 2:F];
	wire [E - 1:0] w_exp_b = b[W - 2:F];
	wire [F - 1:0] w_mant_a = a[F - 1:0];
	wire [F - 1:0] w_mant_b = b[F - 1:0];
	reg [D - 1:0] r_d;
	wire [D - 1:0] w_d;
	assign y = r_d[D - 1];
	assign w_d[0] = t_y;
	genvar i;
	generate
		for (i = 1; i < D; i = i + 1) begin : genblk1
			assign w_d[i] = r_d[i - 1];
		end
	endgenerate
	always @(posedge clk) r_d <= w_d;
	wire w_sign_lt = (w_sign_a ^ w_sign_b) & w_sign_a;
	wire w_sign_gt = (w_sign_a ^ w_sign_b) & w_sign_b;
	wire w_sign_eq = w_sign_a == w_sign_b;
	wire w_exp_lt = (w_exp_a < w_exp_b) & w_sign_eq;
	wire w_exp_gt = (w_exp_a > w_exp_b) & w_sign_eq;
	wire w_exp_eq = (w_exp_a == w_exp_b) & w_sign_eq;
	wire w_mant_lt = (w_mant_a < w_mant_b) & w_exp_eq;
	wire w_mant_gt = (w_mant_a > w_mant_b) & w_exp_eq;
	wire w_lt_t = (w_sign_lt | w_exp_lt) | w_mant_lt;
	wire w_gt_t = (w_sign_gt | w_exp_gt) | w_mant_gt;
	wire w_lt = (w_both_neg ? w_gt_t : w_lt_t);
	wire w_eq = (a == b) || (w_a_is_zero && w_b_is_zero);
	wire w_le = w_lt | w_eq;
	always @(*) begin
		t_y = 1'b0;
		case (cmp_type)
			4'd1: t_y = w_lt;
			4'd2: t_y = w_le;
			4'd3: t_y = w_eq;
			default:
				;
		endcase
	end
endmodule

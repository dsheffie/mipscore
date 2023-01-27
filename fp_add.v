module zero_detector (
	distance,
	a
);
	parameter LG_W = 5;
	parameter W = 24;
	input wire [W:0] a;
	output reg [LG_W - 1:0] distance;
	localparam WW = 1 << LG_W;
	localparam ZP = (WW - W) - 1;
	reg [ZP - 1:0] t_zp = {ZP {1'b0}};
	reg [WW - 1:0] t_a_pad = {a, t_zp};
	wire [LG_W:0] t_ffs;
	count_leading_zeros #(.LG_N(LG_W)) zffs(
		t_a_pad,
		t_ffs
	);
	always @(*) begin
		distance = t_ffs[LG_W - 1:0];
		if (t_ffs >= W)
			distance = W;
	end
endmodule
module fp_add (
	y,
	clk,
	sub,
	a,
	b,
	en
);
	parameter W = 32;
	parameter ADD_LAT = 2;
	input wire clk;
	input wire sub;
	input wire [W - 1:0] a;
	input wire [W - 1:0] b;
	input wire en;
	output wire [W - 1:0] y;
	localparam FW = (W == 32 ? 23 : 52);
	localparam EW = (W == 32 ? 8 : 11);
	wire w_sign_toggle_b = (sub ? ~b[W - 1] : b[W - 1]);
	wire [W - 1:0] w_b = {w_sign_toggle_b, b[W - 2:0]};
	wire w_a_is_zero = a[W - 2:0] == 'd0;
	wire w_b_is_zero = b[W - 2:0] == 'd0;
	wire [W - 1:0] t_aligned_a;
	wire [W - 1:0] t_aligned_b;
	reg [EW - 1:0] t_dist_a;
	reg [EW - 1:0] t_dist_b;
	reg [FW + 3:0] t_a_mant;
	reg [FW + 3:0] t_b_mant;
	reg [FW + 3:0] t_a_align_mant;
	reg [FW + 3:0] t_b_align_mant;
	reg [EW:0] t_align_exp;
	always @(*) begin
		t_a_mant = {1'b1, a[FW - 1:0], 3'd0};
		t_b_mant = {1'b1, b[FW - 1:0], 3'd0};
		t_dist_a = a[W - 2:FW] - b[W - 2:FW];
		t_dist_b = b[W - 2:FW] - a[W - 2:FW];
	end
	wire [FW + 3:0] w_or_mant_a;
	wire [FW + 3:0] w_or_mant_b;
	assign w_or_mant_a[0] = a[0];
	assign w_or_mant_b[0] = b[0];
	genvar i;
	generate
		for (i = 1; i < (FW + 3); i = i + 1) begin : genblk1
			assign w_or_mant_a[i] = |a[i:0];
			assign w_or_mant_b[i] = |b[i:0];
		end
	endgenerate
	localparam LG_FW = (FW == 23 ? 5 : 6);
	wire a_shifted = w_or_mant_a[t_dist_b[LG_FW - 1:0]];
	wire b_shifted = w_or_mant_b[t_dist_b[LG_FW - 1:0]];
	always @(*) begin
		t_a_align_mant = t_a_mant;
		t_align_exp = {1'b0, a[W - 2:FW]};
		t_b_align_mant = t_b_mant;
		if (a[W - 2:FW] > b[W - 2:FW])
			t_b_align_mant = (t_b_mant >> t_dist_a) | {{FW + 3 {1'b0}}, b_shifted};
		else if (b[W - 2:FW] > a[W - 2:FW]) begin
			t_a_align_mant = (t_a_mant >> t_dist_b) | {{FW + 3 {1'b0}}, a_shifted};
			t_align_exp = {1'b0, b[W - 2:FW]};
		end
	end
	reg [FW + 4:0] t_align_sum;
	reg t_align_sign;
	always @(*) begin
		t_align_sum = {1'b0, t_a_align_mant} + t_b_align_mant;
		t_align_sign = a[W - 1];
		if (a[W - 1] != w_b[W - 1])
			if (t_a_align_mant > t_b_align_mant) begin
				t_align_sum = {1'b0, t_a_align_mant} - t_b_align_mant;
				t_align_sign = a[W - 1];
			end
			else begin
				t_align_sum = {1'b0, t_b_align_mant} - t_a_align_mant;
				t_align_sign = w_b[W - 1];
			end
	end
	reg [FW:0] t_add_mant;
	reg [EW:0] t_add_exp;
	reg t_guard;
	reg t_round;
	reg t_sticky;
	always @(*) begin
		t_add_mant = t_align_sum[FW + 3:3];
		t_guard = t_align_sum[2];
		t_round = t_align_sum[1];
		t_sticky = t_align_sum[0];
		t_add_exp = t_align_exp;
		if (t_align_sum[FW + 4]) begin
			t_add_mant = t_align_sum[FW + 4:4];
			t_guard = t_align_sum[3];
			t_round = t_align_sum[2];
			t_sticky = t_align_sum[1] | t_align_sum[0];
			t_add_exp = t_align_exp + 'd1;
		end
	end
	reg [FW:0] t_norm1_add_mant;
	reg [EW:0] t_norm1_add_exp;
	reg t_norm1_guard;
	reg t_norm1_round;
	reg t_norm1_sticky;
	wire [LG_FW - 1:0] w_shft_lft_dist;
	localparam ZP = (EW + 1) - LG_FW;
	zero_detector #(
		.LG_W(LG_FW),
		.W(FW)
	) zd(
		.distance(w_shft_lft_dist),
		.a(t_add_mant)
	);
	wire [EW:0] w_shift_dist = {{ZP {1'b0}}, w_shft_lft_dist};
	always @(*) begin
		t_norm1_add_mant = t_add_mant;
		t_norm1_add_exp = t_add_exp;
		t_norm1_guard = t_guard;
		t_norm1_round = t_round;
		t_norm1_sticky = t_sticky;
		if ((t_add_mant[FW] == 1'b0) && (t_add_exp != 'd0)) begin
			t_norm1_add_exp = t_add_exp - w_shift_dist;
			if (w_shift_dist == 'd1) begin
				t_norm1_guard = t_norm1_round;
				t_norm1_round = 1'b0;
			end
			else begin
				t_norm1_guard = 1'b0;
				t_norm1_round = 1'b0;
			end
			if (w_shift_dist == 'd1)
				t_norm1_add_mant = {t_add_mant[FW - 1:0], t_guard};
			else
				t_norm1_add_mant = {t_add_mant[FW - 2:0], t_guard, t_round} << (w_shift_dist - 'd2);
		end
	end
	reg [FW:0] t_norm2_add_mant;
	reg [EW:0] t_norm2_add_exp;
	reg t_norm2_guard;
	reg t_norm2_round;
	reg t_norm2_sticky;
	always @(*) begin
		t_norm2_add_mant = t_norm1_add_mant;
		t_norm2_add_exp = t_norm1_add_exp;
		t_norm2_guard = t_norm1_guard;
		t_norm2_round = t_norm1_round;
		t_norm2_sticky = t_norm1_sticky;
	end
	reg [FW:0] t_round_add_mant;
	reg [EW:0] t_round_add_exp;
	always @(*) begin
		t_round_add_mant = t_norm2_add_mant;
		t_round_add_exp = t_norm2_add_exp;
		if (t_norm2_guard && ((t_norm2_round | t_norm2_sticky) | t_norm2_add_mant[0]))
			if (t_norm2_add_mant == {FW + 1 {1'b1}}) begin
				t_round_add_exp = t_norm2_add_exp + 'd1;
				t_round_add_mant = {1'b1, {FW {1'b0}}};
			end
			else
				t_round_add_mant = t_norm2_add_mant + 'd1;
	end
	wire w_is_zero = (a[W - 1] ^ w_b[W - 1]) & (t_round_add_mant == 'd0);
	wire [W - 1:0] w_y = (w_is_zero ? 'd0 : (w_a_is_zero ? w_b : (w_b_is_zero ? a : {t_align_sign, t_round_add_exp[EW - 1:0], t_round_add_mant[FW - 1:0]})));
	shiftreg #(
		.W(W),
		.D(ADD_LAT)
	) sr0(
		.clk(clk),
		.in(w_y),
		.out(y)
	);
endmodule

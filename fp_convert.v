module fp_convert (
	clk,
	in,
	en,
	out
);
	parameter W = 32;
	localparam FW = (W == 32 ? 23 : 52);
	localparam EW = (W == 32 ? 8 : 11);
	localparam LG_W = (W == 32 ? 5 : 6);
	localparam PW = EW - (LG_W + 1);
	input wire clk;
	input wire [W - 1:0] in;
	input wire en;
	output reg [W - 1:0] out;
	wire [EW - 1:0] w_bias = (1 << (EW - 1)) - 1;
	reg [W - 1:0] t_in;
	reg [W - 1:0] t_mant_full;
	reg [FW - 1:0] t_mant;
	reg [FW - 1:0] t_round;
	reg [EW - 1:0] t_exp;
	wire [LG_W:0] t_ffs;
	reg t_sign;
	reg t_zero;
	always @(*) begin
		t_in = in;
		t_sign = 1'b0;
		t_zero = in == 'd0;
		if (in[W - 1]) begin
			t_in = ~in + 'd1;
			t_sign = 1'b1;
		end
	end
	find_first_set #(.LG_N(LG_W)) z0(
		.in(t_in),
		.y(t_ffs)
	);
	always @(*) begin
		t_mant_full = t_in << (W - t_ffs);
		t_round = ((t_mant_full[(W - FW) - 1] && t_mant_full[W - FW]) && (t_ffs > FW) ? 'd1 : 'd0);
		t_mant = t_mant_full[W - 1:W - FW] + t_round;
		t_exp = w_bias + {{PW {1'b0}}, t_ffs};
		out = (t_zero ? 'd0 : {t_sign, t_exp, t_mant});
	end
endmodule

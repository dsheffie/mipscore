module fp_trunc_to_int32 (
	clk,
	in,
	en,
	out
);
	parameter W = 32;
	localparam FW = (W == 32 ? 23 : 52);
	localparam EW = (W == 32 ? 8 : 11);
	localparam PW = W - (FW + 1);
	input wire clk;
	input wire [W - 1:0] in;
	input wire en;
	output reg [W - 1:0] out;
	wire [EW - 1:0] w_bias = (1 << (EW - 1)) - 1;
	wire [EW - 1:0] w_exp = in[W - 2:FW];
	wire [FW:0] w_mant = {1'b1, in[FW - 1:0]};
	wire [FW:0] w_zp = {FW + 1 {1'b0}};
	wire [PW - 1:0] w_op = {PW {1'b0}};
	wire [FW + W:0] w_mant_pad = {{W {1'd0}}, w_mant};
	reg [FW + W:0] t_mant_shift;
	wire w_sign = in[W - 1];
	reg t_zero;
	reg [EW - 1:0] t_shift_dist;
	wire [W - 1:0] t_out;
	reg [W - 1:0] t_t;
	always @(*) begin
		t_zero = w_exp < w_bias;
		t_shift_dist = (w_exp - w_bias) + 1;
		t_shift_dist = (t_shift_dist > W ? W : t_shift_dist);
		t_mant_shift = w_mant_pad << t_shift_dist;
		t_t = 'd0;
		if (!t_zero) begin
			t_t = t_mant_shift[FW + W:FW + 1];
			if (w_sign)
				t_t = ~t_t + 'd1;
		end
	end
	generate
		if (W == 64) begin : genblk1
			assign t_out = {32'd0, t_t[31:0]};
		end
		else begin : genblk1
			assign t_out = t_t;
		end
	endgenerate
	always @(*) out = t_out;
endmodule

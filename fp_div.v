module fp_div (
	y,
	valid,
	rob_ptr_out,
	dst_ptr_out,
	active,
	clk,
	reset,
	a,
	b,
	start,
	is_sqrt,
	rob_ptr_in,
	dst_ptr_in
);
	parameter LG_PRF_WIDTH = 1;
	parameter LG_ROB_WIDTH = 1;
	parameter W = 32;
	localparam FW = (W == 32 ? 23 : 52);
	localparam EW = (W == 32 ? 8 : 11);
	localparam LG_FW = (W == 32 ? 5 : 6);
	localparam DW = 2 * (FW + 1);
	input wire clk;
	input wire reset;
	input wire [W - 1:0] a;
	input wire [W - 1:0] b;
	input wire start;
	input wire is_sqrt;
	input wire [LG_ROB_WIDTH - 1:0] rob_ptr_in;
	input wire [LG_PRF_WIDTH - 1:0] dst_ptr_in;
	output wire [W - 1:0] y;
	output wire valid;
	output wire [LG_ROB_WIDTH - 1:0] rob_ptr_out;
	output wire [LG_PRF_WIDTH - 1:0] dst_ptr_out;
	output wire active;
	wire [FW - 1:0] w_pad = {FW {1'b0}};
	wire [DW - 2:0] w_mant_a = {1'b1, a[FW - 1:0], w_pad};
	wire [DW - 2:0] w_mant_b = {w_pad, 1'b1, b[FW - 1:0]};
	wire t_div_complete;
	reg n_valid;
	reg r_valid;
	reg n_sqrt;
	reg r_sqrt;
	wire [DW - 2:0] y_div;
	reg [2:0] r_state;
	reg [2:0] n_state;
	reg [LG_ROB_WIDTH - 1:0] r_rob_ptr;
	reg [LG_ROB_WIDTH - 1:0] n_rob_ptr;
	reg [LG_PRF_WIDTH - 1:0] r_dst_ptr;
	reg [LG_PRF_WIDTH - 1:0] n_dst_ptr;
	reg [EW:0] r_exp;
	reg [EW:0] n_exp;
	reg [EW:0] r_exp_a;
	reg [EW:0] n_exp_a;
	reg [EW:0] r_exp_b;
	reg [EW:0] n_exp_b;
	reg r_sign;
	reg n_sign;
	reg [DW - 2:0] r_div_mant;
	reg [DW - 2:0] n_div_mant;
	reg [W - 1:0] r_y;
	reg [W - 1:0] n_y;
	reg t_start_div;
	reg r_active;
	reg n_active;
	assign active = r_active;
	assign valid = r_valid;
	assign y = r_y;
	assign dst_ptr_out = r_dst_ptr;
	assign rob_ptr_out = r_rob_ptr;
	wire [EW - 1:0] w_bias = (1 << (EW - 1)) - 1;
	reg [31:0] r_cycle;
	always @(posedge clk) r_cycle <= (reset ? 'd0 : r_cycle + 'd1);
	always @(posedge clk)
		if (reset) begin
			r_state <= 3'd0;
			r_valid <= 1'b0;
			r_sqrt <= 1'b0;
			r_y <= 'd0;
			r_rob_ptr <= 'd0;
			r_dst_ptr <= 'd0;
			r_exp <= 'd0;
			r_exp_a <= 'd0;
			r_exp_b <= 'd0;
			r_sign <= 1'b0;
			r_div_mant <= 'd0;
			r_active <= 1'b0;
		end
		else begin
			r_state <= n_state;
			r_valid <= n_valid;
			r_sqrt <= n_sqrt;
			r_y <= n_y;
			r_rob_ptr <= n_rob_ptr;
			r_dst_ptr <= n_dst_ptr;
			r_exp <= n_exp;
			r_exp_a <= n_exp_a;
			r_exp_b <= n_exp_b;
			r_sign <= n_sign;
			r_div_mant <= n_div_mant;
			r_active <= n_active;
		end
	always @(*) begin
		n_state = r_state;
		n_valid = 1'b0;
		n_y = r_y;
		n_rob_ptr = r_rob_ptr;
		n_dst_ptr = r_dst_ptr;
		n_exp = r_exp;
		n_exp_a = r_exp_a;
		n_exp_b = r_exp_b;
		n_sign = r_sign;
		n_div_mant = r_div_mant;
		n_active = r_active;
		t_start_div = 1'b0;
		n_sqrt = r_sqrt;
		case (r_state)
			3'd0: begin
				if (start) begin
					t_start_div = 1'b1;
					n_dst_ptr = dst_ptr_in;
					n_rob_ptr = rob_ptr_in;
					n_state = 3'd1;
					n_active = 1'b1;
				end
				n_exp_a = {1'b0, a[W - 2:FW]};
				n_exp_b = {1'b0, b[W - 2:FW]};
				n_sign = a[W - 1] ^ b[W - 1];
				n_sqrt = is_sqrt;
			end
			3'd1: begin
				n_exp = (r_exp_a - r_exp_b) + w_bias;
				n_state = 3'd2;
			end
			3'd2:
				if (t_div_complete) begin
					n_div_mant = y_div;
					n_state = (y_div[FW] ? 3'd4 : 3'd3);
				end
			3'd3: begin
				n_div_mant = {r_div_mant[DW - 3:0], 1'b0};
				n_exp = r_exp - 'd1;
				n_state = 3'd4;
			end
			3'd4: begin
				n_state = 3'd5;
				n_y = {r_sign, r_exp[EW - 1:0], r_div_mant[FW - 1:0]};
				n_valid = 1'b1;
			end
			3'd5: begin
				n_state = 3'd0;
				n_active = 1'b0;
			end
			default:
				;
		endcase
	end
	unsigned_divider #(
		.LG_W(1 + LG_FW),
		.W(DW - 1)
	) ud0(
		.clk(clk),
		.reset(reset),
		.srcA(w_mant_a),
		.srcB(w_mant_b),
		.start_div(t_start_div),
		.ready(),
		.complete(t_div_complete),
		.y(y_div)
	);
endmodule

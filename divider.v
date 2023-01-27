module divider (
	clk,
	reset,
	srcA,
	srcB,
	rob_ptr_in,
	hilo_prf_ptr_in,
	is_signed_div,
	start_div,
	y,
	rob_ptr_out,
	hilo_prf_ptr_out,
	ready,
	complete
);
	parameter LG_W = 5;
	localparam W = 1 << LG_W;
	localparam W2 = 2 * W;
	input wire clk;
	input wire reset;
	input wire [W - 1:0] srcA;
	input wire [W - 1:0] srcB;
	input wire [4:0] rob_ptr_in;
	input wire [1:0] hilo_prf_ptr_in;
	input wire is_signed_div;
	input wire start_div;
	output reg [W2 - 1:0] y;
	output reg [4:0] rob_ptr_out;
	output reg [1:0] hilo_prf_ptr_out;
	output reg ready;
	output reg complete;
	reg [2:0] r_state;
	reg [2:0] n_state;
	reg r_is_signed;
	reg n_is_signed;
	reg r_sign;
	reg n_sign;
	reg [4:0] r_rob_ptr;
	reg [4:0] n_rob_ptr;
	reg [1:0] r_hilo_prf_ptr;
	reg [1:0] n_hilo_prf_ptr;
	reg [W - 1:0] r_A;
	reg [W - 1:0] n_A;
	reg [W - 1:0] r_B;
	reg [W - 1:0] n_B;
	reg [W2 - 1:0] r_Y;
	reg [W2 - 1:0] n_Y;
	reg [W2 - 1:0] r_D;
	reg [W2 - 1:0] n_D;
	reg [W2 - 1:0] r_R;
	reg [W2 - 1:0] n_R;
	wire [W - 1:0] t_ss;
	reg [LG_W - 1:0] r_idx;
	reg [LG_W - 1:0] n_idx;
	reg t_bit;
	reg t_valid;
	always @(posedge clk)
		if (reset) begin
			r_state <= 3'd0;
			r_rob_ptr <= 'd0;
			r_hilo_prf_ptr <= 'd0;
			r_is_signed <= 1'b0;
			r_sign <= 1'b0;
			r_A <= 'd0;
			r_B <= 'd0;
			r_Y <= 'd0;
			r_D <= 'd0;
			r_R <= 'd0;
			r_idx <= 'd0;
		end
		else begin
			r_state <= n_state;
			r_rob_ptr <= n_rob_ptr;
			r_hilo_prf_ptr <= n_hilo_prf_ptr;
			r_is_signed <= n_is_signed;
			r_sign <= n_sign;
			r_A <= n_A;
			r_B <= n_B;
			r_Y <= n_Y;
			r_D <= n_D;
			r_R <= n_R;
			r_idx <= n_idx;
		end
	shiftregbit #(.W(W)) ss(
		.clk(clk),
		.reset(reset),
		.b(t_bit),
		.valid(t_valid),
		.out(t_ss)
	);
	always @(*) begin
		n_rob_ptr = r_rob_ptr;
		n_hilo_prf_ptr = r_hilo_prf_ptr;
		n_state = r_state;
		n_is_signed = r_is_signed;
		n_sign = r_sign;
		n_A = r_A;
		n_B = r_B;
		n_Y = r_Y;
		n_D = r_D;
		n_R = r_R;
		n_idx = r_idx;
		t_bit = 1'b0;
		t_valid = 1'b0;
		ready = (r_state == 3'd0) & !start_div;
		rob_ptr_out = r_rob_ptr;
		hilo_prf_ptr_out = r_hilo_prf_ptr;
		y = r_Y;
		complete = 1'b0;
		case (r_state)
			3'd0:
				if (start_div) begin
					n_rob_ptr = rob_ptr_in;
					n_hilo_prf_ptr = hilo_prf_ptr_in;
					n_is_signed = is_signed_div;
					n_state = 3'd1;
					n_A = srcA;
					n_B = srcB;
				end
			3'd1: begin
				if (r_is_signed) begin
					n_sign = r_A[W - 1] ^ r_B[W - 1];
					n_A = (r_A[W - 1] ? ~r_A + 'd1 : r_A);
					n_B = (r_B[W - 1] ? ~r_B + 'd1 : r_B);
				end
				else
					n_sign = 1'b0;
				n_D = {n_B, {W {1'b0}}};
				n_R = {{W {1'b0}}, n_A};
				n_idx = W - 1;
				n_state = 3'd2;
			end
			3'd2: begin
				if ({r_R[W2 - 2:0], 1'b0} >= r_D) begin
					n_R = {r_R[W2 - 2:0], 1'b0} - r_D;
					t_bit = 1'b1;
					t_valid = 1'b1;
				end
				else begin
					n_R = {r_R[W2 - 2:0], 1'b0};
					t_bit = 1'b0;
					t_valid = 1'b1;
				end
				n_state = (r_idx == 'd0 ? 3'd3 : 3'd2);
				n_idx = r_idx - 'd1;
			end
			3'd3: begin
				n_state = 3'd4;
				n_Y[W - 1:0] = t_ss;
				n_Y[W2 - 1:W] = n_R[W2 - 1:W];
			end
			3'd4: begin
				if (r_is_signed && r_sign) begin
					n_Y[W - 1:0] = ~r_Y[W - 1:0] + 'd1;
					n_Y[W2 - 1:W] = ~r_Y[W2 - 1:W] + 'd1;
				end
				n_state = 3'd5;
			end
			3'd5: begin
				complete = 1'b1;
				n_state = 3'd0;
			end
			default:
				;
		endcase
	end
endmodule

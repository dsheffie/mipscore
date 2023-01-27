module unsigned_divider (
	clk,
	reset,
	srcA,
	srcB,
	start_div,
	y,
	ready,
	complete
);
	parameter LG_W = 5;
	parameter W = 1 << LG_W;
	localparam W2 = 2 * W;
	input wire clk;
	input wire reset;
	input wire [W - 1:0] srcA;
	input wire [W - 1:0] srcB;
	input wire start_div;
	output reg [W - 1:0] y;
	output reg ready;
	output reg complete;
	reg [2:0] r_state;
	reg [2:0] n_state;
	reg [W - 1:0] r_A;
	reg [W - 1:0] n_A;
	reg [W - 1:0] r_B;
	reg [W - 1:0] n_B;
	reg [W - 1:0] r_Y;
	reg [W - 1:0] n_Y;
	reg [W2 - 1:0] r_D;
	reg [W2 - 1:0] n_D;
	reg [W2 - 1:0] r_R;
	reg [W2 - 1:0] n_R;
	wire [W - 1:0] t_ss;
	reg [LG_W - 1:0] r_idx;
	reg [LG_W - 1:0] n_idx;
	reg t_bit;
	reg t_valid;
	reg [31:0] n_bits = W - 1;
	always @(posedge clk)
		if (reset) begin
			r_state <= 3'd0;
			r_A <= 'd0;
			r_B <= 'd0;
			r_Y <= 'd0;
			r_D <= 'd0;
			r_R <= 'd0;
			r_idx <= 'd0;
		end
		else begin
			r_state <= n_state;
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
		n_state = r_state;
		n_A = r_A;
		n_B = r_B;
		n_Y = r_Y;
		n_D = r_D;
		n_R = r_R;
		n_idx = r_idx;
		t_bit = 1'b0;
		t_valid = 1'b0;
		ready = r_state == 3'd0;
		y = r_Y;
		complete = 1'b0;
		case (r_state)
			3'd0: begin
				if (start_div)
					n_state = 3'd2;
				n_A = srcA;
				n_B = srcB;
				n_D = {srcB, {W {1'b0}}};
				n_R = {{W {1'b0}}, srcA};
				n_idx = n_bits[LG_W - 1:0];
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
				n_Y = t_ss;
			end
			3'd4: begin
				complete = 1'b1;
				n_state = 3'd0;
			end
			default:
				;
		endcase
	end
endmodule

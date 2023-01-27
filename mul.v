module mul (
	clk,
	reset,
	opcode,
	go,
	src_A,
	src_B,
	src_hilo,
	rob_ptr_in,
	gpr_prf_ptr_in,
	hilo_prf_ptr_in,
	y,
	complete,
	rob_ptr_out,
	gpr_prf_ptr_val_out,
	gpr_prf_ptr_out,
	hilo_prf_ptr_val_out,
	hilo_prf_ptr_out
);
	input wire clk;
	input wire reset;
	input wire [7:0] opcode;
	input wire go;
	input wire [31:0] src_A;
	input wire [31:0] src_B;
	input wire [63:0] src_hilo;
	input wire [4:0] rob_ptr_in;
	input wire [5:0] gpr_prf_ptr_in;
	input wire [1:0] hilo_prf_ptr_in;
	output reg [63:0] y;
	output wire complete;
	output wire [4:0] rob_ptr_out;
	output wire gpr_prf_ptr_val_out;
	output wire [5:0] gpr_prf_ptr_out;
	output wire hilo_prf_ptr_val_out;
	output wire [1:0] hilo_prf_ptr_out;
	reg [63:0] r_mul [2:0];
	reg [2:0] r_complete;
	reg [2:0] r_do_madd;
	reg [2:0] r_do_msub;
	reg [2:0] r_hilo_val;
	reg [1:0] r_hilo_ptr [2:0];
	reg [2:0] r_gpr_val;
	reg [5:0] r_gpr_ptr [2:0];
	reg [63:0] r_madd [2:0];
	reg [4:0] r_rob_ptr [2:0];
	reg [63:0] t_mul;
	assign complete = r_complete[2];
	assign rob_ptr_out = r_rob_ptr[2];
	assign gpr_prf_ptr_val_out = r_gpr_val[2];
	assign gpr_prf_ptr_out = r_gpr_ptr[2];
	assign hilo_prf_ptr_val_out = r_hilo_val[2];
	assign hilo_prf_ptr_out = r_hilo_ptr[2];
	always @(*) begin
		y = r_mul[2];
		if (r_do_madd[2])
			y = r_mul[2] + r_madd[2];
		else if (r_do_msub[2])
			y = r_mul[2] - r_madd[2];
	end
	always @(*)
		if (opcode == 8'd12)
			t_mul = src_A * src_B;
		else
			t_mul = $signed(src_A) * $signed(src_B);
	always @(posedge clk)
		if (reset) begin
			begin : sv2v_autoblock_1
				integer i;
				for (i = 0; i <= 2; i = i + 1)
					begin
						r_mul[i] <= 'd0;
						r_rob_ptr[i] <= 'd0;
						r_gpr_ptr[i] <= 'd0;
						r_hilo_ptr[i] <= 'd0;
						r_madd[i] <= 'd0;
					end
			end
			r_complete <= 'd0;
			r_do_madd <= 'd0;
			r_do_msub <= 'd0;
			r_gpr_val <= 'd0;
			r_hilo_val <= 'd0;
		end
		else begin : sv2v_autoblock_2
			integer i;
			for (i = 0; i <= 2; i = i + 1)
				if (i == 0) begin
					r_mul[0] <= t_mul;
					r_do_madd[0] <= go & (opcode == 8'd66);
					r_do_msub[0] <= go & (opcode == 8'd69);
					r_complete[0] <= go;
					r_rob_ptr[0] <= rob_ptr_in;
					r_gpr_val[0] <= go && (opcode == 8'd68);
					r_hilo_val[0] <= go && (opcode != 8'd68);
					r_gpr_ptr[0] <= gpr_prf_ptr_in;
					r_hilo_ptr[0] <= hilo_prf_ptr_in;
					r_madd[0] <= src_hilo;
				end
				else begin
					r_mul[i] <= r_mul[i - 1];
					r_do_madd[i] <= r_do_madd[i - 1];
					r_do_msub[i] <= r_do_msub[i - 1];
					r_complete[i] <= r_complete[i - 1];
					r_rob_ptr[i] <= r_rob_ptr[i - 1];
					r_gpr_val[i] <= r_gpr_val[i - 1];
					r_hilo_val[i] <= r_hilo_val[i - 1];
					r_gpr_ptr[i] <= r_gpr_ptr[i - 1];
					r_hilo_ptr[i] <= r_hilo_ptr[i - 1];
					r_madd[i] <= r_madd[i - 1];
				end
		end
endmodule

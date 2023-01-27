module wrap (
	clk,
	reset,
	resume,
	resume_pc,
	ready_for_resume,
	is_write,
	addr,
	d_out,
	d_out_valid,
	d_in,
	d_in_valid,
	monitor_req_reason,
	monitor_req_valid,
	monitor_rsp_valid,
	monitor_rsp_data_valid,
	monitor_rsp_data,
	got_break,
	got_syscall,
	got_ud
);
	input wire clk;
	input wire reset;
	input wire resume;
	input wire [63:0] resume_pc;
	output wire ready_for_resume;
	localparam LG_D_WIDTH = 4;
	localparam D_WIDTH = 16;
	localparam L1D_CL_LEN = 16;
	localparam L1D_CL_LEN_BITS = 128;
	localparam LG_N_WORDS = 3;
	localparam N_WORDS = 8;
	output wire is_write;
	output wire [63:0] addr;
	output wire [15:0] d_out;
	output wire d_out_valid;
	input wire [15:0] d_in;
	input wire d_in_valid;
	output wire [15:0] monitor_req_reason;
	output wire monitor_req_valid;
	input wire monitor_rsp_valid;
	input wire monitor_rsp_data_valid;
	input wire [63:0] monitor_rsp_data;
	output wire got_break;
	output wire got_syscall;
	output wire got_ud;
	reg t_mem_req_ack;
	wire mem_req_valid;
	wire [63:0] mem_req_addr;
	wire [127:0] mem_req_store_data;
	wire [4:0] mem_req_opcode;
	wire mem_rsp_valid;
	wire [127:0] mem_rsp_load_data;
	wire [4:0] mem_rsp_opcode;
	reg [1:0] n_state;
	reg [1:0] r_state;
	reg [127:0] r_buf;
	reg [127:0] n_buf;
	reg [127:0] t_buf;
	reg r_is_write;
	reg n_is_write;
	reg [63:0] r_addr;
	reg [63:0] n_addr;
	reg [4:0] r_mem_req_opcode;
	reg [4:0] n_mem_req_opcode;
	reg [LG_N_WORDS:0] r_cnt;
	reg [LG_N_WORDS:0] n_cnt;
	reg n_valid;
	reg r_valid;
	reg r_mem_rsp_valid;
	reg n_mem_rsp_valid;
	wire [15:0] t_buf_rd [7:0];
	always @(*) begin
		t_buf = r_buf;
		if (d_in_valid)
			if (r_cnt == 'd0)
				t_buf[15:0] = d_in;
			else if (r_cnt == 'd1)
				t_buf[31:16] = d_in;
			else if (r_cnt == 'd2)
				t_buf[47:32] = d_in;
			else if (r_cnt == 'd3)
				t_buf[63:48] = d_in;
			else if (r_cnt == 'd4)
				t_buf[79:64] = d_in;
			else if (r_cnt == 'd5)
				t_buf[95:80] = d_in;
			else if (r_cnt == 'd6)
				t_buf[111:96] = d_in;
			else
				t_buf[127:112] = d_in;
	end
	genvar i;
	generate
		for (i = 0; i < N_WORDS; i = i + 1) begin : genblk1
			assign t_buf_rd[i] = r_buf[((i + 1) * D_WIDTH) - 1:i * D_WIDTH];
		end
	endgenerate
	assign is_write = r_is_write;
	assign addr = r_addr;
	assign d_out = t_buf_rd[r_cnt];
	assign d_out_valid = r_valid;
	always @(posedge clk)
		if (reset) begin
			r_buf <= 'd0;
			r_state <= 2'd0;
			r_is_write <= 1'b0;
			r_addr <= 'd0;
			r_mem_req_opcode <= 'd0;
			r_cnt <= 'd0;
			r_valid <= 1'b0;
			r_mem_rsp_valid <= 1'b0;
		end
		else begin
			r_buf <= n_buf;
			r_state <= n_state;
			r_is_write <= n_is_write;
			r_addr <= n_addr;
			r_mem_req_opcode <= n_mem_req_opcode;
			r_cnt <= n_cnt;
			r_valid <= n_valid;
			r_mem_rsp_valid <= n_mem_rsp_valid;
		end
	always @(*) begin
		n_state = r_state;
		n_buf = r_buf;
		n_is_write = r_is_write;
		n_addr = r_addr;
		n_mem_req_opcode = r_mem_req_opcode;
		t_mem_req_ack = 1'b1;
		n_cnt = r_cnt;
		n_valid = 1'b0;
		n_mem_rsp_valid = 1'b0;
		case (r_state)
			2'd0:
				if (mem_req_valid) begin
					n_buf = mem_req_store_data;
					n_mem_req_opcode = mem_req_opcode;
					t_mem_req_ack = 1'b1;
					n_cnt = 'd0;
					if (mem_req_opcode == 5'd4) begin
						n_is_write = 1'b0;
						n_state = 2'd2;
					end
					else begin
						n_is_write = 1'b1;
						n_state = 2'd1;
					end
				end
			2'd2: begin
				n_buf = t_buf;
				if (d_in_valid) begin
					n_cnt = r_cnt + 'd1;
					n_addr = r_addr + 2;
					if (r_cnt == 7) begin
						n_state = 2'd0;
						n_mem_rsp_valid = 1'b1;
					end
				end
			end
			2'd1: begin
				n_cnt = r_cnt + 'd1;
				n_addr = r_addr + 2;
				n_valid = 1'b1;
				if (r_cnt == 7) begin
					n_state = 2'd0;
					n_mem_rsp_valid = 1'b1;
				end
			end
			default:
				;
		endcase
	end
	wire retire_reg_ptr;
	wire retire_reg_data;
	wire retire_reg_valid;
	wire retire_valid;
	core_l1d_l1i mips(
		.clk(clk),
		.reset(reset),
		.resume(resume),
		.resume_pc(resume_pc),
		.ready_for_resume(ready_for_resume),
		.mem_req_ack(t_mem_req_ack),
		.mem_req_valid(mem_req_valid),
		.mem_req_addr(mem_req_addr),
		.mem_req_store_data(mem_req_store_data),
		.mem_req_opcode(mem_req_opcode),
		.mem_rsp_valid(r_mem_rsp_valid),
		.mem_rsp_load_data(r_buf),
		.mem_rsp_tag('d0),
		.mem_rsp_opcode(r_mem_req_opcode),
		.retire_reg_ptr(retire_reg_ptr),
		.retire_reg_data(retire_reg_data),
		.retire_reg_valid(retire_reg_valid),
		.retire_valid(retire_valid),
		.monitor_req_reason(monitor_req_reason),
		.monitor_req_valid(monitor_req_valid),
		.monitor_rsp_valid(monitor_rsp_valid),
		.monitor_rsp_data_valid(monitor_rsp_data_valid),
		.monitor_rsp_data(monitor_rsp_data),
		.got_break(got_break),
		.got_syscall(got_syscall),
		.got_ud(got_ud)
	);
endmodule

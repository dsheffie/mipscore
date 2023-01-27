module xor_fold (
	in,
	out
);
	parameter IN_W = 32;
	parameter OUT_W = 16;
	localparam W = IN_W / 2;
	input [IN_W - 1:0] in;
	output wire [W - 1:0] out;
	reg [W - 1:0] t;
	always @(*) t = in[IN_W - 1:W] ^ in[W - 1:0];
	generate
		if ((2 * W) == OUT_W) begin : genblk1
			assign out = t;
		end
		else begin : genblk1
			xor_fold #(
				.IN_W(W),
				.OUT_W(OUT_W)
			) f(
				.in(t),
				.out(out)
			);
		end
	endgenerate
endmodule
module l1i (
	clk,
	reset,
	flush_req,
	flush_complete,
	restart_pc,
	restart_src_pc,
	restart_src_is_indirect,
	restart_valid,
	restart_ack,
	retire_valid,
	retired_call,
	retired_ret,
	retire_reg_ptr,
	retire_reg_data,
	retire_reg_valid,
	branch_pc_valid,
	took_branch,
	branch_pht_idx,
	insn,
	insn_valid,
	insn_ack,
	insn_two,
	insn_valid_two,
	insn_ack_two,
	mem_req_ack,
	mem_req_valid,
	mem_req_addr,
	mem_req_tag,
	mem_req_opcode,
	mem_rsp_valid,
	mem_rsp_load_data,
	mem_rsp_tag,
	mem_rsp_opcode,
	utlb_miss_req,
	utlb_miss_paddr,
	tlb_rsp_valid,
	tlb_rsp,
	cache_accesses,
	cache_hits
);
	input wire clk;
	input wire reset;
	input wire flush_req;
	output wire flush_complete;
	input wire [63:0] restart_pc;
	input wire [63:0] restart_src_pc;
	input wire restart_src_is_indirect;
	input wire restart_valid;
	output wire restart_ack;
	input wire retire_valid;
	input wire retired_call;
	input wire retired_ret;
	input wire [4:0] retire_reg_ptr;
	input wire [63:0] retire_reg_data;
	input wire retire_reg_valid;
	input wire branch_pc_valid;
	input wire took_branch;
	input wire [15:0] branch_pht_idx;
	output wire utlb_miss_req;
	output wire [51:0] utlb_miss_paddr;
	input wire tlb_rsp_valid;
	input wire [56:0] tlb_rsp;
	output reg [176:0] insn;
	output wire insn_valid;
	input wire insn_ack;
	output reg [176:0] insn_two;
	output wire insn_valid_two;
	input wire insn_ack_two;
	input wire mem_req_ack;
	output wire mem_req_valid;
	localparam L1I_NUM_SETS = 4096;
	localparam L1I_CL_LEN = 16;
	localparam L1I_CL_LEN_BITS = 128;
	localparam LG_WORDS_PER_CL = 2;
	localparam WORDS_PER_CL = 4;
	localparam N_TAG_BITS = 48;
	localparam IDX_START = 4;
	localparam IDX_STOP = 16;
	localparam WORD_START = 2;
	localparam WORD_STOP = 4;
	localparam N_FQ_ENTRIES = 8;
	localparam RETURN_STACK_ENTRIES = 4;
	localparam PHT_ENTRIES = 65536;
	localparam BTB_ENTRIES = 128;
	output wire [63:0] mem_req_addr;
	output wire [1:0] mem_req_tag;
	output wire [4:0] mem_req_opcode;
	input wire mem_rsp_valid;
	input wire [127:0] mem_rsp_load_data;
	input wire [1:0] mem_rsp_tag;
	input wire [4:0] mem_rsp_opcode;
	output wire [63:0] cache_accesses;
	output wire [63:0] cache_hits;
	reg [47:0] t_cache_tag;
	reg [47:0] r_cache_tag;
	wire [47:0] r_tag_out;
	reg r_pht_update;
	wire [1:0] r_pht_out;
	wire [1:0] r_pht_update_out;
	reg [1:0] t_pht_val;
	reg t_do_pht_wr;
	wire [15:0] n_pht_idx;
	reg [15:0] r_pht_idx;
	reg [15:0] r_pht_update_idx;
	reg r_take_br;
	reg [63:0] r_btb [127:0];
	wire [15:0] r_jump_out;
	reg [11:0] t_cache_idx;
	reg [11:0] r_cache_idx;
	wire [127:0] r_array_out;
	reg r_mem_req_valid;
	reg n_mem_req_valid;
	reg [63:0] r_mem_req_addr;
	reg [63:0] n_mem_req_addr;
	reg [176:0] r_fq [7:0];
	reg [3:0] r_fq_head_ptr;
	reg [3:0] n_fq_head_ptr;
	reg [3:0] r_fq_next_head_ptr;
	reg [3:0] n_fq_next_head_ptr;
	reg [3:0] r_fq_next_tail_ptr;
	reg [3:0] n_fq_next_tail_ptr;
	reg [3:0] r_fq_next3_tail_ptr;
	reg [3:0] n_fq_next3_tail_ptr;
	reg [3:0] r_fq_next4_tail_ptr;
	reg [3:0] n_fq_next4_tail_ptr;
	reg [3:0] r_fq_tail_ptr;
	reg [3:0] n_fq_tail_ptr;
	reg r_resteer_bubble;
	reg n_resteer_bubble;
	reg fq_full;
	reg fq_next_empty;
	reg fq_empty;
	reg fq_full2;
	reg fq_full3;
	reg fq_full4;
	reg [255:0] r_spec_return_stack;
	reg [255:0] r_arch_return_stack;
	reg [1:0] n_arch_rs_tos;
	reg [1:0] r_arch_rs_tos;
	reg [1:0] n_spec_rs_tos;
	reg [1:0] r_spec_rs_tos;
	reg [31:0] n_arch_gbl_hist;
	reg [31:0] r_arch_gbl_hist;
	reg [31:0] n_spec_gbl_hist;
	reg [31:0] r_spec_gbl_hist;
	reg [31:0] t_xor_pc_hist;
	reg [1:0] t_insn_idx;
	reg n_utlb_miss_req;
	reg r_utlb_miss_req;
	reg [51:0] n_utlb_miss_paddr;
	reg [51:0] r_utlb_miss_paddr;
	reg [63:0] n_cache_accesses;
	reg [63:0] r_cache_accesses;
	reg [63:0] n_cache_hits;
	reg [63:0] r_cache_hits;
	function [31:0] select_cl32;
		input reg [127:0] cl;
		input reg [1:0] pos;
		reg [31:0] w32;
		begin
			case (pos)
				2'd0: w32 = cl[31:0];
				2'd1: w32 = cl[63:32];
				2'd2: w32 = cl[95:64];
				2'd3: w32 = cl[127:96];
			endcase
			select_cl32 = w32;
		end
	endfunction
	function [3:0] select_pd;
		input reg [15:0] cl;
		input reg [1:0] pos;
		reg [3:0] j;
		begin
			case (pos)
				2'd0: j = cl[0+:4];
				2'd1: j = cl[4+:4];
				2'd2: j = cl[8+:4];
				2'd3: j = cl[12+:4];
			endcase
			select_pd = j;
		end
	endfunction
	function is_nop;
		input reg [31:0] insn;
		is_nop = insn == 32'd0;
	endfunction
	function [3:0] predecode;
		input reg [31:0] insn;
		reg [3:0] j;
		reg [5:0] opcode;
		reg [4:0] rt;
		reg [4:0] rs;
		begin
			j = 4'd0;
			opcode = insn[31:26];
			rt = insn[20:16];
			rs = insn[25:21];
			case (opcode)
				6'd0:
					if (insn[5:0] == 6'd8)
						j = (rs == 5'd31 ? 4'd7 : 4'd4);
					else if (insn[5:0] == 6'd9)
						j = 4'd6;
				6'd1:
					case (rt)
						'd0: j = 4'd1;
						'd1: j = 4'd1;
						'd2: j = 4'd2;
						'd3: j = 4'd2;
						'd17: j = 4'd9;
						default:
							;
					endcase
				6'd2: j = 4'd3;
				6'd3: j = 4'd5;
				6'd4: j = ((rs == 'd0) && (rt == 'd0) ? 4'd8 : 4'd1);
				6'd5: j = 4'd1;
				6'd6: j = 4'd1;
				6'd7: j = 4'd1;
				6'd17:
					if (insn[25:21] == 5'd8)
						case (insn[17:16])
							2'b00: j = 4'd1;
							2'b01: j = 4'd1;
							2'b10: j = 4'd2;
							2'b11: j = 4'd2;
						endcase
				6'd20: j = 4'd2;
				6'd21: j = 4'd2;
				6'd22: j = 4'd2;
				6'd23: j = 4'd2;
				default: j = 4'd0;
			endcase
			predecode = j;
		end
	endfunction
	reg [63:0] r_pc;
	reg [63:0] n_pc;
	reg [63:0] r_miss_pc;
	reg [63:0] n_miss_pc;
	reg [63:0] r_cache_pc;
	reg [63:0] n_cache_pc;
	reg [63:0] r_btb_pc;
	reg [2:0] n_state;
	reg [2:0] r_state;
	reg r_restart_req;
	reg n_restart_req;
	reg r_restart_ack;
	reg n_restart_ack;
	reg r_req;
	reg n_req;
	wire r_valid_out;
	reg t_miss;
	reg t_hit;
	reg t_push_insn;
	reg t_push_insn2;
	reg t_push_insn3;
	reg t_push_insn4;
	reg t_clear_fq;
	reg r_flush_req;
	reg n_flush_req;
	reg r_flush_complete;
	reg n_flush_complete;
	reg n_delay_slot;
	reg r_delay_slot;
	reg t_take_br;
	reg t_is_cflow;
	reg t_update_spec_hist;
	reg [31:0] t_insn_data;
	reg [31:0] t_insn_data2;
	reg [31:0] t_insn_data3;
	reg [31:0] t_insn_data4;
	reg [63:0] t_simm;
	reg t_is_call;
	reg t_is_ret;
	wire t_utlb_hit;
	reg [2:0] t_branch_cnt;
	reg [4:0] t_branch_marker;
	reg [4:0] t_spec_branch_marker;
	reg [2:0] t_first_branch;
	wire [56:0] t_utlb_hit_entry;
	localparam SEXT = 48;
	reg [176:0] t_insn;
	reg [176:0] t_insn2;
	reg [176:0] t_insn3;
	reg [176:0] t_insn4;
	reg [3:0] t_pd;
	reg [63:0] r_cycle;
	always @(posedge clk) r_cycle <= (reset ? 'd0 : r_cycle + 'd1);
	assign flush_complete = r_flush_complete;
	assign insn_valid = !fq_empty;
	assign insn_valid_two = !(fq_next_empty || fq_empty);
	assign restart_ack = r_restart_ack;
	assign mem_req_valid = r_mem_req_valid;
	assign mem_req_addr = r_mem_req_addr;
	assign mem_req_tag = 'd0;
	assign mem_req_opcode = 5'd4;
	assign cache_hits = r_cache_hits;
	assign cache_accesses = r_cache_accesses;
	always @(negedge clk) begin
		if (fq_full && t_push_insn)
			$stop;
		if (fq_full4 && t_push_insn4)
			$stop;
		if (fq_empty && insn_ack)
			$stop;
	end
	always @(*) begin
		n_fq_tail_ptr = r_fq_tail_ptr;
		n_fq_head_ptr = r_fq_head_ptr;
		n_fq_next_head_ptr = r_fq_next_head_ptr;
		n_fq_next_tail_ptr = r_fq_next_tail_ptr;
		n_fq_next3_tail_ptr = r_fq_next3_tail_ptr;
		n_fq_next4_tail_ptr = r_fq_next4_tail_ptr;
		fq_empty = r_fq_head_ptr == r_fq_tail_ptr;
		fq_next_empty = r_fq_next_head_ptr == r_fq_tail_ptr;
		fq_full = (r_fq_head_ptr != r_fq_tail_ptr) && (r_fq_head_ptr[2:0] == r_fq_tail_ptr[2:0]);
		fq_full2 = ((r_fq_head_ptr != r_fq_next_tail_ptr) && (r_fq_head_ptr[2:0] == r_fq_next_tail_ptr[2:0])) || fq_full;
		fq_full3 = ((r_fq_head_ptr != r_fq_next3_tail_ptr) && (r_fq_head_ptr[2:0] == r_fq_next3_tail_ptr[2:0])) || fq_full2;
		fq_full4 = ((r_fq_head_ptr != r_fq_next4_tail_ptr) && (r_fq_head_ptr[2:0] == r_fq_next4_tail_ptr[2:0])) || fq_full3;
		insn = r_fq[r_fq_head_ptr[2:0]];
		insn_two = r_fq[r_fq_next_head_ptr[2:0]];
		if (t_push_insn4) begin
			n_fq_tail_ptr = r_fq_tail_ptr + 'd4;
			n_fq_next_tail_ptr = r_fq_next_tail_ptr + 'd4;
			n_fq_next3_tail_ptr = r_fq_next3_tail_ptr + 'd4;
			n_fq_next4_tail_ptr = r_fq_next4_tail_ptr + 'd4;
		end
		else if (t_push_insn3) begin
			n_fq_tail_ptr = r_fq_tail_ptr + 'd3;
			n_fq_next_tail_ptr = r_fq_next_tail_ptr + 'd3;
			n_fq_next3_tail_ptr = r_fq_next3_tail_ptr + 'd3;
			n_fq_next4_tail_ptr = r_fq_next4_tail_ptr + 'd3;
		end
		else if (t_push_insn2) begin
			n_fq_tail_ptr = r_fq_tail_ptr + 'd2;
			n_fq_next_tail_ptr = r_fq_next_tail_ptr + 'd2;
			n_fq_next3_tail_ptr = r_fq_next3_tail_ptr + 'd2;
			n_fq_next4_tail_ptr = r_fq_next4_tail_ptr + 'd2;
		end
		else if (t_push_insn) begin
			n_fq_tail_ptr = r_fq_tail_ptr + 'd1;
			n_fq_next_tail_ptr = r_fq_next_tail_ptr + 'd1;
			n_fq_next3_tail_ptr = r_fq_next3_tail_ptr + 'd1;
			n_fq_next4_tail_ptr = r_fq_next4_tail_ptr + 'd1;
		end
		if (insn_ack && !insn_ack_two) begin
			n_fq_head_ptr = r_fq_head_ptr + 'd1;
			n_fq_next_head_ptr = r_fq_next_head_ptr + 'd1;
		end
		else if (insn_ack && insn_ack_two) begin
			n_fq_head_ptr = r_fq_head_ptr + 'd2;
			n_fq_next_head_ptr = r_fq_next_head_ptr + 'd2;
		end
	end
	always @(posedge clk)
		if (t_push_insn)
			r_fq[r_fq_tail_ptr[2:0]] <= t_insn;
		else if (t_push_insn2) begin
			r_fq[r_fq_tail_ptr[2:0]] <= t_insn;
			r_fq[r_fq_next_tail_ptr[2:0]] <= t_insn2;
		end
		else if (t_push_insn3) begin
			r_fq[r_fq_tail_ptr[2:0]] <= t_insn;
			r_fq[r_fq_next_tail_ptr[2:0]] <= t_insn2;
			r_fq[r_fq_next3_tail_ptr[2:0]] <= t_insn3;
		end
		else if (t_push_insn4) begin
			r_fq[r_fq_tail_ptr[2:0]] <= t_insn;
			r_fq[r_fq_next_tail_ptr[2:0]] <= t_insn2;
			r_fq[r_fq_next3_tail_ptr[2:0]] <= t_insn3;
			r_fq[r_fq_next4_tail_ptr[2:0]] <= t_insn4;
		end
	utlb #(1) utlb0(
		.clk(clk),
		.reset(reset),
		.flush(n_flush_complete),
		.req(n_req),
		.addr({t_cache_tag, t_cache_idx, {IDX_START {1'b0}}}),
		.tlb_rsp(tlb_rsp),
		.tlb_rsp_valid(tlb_rsp_valid),
		.hit(t_utlb_hit),
		.hit_entry(t_utlb_hit_entry)
	);
	assign utlb_miss_req = r_utlb_miss_req;
	assign utlb_miss_paddr = r_utlb_miss_paddr;
	always @(posedge clk)
		if (restart_valid && restart_src_is_indirect)
			r_btb[restart_src_pc[8:2]] <= restart_pc;
	always @(posedge clk) r_btb_pc <= (reset ? 'd0 : r_btb[n_cache_pc[8:2]]);
	reg r_dead_flush;
	reg [31:0] r_dead_count;
	always @(posedge clk)
		if (reset) begin
			r_dead_flush <= 1'b0;
			r_dead_count <= 'd0;
		end
		else begin
			if (r_dead_flush)
				r_dead_count <= (flush_complete ? 'd0 : r_dead_count + 'd1);
			if (r_dead_flush && flush_complete)
				r_dead_flush <= 1'b0;
			else if (flush_req)
				r_dead_flush <= 1'b1;
		end
	always @(negedge clk)
		if (r_dead_count > 32'd16777216) begin
			$display("no fe flush in %d cycles!, r_state = %d, fq_full = %b", r_dead_count, r_state, fq_full);
			$stop;
		end
	always @(*) begin
		n_utlb_miss_req = 1'b0;
		n_utlb_miss_paddr = r_utlb_miss_paddr;
		n_pc = r_pc;
		n_miss_pc = r_miss_pc;
		n_cache_pc = 'd0;
		n_state = r_state;
		n_restart_ack = 1'b0;
		n_flush_req = r_flush_req | flush_req;
		n_flush_complete = 1'b0;
		n_delay_slot = r_delay_slot;
		t_cache_idx = 'd0;
		t_cache_tag = 'd0;
		n_req = 1'b0;
		n_mem_req_valid = 1'b0;
		n_mem_req_addr = r_mem_req_addr;
		n_resteer_bubble = 1'b0;
		n_restart_req = restart_valid | r_restart_req;
		t_miss = r_req && !(r_valid_out && (r_tag_out == r_cache_tag));
		t_hit = r_req && (r_valid_out && (r_tag_out == r_cache_tag));
		t_insn_idx = r_cache_pc[3:WORD_START];
		t_pd = select_pd(r_jump_out, t_insn_idx);
		t_insn_data = select_cl32(r_array_out, t_insn_idx);
		t_insn_data2 = select_cl32(r_array_out, t_insn_idx + 2'd1);
		t_insn_data3 = select_cl32(r_array_out, t_insn_idx + 2'd2);
		t_insn_data4 = select_cl32(r_array_out, t_insn_idx + 2'd3);
		t_branch_marker = {1'b1, select_pd(r_jump_out, 'd3) != 4'd0, select_pd(r_jump_out, 'd2) != 4'd0, select_pd(r_jump_out, 'd1) != 4'd0, select_pd(r_jump_out, 'd0) != 4'd0} >> t_insn_idx;
		t_spec_branch_marker = ({1'b1, select_pd(r_jump_out, 'd3) != 4'd0, select_pd(r_jump_out, 'd2) != 4'd0, select_pd(r_jump_out, 'd1) != 4'd0, select_pd(r_jump_out, 'd0) != 4'd0} >> t_insn_idx) & {4'b1111, !((t_pd == 4'd1) && !r_pht_out[1])};
		t_first_branch = 'd7;
		casez (t_spec_branch_marker)
			5'bzzzz1: t_first_branch = 'd0;
			5'bzzz10: t_first_branch = 'd1;
			5'bzz100: t_first_branch = 'd2;
			5'bz1000: t_first_branch = 'd3;
			5'b10000: t_first_branch = 'd4;
			default: t_first_branch = 'd7;
		endcase
		t_branch_cnt = (({2'd0, select_pd(r_jump_out, 'd0) != 4'd0} + {2'd0, select_pd(r_jump_out, 'd1) != 4'd0}) + {2'd0, select_pd(r_jump_out, 'd2) != 4'd0}) + {2'd0, select_pd(r_jump_out, 'd3) != 4'd0};
		t_simm = {{SEXT {t_insn_data[15]}}, t_insn_data[15:0]};
		t_clear_fq = 1'b0;
		t_push_insn = 1'b0;
		t_push_insn2 = 1'b0;
		t_push_insn3 = 1'b0;
		t_push_insn4 = 1'b0;
		t_take_br = 1'b0;
		t_is_cflow = 1'b0;
		t_update_spec_hist = 1'b0;
		t_is_call = 1'b0;
		t_is_ret = 1'b0;
		case (r_state)
			3'd0:
				if (n_restart_req) begin
					n_restart_ack = 1'b1;
					n_restart_req = 1'b0;
					n_pc = restart_pc;
					n_state = 3'd1;
					t_clear_fq = 1'b1;
				end
			3'd1: begin
				t_cache_idx = r_pc[15:IDX_START];
				t_cache_tag = r_pc[63:IDX_STOP];
				n_cache_pc = r_pc;
				n_req = 1'b1;
				n_pc = r_pc + 'd4;
				if (r_resteer_bubble)
					;
				else if (n_flush_req) begin
					n_flush_req = 1'b0;
					t_clear_fq = 1'b1;
					n_state = 3'd4;
					t_cache_idx = 0;
					if (r_resteer_bubble)
						$stop;
				end
				else if (n_restart_req) begin
					n_restart_ack = 1'b1;
					n_restart_req = 1'b0;
					n_delay_slot = 1'b0;
					n_pc = restart_pc;
					n_req = 1'b0;
					n_state = 3'd1;
					t_clear_fq = 1'b1;
					if (r_resteer_bubble)
						$stop;
				end
				else if (!t_utlb_hit && (t_miss || t_hit)) begin
					n_miss_pc = r_cache_pc;
					n_pc = r_pc;
					n_utlb_miss_req = 1'b1;
					n_utlb_miss_paddr = r_cache_pc[63:12];
					n_state = 3'd6;
					if (r_resteer_bubble)
						$stop;
				end
				else if (t_miss) begin
					n_state = 3'd2;
					n_mem_req_addr = {r_cache_pc[63:4], {4 {1'b0}}};
					n_mem_req_valid = 1'b1;
					n_miss_pc = r_cache_pc;
					n_pc = r_pc;
					if (r_resteer_bubble)
						$stop;
				end
				else if (t_hit && !fq_full) begin
					t_update_spec_hist = t_pd != 4'd0;
					if ((t_pd == 4'd5) || (t_pd == 4'd3)) begin
						t_is_cflow = 1'b1;
						n_delay_slot = 1'b1;
						t_take_br = 1'b1;
						t_is_call = t_pd == 4'd5;
						n_pc = {r_cache_pc[63:28], t_insn_data[25:0], 2'd0};
					end
					else if (t_pd == 4'd8) begin
						t_is_cflow = 1'b1;
						n_delay_slot = 1'b1;
						t_take_br = 1'b1;
						n_pc = (r_cache_pc + 'd4) + {t_simm[61:0], 2'd0};
					end
					else if (t_pd == 4'd2) begin
						t_is_cflow = 1'b1;
						n_delay_slot = 1'b1;
						t_take_br = 1'b1;
						n_pc = (r_cache_pc + 'd4) + {t_simm[61:0], 2'd0};
					end
					else if (t_pd == 4'd9) begin
						if (r_pht_out[1] || (t_insn_data[25:21] == 5'd0)) begin
							t_is_cflow = 1'b1;
							n_delay_slot = 1'b1;
							n_pc = (r_cache_pc + 'd4) + {t_simm[61:0], 2'd0};
							t_is_call = 1'b1;
							t_take_br = 1'b1;
						end
					end
					else if ((t_pd == 4'd1) && r_pht_out[1]) begin
						t_is_cflow = 1'b1;
						n_delay_slot = 1'b1;
						t_take_br = 1'b1;
						n_pc = (r_cache_pc + 'd4) + {t_simm[61:0], 2'd0};
					end
					else if (t_pd == 4'd7) begin
						t_is_cflow = 1'b1;
						t_is_ret = 1'b1;
						n_delay_slot = 1'b1;
						t_take_br = 1'b1;
					        case(r_spec_rs_tos)
						  2'd0:
						    begin
						       n_pc = r_spec_return_stack[127:64];
						    end
						  2'd1:
						    begin
						       n_pc = r_spec_return_stack[191:128];
						    end
						  2'd2:
						    begin
						       n_pc = r_spec_return_stack[255:192];						       
						    end
						  2'd3:
						    begin
						       n_pc = r_spec_return_stack[63:0];
						    end
						endcase

					end
					else if ((t_pd == 4'd4) || (t_pd == 4'd6)) begin
						t_is_cflow = 1'b1;
						n_delay_slot = 1'b1;
						t_take_br = 1'b1;
						t_is_call = t_pd == 4'd6;
						n_pc = r_btb_pc;
					end
					if (r_delay_slot)
						n_delay_slot = 1'b0;
					if (!(t_is_cflow || r_delay_slot)) begin
						if (t_first_branch == 'd7)
							$stop;
						if ((t_first_branch == 'd4) && !fq_full4) begin
							t_push_insn4 = 1'b1;
							t_cache_idx = r_cache_idx + 'd1;
							n_cache_pc = r_cache_pc + 'd16;
							t_cache_tag = n_cache_pc[63:IDX_STOP];
							n_pc = r_cache_pc + 'd20;
						end
						else if ((t_first_branch == 'd3) && !fq_full3) begin
							t_push_insn3 = 1'b1;
							n_cache_pc = r_cache_pc + 'd12;
							n_pc = r_cache_pc + 'd16;
							t_cache_tag = n_cache_pc[63:IDX_STOP];
							if (t_insn_idx != 0)
								t_cache_idx = r_cache_idx + 'd1;
						end
						else if ((t_first_branch == 'd2) && !fq_full2) begin
							t_push_insn2 = 1'b1;
							n_pc = r_cache_pc + 'd8;
							n_cache_pc = r_cache_pc + 'd8;
							t_cache_tag = n_cache_pc[63:IDX_STOP];
							n_pc = r_cache_pc + 'd12;
							if (t_insn_idx == 2)
								t_cache_idx = r_cache_idx + 'd1;
						end
						else
							t_push_insn = 1'b1;
					end
					else
						t_push_insn = 1'b1;
				end
				else if (t_hit && fq_full) begin
					n_pc = r_pc;
					n_miss_pc = r_cache_pc;
					n_state = 3'd5;
					if (r_resteer_bubble)
						$stop;
				end
			end
			3'd2:
				if (mem_rsp_valid)
					n_state = 3'd3;
			3'd3: begin
				t_cache_idx = r_miss_pc[15:IDX_START];
				t_cache_tag = r_miss_pc[63:IDX_STOP];
				if (n_flush_req) begin
					n_flush_req = 1'b0;
					t_clear_fq = 1'b1;
					n_state = 3'd4;
					t_cache_idx = 0;
				end
				else if (n_restart_req) begin
					n_restart_ack = 1'b1;
					n_restart_req = 1'b0;
					n_delay_slot = 1'b0;
					n_pc = restart_pc;
					n_req = 1'b0;
					n_state = 3'd1;
					t_clear_fq = 1'b1;
				end
				else if (!fq_full) begin
					n_cache_pc = r_miss_pc;
					n_req = 1'b1;
					n_state = 3'd1;
				end
			end
			3'd4: begin
				if (r_cache_idx == 4095) begin
					n_flush_complete = 1'b1;
					n_state = 3'd0;
				end
				t_cache_idx = r_cache_idx + 'd1;
			end
			3'd5: begin
				t_cache_idx = r_miss_pc[15:IDX_START];
				t_cache_tag = r_miss_pc[63:IDX_STOP];
				n_cache_pc = r_miss_pc;
				if (!fq_full) begin
					n_req = 1'b1;
					n_state = 3'd1;
				end
				else if (n_flush_req) begin
					n_flush_req = 1'b0;
					t_clear_fq = 1'b1;
					n_state = 3'd4;
					t_cache_idx = 0;
				end
				else if (n_restart_req) begin
					n_restart_ack = 1'b1;
					n_restart_req = 1'b0;
					n_delay_slot = 1'b0;
					n_pc = restart_pc;
					n_req = 1'b0;
					n_state = 3'd1;
					t_clear_fq = 1'b1;
				end
			end
			3'd6: begin
				t_cache_idx = r_miss_pc[15:IDX_START];
				t_cache_tag = r_miss_pc[63:IDX_STOP];
				if (tlb_rsp_valid) begin
					n_cache_pc = r_miss_pc;
					n_req = 1'b1;
					n_state = (fq_full ? 3'd5 : 3'd1);
				end
			end
			default:
				;
		endcase
	end
	always @(*) begin
		n_cache_accesses = r_cache_accesses;
		n_cache_hits = r_cache_hits;
		if (t_hit)
			n_cache_hits = r_cache_hits + 'd1;
		if (r_req)
			n_cache_accesses = r_cache_accesses + 'd1;
	end
	always @(*) begin
		t_insn[176-:32] = t_insn_data;
		t_insn[144-:64] = r_cache_pc;
		t_insn[80-:64] = n_pc;
		t_insn[16] = t_take_br;
		t_insn[15-:16] = r_pht_idx;
		t_insn2[176-:32] = t_insn_data2;
		t_insn2[144-:64] = r_cache_pc + 'd4;
		t_insn2[80-:64] = 'd0;
		t_insn2[16] = 1'b0;
		t_insn2[15-:16] = 'd0;
		t_insn3[176-:32] = t_insn_data3;
		t_insn3[144-:64] = r_cache_pc + 'd8;
		t_insn3[80-:64] = 'd0;
		t_insn3[16] = 1'b0;
		t_insn3[15-:16] = 'd0;
		t_insn4[176-:32] = t_insn_data4;
		t_insn4[144-:64] = r_cache_pc + 'd12;
		t_insn4[80-:64] = 'd0;
		t_insn4[16] = 1'b0;
		t_insn4[15-:16] = 'd0;
	end
	reg t_wr_valid_ram_en = mem_rsp_valid || (r_state == 3'd4);
	reg t_valid_ram_value = r_state != 3'd4;
	reg [11:0] t_valid_ram_idx = (mem_rsp_valid ? r_mem_req_addr[15:IDX_START] : r_cache_idx);
	always @(*) t_xor_pc_hist = {n_cache_pc[25:2], 8'd0} ^ r_spec_gbl_hist;
	xor_fold #(
		.IN_W(32),
		.OUT_W(32)
	) f0(
		.in(t_xor_pc_hist),
		.out(n_pht_idx)
	);
	always @(*) begin
		t_pht_val = r_pht_update_out;
		t_do_pht_wr = r_pht_update;
		case (r_pht_update_out)
			2'd0:
				if (r_take_br)
					t_pht_val = 2'd1;
				else
					t_do_pht_wr = 1'b0;
			2'd1: t_pht_val = (r_take_br ? 2'd2 : 2'd0);
			2'd2: t_pht_val = (r_take_br ? 2'd3 : 2'd1);
			2'd3:
				if (!r_take_br)
					t_pht_val = 2'd2;
				else
					t_do_pht_wr = 1'b0;
		endcase
	end
	always @(posedge clk)
		if (reset) begin
			r_pht_idx <= 'd0;
			r_pht_update <= 1'b0;
			r_pht_update_idx <= 'd0;
			r_take_br <= 1'b0;
		end
		else begin
			r_pht_idx <= n_pht_idx;
			r_pht_update <= branch_pc_valid;
			r_pht_update_idx <= branch_pht_idx;
			r_take_br <= took_branch;
		end
	ram2r1w #(
		.WIDTH(2),
		.LG_DEPTH(16)
	) pht(
		.clk(clk),
		.rd_addr0(n_pht_idx),
		.rd_addr1(branch_pht_idx),
		.wr_addr(r_pht_update_idx),
		.wr_data(t_pht_val),
		.wr_en(t_do_pht_wr),
		.rd_data0(r_pht_out),
		.rd_data1(r_pht_update_out)
	);
	ram1r1w #(
		.WIDTH(1),
		.LG_DEPTH(12)
	) valid_array(
		.clk(clk),
		.rd_addr(t_cache_idx),
		.wr_addr(t_valid_ram_idx),
		.wr_data(t_valid_ram_value),
		.wr_en(t_wr_valid_ram_en),
		.rd_data(r_valid_out)
	);
	ram1r1w #(
		.WIDTH(N_TAG_BITS),
		.LG_DEPTH(12)
	) tag_array(
		.clk(clk),
		.rd_addr(t_cache_idx),
		.wr_addr(r_mem_req_addr[15:IDX_START]),
		.wr_data(r_mem_req_addr[63:IDX_STOP]),
		.wr_en(mem_rsp_valid),
		.rd_data(r_tag_out)
	);
	function [31:0] bswap32;
		input reg [31:0] in;
		bswap32 = {in[7:0], in[15:8], in[23:16], in[31:24]};
	endfunction
	ram1r1w #(
		.WIDTH(L1I_CL_LEN_BITS),
		.LG_DEPTH(12)
	) insn_array(
		.clk(clk),
		.rd_addr(t_cache_idx),
		.wr_addr(r_mem_req_addr[15:IDX_START]),
		.wr_data({bswap32(mem_rsp_load_data[127:96]), bswap32(mem_rsp_load_data[95:64]), bswap32(mem_rsp_load_data[63:32]), bswap32(mem_rsp_load_data[31:0])}),
		.wr_en(mem_rsp_valid),
		.rd_data(r_array_out)
	);
	ram1r1w #(
		.WIDTH(16),
		.LG_DEPTH(12)
	) pd_data(
		.clk(clk),
		.rd_addr(t_cache_idx),
		.wr_addr(r_mem_req_addr[15:IDX_START]),
		.wr_data({predecode(bswap32(mem_rsp_load_data[127:96])), predecode(bswap32(mem_rsp_load_data[95:64])), predecode(bswap32(mem_rsp_load_data[63:32])), predecode(bswap32(mem_rsp_load_data[31:0]))}),
		.wr_en(mem_rsp_valid),
		.rd_data(r_jump_out)
	);
	always @(*) begin
		n_spec_rs_tos = r_spec_rs_tos;
		if (n_restart_ack)
			n_spec_rs_tos = r_arch_rs_tos;
		else if (t_is_call)
			n_spec_rs_tos = r_spec_rs_tos - 'd1;
		else if (t_is_ret)
			n_spec_rs_tos = r_spec_rs_tos + 'd1;
	end
	always @(posedge clk)
		if (t_is_call)
			r_spec_return_stack[r_spec_rs_tos * 64+:64] <= r_cache_pc + 'd8;
		else if (n_restart_ack)
			r_spec_return_stack <= r_arch_return_stack;
	always @(posedge clk)
		if ((retire_reg_valid && retire_valid) && retired_call)
			r_arch_return_stack[r_arch_rs_tos * 64+:64] <= retire_reg_data;
	always @(*) begin
		n_arch_rs_tos = r_arch_rs_tos;
		if (retire_valid && retired_call)
			n_arch_rs_tos = r_arch_rs_tos - 'd1;
		else if (retire_valid && retired_ret)
			n_arch_rs_tos = r_arch_rs_tos + 'd1;
	end
	always @(*) begin
		n_spec_gbl_hist = r_spec_gbl_hist;
		if (n_restart_ack)
			n_spec_gbl_hist = r_arch_gbl_hist;
		else if (t_update_spec_hist)
			n_spec_gbl_hist = {r_spec_gbl_hist[30:0], t_take_br};
	end
	always @(*) begin
		n_arch_gbl_hist = r_arch_gbl_hist;
		if (branch_pc_valid)
			n_arch_gbl_hist = {r_arch_gbl_hist[30:0], took_branch};
	end
	always @(posedge clk)
		if (reset) begin
			r_state <= 3'd0;
			r_pc <= 'd0;
			r_miss_pc <= 'd0;
			r_cache_pc <= 'd0;
			r_restart_ack <= 1'b0;
			r_cache_idx <= 'd0;
			r_cache_tag <= 'd0;
			r_req <= 1'b0;
			r_mem_req_valid <= 1'b0;
			r_mem_req_addr <= 'd0;
			r_fq_head_ptr <= 'd0;
			r_fq_next_head_ptr <= 'd1;
			r_fq_next_tail_ptr <= 'd1;
			r_fq_next3_tail_ptr <= 'd1;
			r_fq_next4_tail_ptr <= 'd1;
			r_fq_tail_ptr <= 'd0;
			r_restart_req <= 1'b0;
			r_flush_req <= 1'b0;
			r_flush_complete <= 1'b0;
			r_delay_slot <= 1'b0;
			r_spec_rs_tos <= 3;
			r_arch_rs_tos <= 3;
			r_arch_gbl_hist <= 'd0;
			r_spec_gbl_hist <= 'd0;
			r_utlb_miss_req <= 1'b0;
			r_utlb_miss_paddr <= 'd0;
			r_cache_hits <= 'd0;
			r_cache_accesses <= 'd0;
			r_resteer_bubble <= 1'b0;
		end
		else begin
			r_state <= n_state;
			r_pc <= n_pc;
			r_miss_pc <= n_miss_pc;
			r_cache_pc <= n_cache_pc;
			r_restart_ack <= n_restart_ack;
			r_cache_idx <= t_cache_idx;
			r_cache_tag <= t_cache_tag;
			r_req <= n_req;
			r_mem_req_valid <= n_mem_req_valid;
			r_mem_req_addr <= n_mem_req_addr;
			r_fq_head_ptr <= (t_clear_fq ? 'd0 : n_fq_head_ptr);
			r_fq_next_head_ptr <= (t_clear_fq ? 'd1 : n_fq_next_head_ptr);
			r_fq_next_tail_ptr <= (t_clear_fq ? 'd1 : n_fq_next_tail_ptr);
			r_fq_next3_tail_ptr <= (t_clear_fq ? 'd2 : n_fq_next3_tail_ptr);
			r_fq_next4_tail_ptr <= (t_clear_fq ? 'd3 : n_fq_next4_tail_ptr);
			r_fq_tail_ptr <= (t_clear_fq ? 'd0 : n_fq_tail_ptr);
			r_restart_req <= n_restart_req;
			r_flush_req <= n_flush_req;
			r_flush_complete <= n_flush_complete;
			r_delay_slot <= n_delay_slot;
			r_spec_rs_tos <= n_spec_rs_tos;
			r_arch_rs_tos <= n_arch_rs_tos;
			r_arch_gbl_hist <= n_arch_gbl_hist;
			r_spec_gbl_hist <= n_spec_gbl_hist;
			r_utlb_miss_req <= n_utlb_miss_req;
			r_utlb_miss_paddr <= n_utlb_miss_paddr;
			r_cache_hits <= n_cache_hits;
			r_cache_accesses <= n_cache_accesses;
			r_resteer_bubble <= n_resteer_bubble;
		end
endmodule

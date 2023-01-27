module core_l1d_l1i (
	clk,
	reset,
	extern_irq,
	in_flush_mode,
	resume,
	resume_pc,
	ready_for_resume,
	mem_req_ack,
	mem_req_valid,
	mem_req_addr,
	mem_req_store_data,
	mem_req_insn,
	mem_req_tag,
	mem_req_opcode,
	mem_rsp_valid,
	mem_rsp_load_data,
	mem_rsp_tag,
	mem_rsp_opcode,
	retire_reg_ptr,
	retire_reg_data,
	retire_reg_valid,
	retire_reg_fp_valid,
	retire_reg_two_ptr,
	retire_reg_two_data,
	retire_reg_two_valid,
	retire_reg_fp_two_valid,
	retire_valid,
	retire_two_valid,
	retire_pc,
	retire_two_pc,
	monitor_req_reason,
	monitor_req_valid,
	monitor_rsp_valid,
	monitor_rsp_data_valid,
	monitor_rsp_data,
	branch_pc,
	branch_pc_valid,
	branch_fault,
	l1i_cache_accesses,
	l1i_cache_hits,
	l1d_cache_accesses,
	l1d_cache_hits,
	l1d_cache_hits_under_miss,
	got_break,
	got_syscall,
	got_ud,
	inflight,
	iside_tlb_miss,
	dside_tlb_miss
);
	localparam L1D_CL_LEN = 16;
	localparam L1D_CL_LEN_BITS = 128;
	input wire clk;
	input wire reset;
	input wire extern_irq;
	input wire resume;
	input wire [63:0] resume_pc;
	output wire in_flush_mode;
	output wire ready_for_resume;
	wire [63:0] restart_pc;
	wire [63:0] restart_src_pc;
	wire restart_src_is_indirect;
	wire restart_valid;
	wire restart_ack;
	wire [15:0] branch_pht_idx;
	wire took_branch;
	wire t_retire_delay_slot;
	wire [63:0] t_branch_pc;
	wire t_branch_pc_valid;
	wire t_branch_fault;
	output wire [63:0] branch_pc;
	output wire branch_pc_valid;
	output wire branch_fault;
	assign branch_pc = t_branch_pc;
	assign branch_pc_valid = t_branch_pc_valid;
	assign branch_fault = t_branch_fault;
	output wire [63:0] l1i_cache_accesses;
	output wire [63:0] l1i_cache_hits;
	output wire [63:0] l1d_cache_accesses;
	output wire [63:0] l1d_cache_hits;
	output wire [63:0] l1d_cache_hits_under_miss;
	input wire mem_req_ack;
	output reg mem_req_valid;
	output reg [63:0] mem_req_addr;
	output reg [127:0] mem_req_store_data;
	output reg [1:0] mem_req_tag;
	output reg mem_req_insn;
	output reg [4:0] mem_req_opcode;
	input wire mem_rsp_valid;
	input wire [127:0] mem_rsp_load_data;
	input wire [1:0] mem_rsp_tag;
	input wire [4:0] mem_rsp_opcode;
	output wire [4:0] retire_reg_ptr;
	output wire [63:0] retire_reg_data;
	output wire retire_reg_valid;
	output wire retire_reg_fp_valid;
	output wire [4:0] retire_reg_two_ptr;
	output wire [63:0] retire_reg_two_data;
	output wire retire_reg_two_valid;
	output wire retire_reg_fp_two_valid;
	output wire retire_valid;
	output wire retire_two_valid;
	output wire [63:0] retire_pc;
	output wire [63:0] retire_two_pc;
	wire retired_call;
	wire retired_ret;
	wire retired_rob_ptr_valid;
	wire retired_rob_ptr_two_valid;
	wire [4:0] retired_rob_ptr;
	wire [4:0] retired_rob_ptr_two;
	output wire [15:0] monitor_req_reason;
	output wire monitor_req_valid;
	input wire monitor_rsp_valid;
	input wire monitor_rsp_data_valid;
	input wire [63:0] monitor_rsp_data;
	output wire got_break;
	output wire got_syscall;
	output wire got_ud;
	output wire [5:0] inflight;
	output wire iside_tlb_miss;
	output wire dside_tlb_miss;
	wire [63:0] t_l1d_cache_accesses;
	wire [63:0] t_l1d_cache_hits;
	wire [63:0] t_l1d_cache_hits_under_miss;
	wire [63:0] t_l1i_cache_accesses;
	wire [63:0] t_l1i_cache_hits;
	wire head_of_rob_ptr_valid;
	wire [4:0] head_of_rob_ptr;
	wire flush_req;
	wire flush_cl_req;
	wire [63:0] flush_cl_addr;
	wire l1d_flush_complete;
	wire l1i_flush_complete;
	wire [245:0] core_mem_req;
	wire [151:0] core_mem_rsp;
	wire core_mem_req_valid;
	wire core_mem_req_ack;
	wire core_mem_rsp_valid;
	reg [1:0] n_flush_state;
	reg [1:0] r_flush_state;
	reg r_flush;
	reg n_flush;
	wire memq_empty;
	assign in_flush_mode = r_flush;
	always @(posedge clk)
		if (reset) begin
			r_flush_state <= 2'd0;
			r_flush <= 1'b0;
		end
		else begin
			r_flush_state <= n_flush_state;
			r_flush <= n_flush;
		end
	always @(*) begin
		n_flush_state = r_flush_state;
		n_flush = r_flush;
		case (r_flush_state)
			2'd0:
				if (flush_req) begin
					n_flush_state = 2'd1;
					n_flush = 1'b1;
				end
			2'd1:
				if (l1d_flush_complete && !l1i_flush_complete)
					n_flush_state = 2'd2;
				else if (!l1d_flush_complete && l1i_flush_complete)
					n_flush_state = 2'd3;
				else if (l1d_flush_complete && l1i_flush_complete) begin
					n_flush_state = 2'd0;
					n_flush = 1'b0;
				end
			2'd2:
				if (l1i_flush_complete) begin
					n_flush_state = 2'd0;
					n_flush = 1'b0;
				end
			2'd3:
				if (l1d_flush_complete) begin
					n_flush_state = 2'd0;
					n_flush = 1'b0;
				end
		endcase
	end
	assign l1d_cache_accesses = t_l1d_cache_accesses;
	assign l1d_cache_hits = t_l1d_cache_hits;
	assign l1d_cache_hits_under_miss = t_l1d_cache_hits_under_miss;
	assign l1i_cache_accesses = t_l1i_cache_accesses;
	assign l1i_cache_hits = t_l1i_cache_hits;
	wire l1d_mem_req_ack;
	wire l1d_mem_req_valid;
	wire [63:0] l1d_mem_req_addr;
	wire [127:0] l1d_mem_req_store_data;
	wire [1:0] l1d_mem_req_tag;
	wire [4:0] l1d_mem_req_opcode;
	wire l1i_mem_req_ack;
	wire l1i_mem_req_valid;
	wire [63:0] l1i_mem_req_addr;
	wire [127:0] l1i_mem_req_store_data;
	wire [1:0] l1i_mem_req_tag;
	wire [4:0] l1i_mem_req_opcode;
	reg l1d_mem_rsp_valid;
	reg l1i_mem_rsp_valid;
	reg [1:0] r_state;
	reg [1:0] n_state;
	reg r_l1d_req;
	reg n_l1d_req;
	reg r_l1i_req;
	reg n_l1i_req;
	reg r_last_gnt;
	reg n_last_gnt;
	reg n_req;
	reg r_req;
	wire insn_valid;
	wire insn_valid2;
	wire insn_ack;
	wire insn_ack2;
	wire [176:0] insn;
	wire [176:0] insn2;
	always @(*) begin
		n_state = r_state;
		n_last_gnt = r_last_gnt;
		n_l1i_req = r_l1i_req || l1i_mem_req_valid;
		n_l1d_req = r_l1d_req || l1d_mem_req_valid;
		n_req = r_req;
		mem_req_valid = n_req;
		mem_req_addr = (r_state == 2'd2 ? l1i_mem_req_addr : l1d_mem_req_addr);
		mem_req_store_data = l1d_mem_req_store_data;
		mem_req_tag = (r_state == 2'd2 ? l1i_mem_req_tag : l1d_mem_req_tag);
		mem_req_opcode = (r_state == 2'd2 ? l1i_mem_req_opcode : l1d_mem_req_opcode);
		mem_req_insn = r_state == 2'd2;
		l1d_mem_rsp_valid = 1'b0;
		l1i_mem_rsp_valid = 1'b0;
		case (r_state)
			2'd0:
				if (n_l1d_req && !n_l1i_req) begin
					n_state = 2'd1;
					n_req = 1'b1;
				end
				else if (!n_l1d_req && n_l1i_req) begin
					n_state = 2'd2;
					n_req = 1'b1;
				end
				else if (n_l1d_req && n_l1i_req) begin
					n_state = (r_last_gnt ? 2'd1 : 2'd2);
					n_req = 1'b1;
				end
			2'd1: begin
				n_last_gnt = 1'b0;
				n_l1d_req = 1'b0;
				if (mem_rsp_valid) begin
					n_req = 1'b0;
					n_state = 2'd0;
					l1d_mem_rsp_valid = 1'b1;
				end
			end
			2'd2: begin
				n_last_gnt = 1'b1;
				n_l1i_req = 1'b0;
				if (mem_rsp_valid) begin
					n_req = 1'b0;
					n_state = 2'd0;
					l1i_mem_rsp_valid = 1'b1;
				end
			end
			default:
				;
		endcase
	end
	always @(posedge clk)
		if (reset) begin
			r_state <= 2'd0;
			r_last_gnt <= 1'b0;
			r_l1d_req <= 1'b0;
			r_l1i_req <= 1'b0;
			r_req <= 1'b0;
		end
		else begin
			r_state <= n_state;
			r_last_gnt <= n_last_gnt;
			r_l1d_req <= n_l1d_req;
			r_l1i_req <= n_l1i_req;
			r_req <= n_req;
		end
	wire t_l1d_tlb_rsp_valid;
	wire t_l1i_tlb_rsp_valid;
	wire t_l1d_utlb_miss_req;
	wire t_l1i_utlb_miss_req;
	wire [51:0] t_l1d_utlb_miss_paddr;
	wire [51:0] t_l1i_utlb_miss_paddr;
	wire drain_ds_complete;
	wire [31:0] dead_rob_mask;
	wire [56:0] t_tlb_rsp;
	l1d dcache(
		.clk(clk),
		.reset(reset),
		.head_of_rob_ptr_valid(head_of_rob_ptr_valid),
		.head_of_rob_ptr(head_of_rob_ptr),
		.retired_rob_ptr_valid(retired_rob_ptr_valid),
		.retired_rob_ptr_two_valid(retired_rob_ptr_two_valid),
		.retired_rob_ptr(retired_rob_ptr),
		.retired_rob_ptr_two(retired_rob_ptr_two),
		.restart_valid(restart_valid),
		.memq_empty(memq_empty),
		.drain_ds_complete(drain_ds_complete),
		.dead_rob_mask(dead_rob_mask),
		.flush_req(flush_req),
		.flush_cl_req(flush_cl_req),
		.flush_cl_addr(flush_cl_addr),
		.flush_complete(l1d_flush_complete),
		.core_mem_req_valid(core_mem_req_valid),
		.core_mem_req(core_mem_req),
		.core_mem_req_ack(core_mem_req_ack),
		.core_mem_rsp_valid(core_mem_rsp_valid),
		.core_mem_rsp(core_mem_rsp),
		.mem_req_ack(l1d_mem_req_ack),
		.mem_req_valid(l1d_mem_req_valid),
		.mem_req_addr(l1d_mem_req_addr),
		.mem_req_store_data(l1d_mem_req_store_data),
		.mem_req_tag(l1d_mem_req_tag),
		.mem_req_opcode(l1d_mem_req_opcode),
		.mem_rsp_valid(l1d_mem_rsp_valid),
		.mem_rsp_load_data(mem_rsp_load_data),
		.mem_rsp_tag(mem_rsp_tag),
		.mem_rsp_opcode(mem_rsp_opcode),
		.utlb_miss_req(t_l1d_utlb_miss_req),
		.utlb_miss_paddr(t_l1d_utlb_miss_paddr),
		.tlb_rsp_valid(t_l1d_tlb_rsp_valid),
		.tlb_rsp(t_tlb_rsp),
		.cache_accesses(t_l1d_cache_accesses),
		.cache_hits(t_l1d_cache_hits),
		.cache_hits_under_miss(t_l1d_cache_hits_under_miss)
	);
	l1i icache(
		.clk(clk),
		.reset(reset),
		.flush_req(flush_req),
		.flush_complete(l1i_flush_complete),
		.restart_pc(restart_pc),
		.restart_src_pc(restart_src_pc),
		.restart_src_is_indirect(restart_src_is_indirect),
		.restart_valid(restart_valid),
		.restart_ack(restart_ack),
		.retire_reg_ptr(retire_reg_ptr),
		.retire_reg_data(retire_reg_data),
		.retire_reg_valid(retire_reg_valid),
		.branch_pc_valid(t_branch_pc_valid),
		.took_branch(took_branch),
		.branch_pht_idx(branch_pht_idx),
		.retire_valid(retire_valid),
		.retired_call(retired_call),
		.retired_ret(retired_ret),
		.insn(insn),
		.insn_valid(insn_valid),
		.insn_ack(insn_ack),
		.insn_two(insn2),
		.insn_valid_two(insn_valid2),
		.insn_ack_two(insn_ack2),
		.mem_req_ack(l1i_mem_req_ack),
		.mem_req_valid(l1i_mem_req_valid),
		.mem_req_addr(l1i_mem_req_addr),
		.mem_req_tag(l1i_mem_req_tag),
		.mem_req_opcode(l1i_mem_req_opcode),
		.mem_rsp_valid(l1i_mem_rsp_valid),
		.mem_rsp_load_data(mem_rsp_load_data),
		.mem_rsp_tag(mem_rsp_tag),
		.mem_rsp_opcode(mem_rsp_opcode),
		.utlb_miss_req(t_l1i_utlb_miss_req),
		.utlb_miss_paddr(t_l1i_utlb_miss_paddr),
		.tlb_rsp_valid(t_l1i_tlb_rsp_valid),
		.tlb_rsp(t_tlb_rsp),
		.cache_accesses(t_l1i_cache_accesses),
		.cache_hits(t_l1i_cache_hits)
	);
	tlb tlb0(
		.clk(clk),
		.reset(reset),
		.iside_req(t_l1i_utlb_miss_req),
		.dside_req(t_l1d_utlb_miss_req),
		.iside_paddr(t_l1i_utlb_miss_paddr),
		.dside_paddr(t_l1d_utlb_miss_paddr),
		.iside_rsp_valid(t_l1i_tlb_rsp_valid),
		.dside_rsp_valid(t_l1d_tlb_rsp_valid),
		.tlb_rsp(t_tlb_rsp),
		.tlb_hit(),
		.iside_tlb_miss(iside_tlb_miss),
		.dside_tlb_miss(dside_tlb_miss)
	);
	core cpu(
		.clk(clk),
		.reset(reset),
		.extern_irq(extern_irq),
		.resume(resume),
		.memq_empty(memq_empty),
		.drain_ds_complete(drain_ds_complete),
		.dead_rob_mask(dead_rob_mask),
		.head_of_rob_ptr_valid(head_of_rob_ptr_valid),
		.head_of_rob_ptr(head_of_rob_ptr),
		.resume_pc(resume_pc),
		.ready_for_resume(ready_for_resume),
		.flush_req(flush_req),
		.flush_cl_req(flush_cl_req),
		.flush_cl_addr(flush_cl_addr),
		.l1d_flush_complete(l1d_flush_complete),
		.l1i_flush_complete(l1i_flush_complete),
		.insn(insn),
		.insn_valid(insn_valid),
		.insn_ack(insn_ack),
		.insn_two(insn2),
		.insn_valid_two(insn_valid2),
		.insn_ack_two(insn_ack2),
		.branch_pc(t_branch_pc),
		.branch_pc_valid(t_branch_pc_valid),
		.branch_fault(t_branch_fault),
		.took_branch(took_branch),
		.branch_pht_idx(branch_pht_idx),
		.restart_pc(restart_pc),
		.restart_src_pc(restart_src_pc),
		.restart_src_is_indirect(restart_src_is_indirect),
		.restart_valid(restart_valid),
		.restart_ack(restart_ack),
		.core_mem_req_ack(core_mem_req_ack),
		.core_mem_req_valid(core_mem_req_valid),
		.core_mem_req(core_mem_req),
		.core_mem_rsp_valid(core_mem_rsp_valid),
		.core_mem_rsp(core_mem_rsp),
		.retire_reg_ptr(retire_reg_ptr),
		.retire_reg_data(retire_reg_data),
		.retire_reg_valid(retire_reg_valid),
		.retire_reg_fp_valid(retire_reg_fp_valid),
		.retire_reg_two_ptr(retire_reg_two_ptr),
		.retire_reg_two_data(retire_reg_two_data),
		.retire_reg_two_valid(retire_reg_two_valid),
		.retire_reg_fp_two_valid(retire_reg_fp_two_valid),
		.retire_valid(retire_valid),
		.retire_two_valid(retire_two_valid),
		.retire_delay_slot(t_retire_delay_slot),
		.retire_pc(retire_pc),
		.retire_two_pc(retire_two_pc),
		.retired_call(retired_call),
		.retired_ret(retired_ret),
		.retired_rob_ptr_valid(retired_rob_ptr_valid),
		.retired_rob_ptr_two_valid(retired_rob_ptr_two_valid),
		.retired_rob_ptr(retired_rob_ptr),
		.retired_rob_ptr_two(retired_rob_ptr_two),
		.monitor_req_reason(monitor_req_reason),
		.monitor_req_valid(monitor_req_valid),
		.monitor_rsp_valid(monitor_rsp_valid),
		.monitor_rsp_data_valid(monitor_rsp_data_valid),
		.monitor_rsp_data(monitor_rsp_data),
		.got_break(got_break),
		.got_syscall(got_syscall),
		.got_ud(got_ud),
		.inflight(inflight)
	);
endmodule

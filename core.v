module core (
	clk,
	reset,
	extern_irq,
	head_of_rob_ptr_valid,
	head_of_rob_ptr,
	resume,
	memq_empty,
	drain_ds_complete,
	dead_rob_mask,
	resume_pc,
	ready_for_resume,
	flush_req,
	flush_cl_req,
	flush_cl_addr,
	l1d_flush_complete,
	l1i_flush_complete,
	insn,
	insn_valid,
	insn_ack,
	insn_two,
	insn_valid_two,
	insn_ack_two,
	branch_pc,
	branch_pc_valid,
	branch_fault,
	took_branch,
	branch_pht_idx,
	restart_pc,
	restart_src_pc,
	restart_src_is_indirect,
	restart_valid,
	restart_ack,
	core_mem_req_ack,
	core_mem_req,
	core_mem_req_valid,
	core_mem_rsp,
	core_mem_rsp_valid,
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
	retire_delay_slot,
	retire_pc,
	retire_two_pc,
	retired_call,
	retired_ret,
	retired_rob_ptr_valid,
	retired_rob_ptr_two_valid,
	retired_rob_ptr,
	retired_rob_ptr_two,
	monitor_req_reason,
	monitor_req_valid,
	monitor_rsp_valid,
	monitor_rsp_data_valid,
	monitor_rsp_data,
	got_break,
	got_syscall,
	got_ud,
	inflight
);
	input wire clk;
	input wire reset;
	input wire extern_irq;
	output wire head_of_rob_ptr_valid;
	output wire [4:0] head_of_rob_ptr;
	input wire resume;
	input wire memq_empty;
	output reg drain_ds_complete;
	output wire [31:0] dead_rob_mask;
	input wire [63:0] resume_pc;
	output wire ready_for_resume;
	output wire flush_req;
	output wire flush_cl_req;
	output wire [63:0] flush_cl_addr;
	input wire l1d_flush_complete;
	input wire l1i_flush_complete;
	input wire [176:0] insn;
	input wire insn_valid;
	output wire insn_ack;
	input wire [176:0] insn_two;
	input wire insn_valid_two;
	output wire insn_ack_two;
	output wire [63:0] restart_pc;
	output wire [63:0] restart_src_pc;
	output wire restart_src_is_indirect;
	output wire restart_valid;
	input wire restart_ack;
	output wire [63:0] branch_pc;
	output wire branch_pc_valid;
	output wire branch_fault;
	output wire took_branch;
	output wire [15:0] branch_pht_idx;
	input wire core_mem_req_ack;
	output reg core_mem_req_valid;
	output reg [245:0] core_mem_req;
	input wire [151:0] core_mem_rsp;
	input wire core_mem_rsp_valid;
	output reg [4:0] retire_reg_ptr;
	output reg [63:0] retire_reg_data;
	output reg retire_reg_valid;
	output reg retire_reg_fp_valid;
	output reg [4:0] retire_reg_two_ptr;
	output reg [63:0] retire_reg_two_data;
	output reg retire_reg_two_valid;
	output reg retire_reg_fp_two_valid;
	output reg retire_valid;
	output reg retire_two_valid;
	output reg retire_delay_slot;
	output reg [63:0] retire_pc;
	output reg [63:0] retire_two_pc;
	output reg retired_call;
	output reg retired_ret;
	output reg retired_rob_ptr_valid;
	output reg retired_rob_ptr_two_valid;
	output reg [4:0] retired_rob_ptr;
	output reg [4:0] retired_rob_ptr_two;
	output wire [15:0] monitor_req_reason;
	output wire monitor_req_valid;
	input wire monitor_rsp_valid;
	input wire monitor_rsp_data_valid;
	input wire [63:0] monitor_rsp_data;
	output wire got_break;
	output wire got_syscall;
	output wire got_ud;
	output wire [5:0] inflight;
	localparam N_PRF_ENTRIES = 64;
	localparam N_ROB_ENTRIES = 32;
	localparam N_UQ_ENTRIES = 8;
	localparam N_HILO_ENTRIES = 4;
	localparam N_FCR_ENTRIES = 4;
	localparam N_DQ_ENTRIES = 4;
	localparam HI_EBITS = 32;
	reg [827:0] r_dq;
	reg [827:0] n_dq;
	reg [15:0] r_monitor_reason;
	reg [15:0] n_monitor_reason;
	reg [2:0] r_dq_head_ptr;
	reg [2:0] n_dq_head_ptr;
	reg [2:0] r_dq_next_head_ptr;
	reg [2:0] n_dq_next_head_ptr;
	reg [2:0] r_dq_next_tail_ptr;
	reg [2:0] n_dq_next_tail_ptr;
	reg [2:0] r_dq_cnt;
	reg [2:0] n_dq_cnt;
	reg [2:0] r_dq_tail_ptr;
	reg [2:0] n_dq_tail_ptr;
	reg t_dq_empty;
	reg t_dq_full;
	reg t_dq_next_empty;
	reg t_dq_next_full;
	reg r_got_restart_ack;
	reg n_got_restart_ack;
	reg [247:0] r_rob [31:0];
	reg [31:0] r_rob_complete;
	reg t_rob_head_complete;
	reg t_rob_next_head_complete;
	reg [31:0] r_rob_inflight;
	reg [31:0] r_rob_dead_insns;
	reg [31:0] t_clr_mask;
	reg [247:0] t_rob_head;
	reg [247:0] t_rob_next_head;
	reg [247:0] t_rob_tail;
	reg [247:0] t_rob_next_tail;
	reg [63:0] n_prf_free;
	reg [63:0] r_prf_free;
	reg [63:0] t_prf_free;
	reg [63:0] n_retire_prf_free;
	reg [63:0] r_retire_prf_free;
	wire [6:0] t_prf_free_cnt;
	reg [63:0] n_fp_prf_free;
	reg [63:0] r_fp_prf_free;
	reg [63:0] t_fp_prf_free;
	reg [63:0] n_retire_fp_prf_free;
	reg [63:0] r_retire_fp_prf_free;
	wire [6:0] t_fp_prf_free_cnt;
	reg [3:0] n_hilo_prf_free;
	reg [3:0] r_hilo_prf_free;
	reg [3:0] n_retire_hilo_prf_free;
	reg [3:0] r_retire_hilo_prf_free;
	reg [1:0] n_hilo_prf_entry;
	wire [2:0] t_hilo_prf_idx;
	reg [3:0] n_fcr_prf_free;
	reg [3:0] r_fcr_prf_free;
	reg [3:0] n_retire_fcr_prf_free;
	reg [3:0] r_retire_fcr_prf_free;
	reg [1:0] n_fcr_prf_entry;
	wire [2:0] t_fcr_prf_idx;
	reg [5:0] n_prf_entry;
	reg [5:0] n_prf_entry2;
	reg [5:0] n_fp_prf_entry;
	reg [5:0] n_fp_prf_entry2;
	reg [5:0] r_rob_head_ptr;
	reg [5:0] n_rob_head_ptr;
	reg [5:0] r_rob_next_head_ptr;
	reg [5:0] n_rob_next_head_ptr;
	reg [5:0] r_rob_tail_ptr;
	reg [5:0] n_rob_tail_ptr;
	reg [5:0] r_rob_next_tail_ptr;
	reg [5:0] n_rob_next_tail_ptr;
	reg [191:0] r_alloc_rat;
	reg [191:0] n_alloc_rat;
	reg [191:0] r_retire_rat;
	reg [191:0] n_retire_rat;
	reg [191:0] r_fp_alloc_rat;
	reg [191:0] n_fp_alloc_rat;
	reg [191:0] r_fp_retire_rat;
	reg [191:0] n_fp_retire_rat;
	reg [1:0] r_hilo_alloc_rat;
	reg [1:0] n_hilo_alloc_rat;
	reg [1:0] r_hilo_retire_rat;
	reg [1:0] n_hilo_retire_rat;
	reg [1:0] r_fcr_alloc_rat;
	reg [1:0] n_fcr_alloc_rat;
	reg [1:0] r_fcr_retire_rat;
	reg [1:0] n_fcr_retire_rat;
	wire [31:0] uq_wait;
	wire [31:0] mq_wait;
	wire [31:0] fq_wait;
	reg t_rob_empty;
	reg t_rob_full;
	reg t_rob_next_full;
	reg t_rob_next_empty;
	reg t_alloc;
	reg t_alloc_two;
	reg t_retire;
	reg t_retire_two;
	reg t_rat_copy;
	reg t_clr_rob;
	reg t_possible_to_alloc;
	reg t_fold_uop;
	reg t_fold_uop2;
	reg n_in_delay_slot;
	reg r_in_delay_slot;
	reg t_clr_dq;
	reg t_enough_iprfs;
	reg t_enough_hlprfs;
	reg t_enough_fprfs;
	reg t_enough_fcrprfs;
	reg t_enough_next_iprfs;
	reg t_enough_next_hlprfs;
	reg t_enough_next_fprfs;
	reg t_enough_next_fcrprfs;
	reg t_bump_rob_head;
	reg [63:0] n_restart_pc;
	reg [63:0] r_restart_pc;
	reg [63:0] n_restart_src_pc;
	reg [63:0] r_restart_src_pc;
	reg n_restart_src_is_indirect;
	reg r_restart_src_is_indirect;
	reg [63:0] n_branch_pc;
	reg [63:0] r_branch_pc;
	reg n_took_branch;
	reg r_took_branch;
	reg n_branch_valid;
	reg r_branch_valid;
	reg n_branch_fault;
	reg r_branch_fault;
	reg [15:0] n_branch_pht_idx;
	reg [15:0] r_branch_pht_idx;
	reg n_restart_valid;
	reg r_restart_valid;
	reg n_has_delay_slot;
	reg r_has_delay_slot;
	reg n_has_nullifying_delay_slot;
	reg r_has_nullifying_delay_slot;
	reg n_take_br;
	reg r_take_br;
	reg n_got_break;
	reg r_got_break;
	reg n_got_syscall;
	reg r_got_syscall;
	reg n_got_ud;
	reg r_got_ud;
	reg n_l1i_flush_complete;
	reg r_l1i_flush_complete;
	reg n_l1d_flush_complete;
	reg r_l1d_flush_complete;
	wire t_in_32fp_reg_mode;
	wire [63:0] t_cpr0_status_reg;
	reg [63:0] r_arch_a0;
	reg [4:0] n_cause;
	reg [4:0] r_cause;
	wire [137:0] t_complete_bundle_1;
	wire t_complete_valid_1;
	wire [137:0] t_complete_bundle_2;
	wire t_complete_valid_2;
	reg t_any_complete;
	reg t_free_reg;
	reg [5:0] t_free_reg_ptr;
	reg t_free_reg_two;
	reg [5:0] t_free_reg_two_ptr;
	reg t_free_fp_reg;
	reg [5:0] t_free_fp_reg_ptr;
	reg t_free_fp_two_reg;
	reg [5:0] t_free_fp_reg_two_ptr;
	reg t_free_hilo;
	reg [1:0] t_free_hilo_ptr;
	reg t_free_fcr;
	reg [1:0] t_free_fcr_ptr;
	wire [2:0] t_hilo_ffs;
	wire [2:0] t_fcr_ffs;
	wire [6:0] t_fp_ffs;
	wire [6:0] t_fp_ffs2;
	wire [6:0] t_gpr_ffs;
	wire [6:0] t_gpr_ffs2;
	wire t_uq_full;
	wire t_uq_empty;
	wire t_uq_next_full;
	wire t_uq_read;
	reg n_ready_for_resume;
	reg r_ready_for_resume;
	reg t_exception_wr_cpr0_val;
	reg [4:0] t_exception_wr_cpr0_ptr;
	reg [63:0] t_exception_wr_cpr0_data;
	wire [245:0] t_mem_req;
	wire t_mem_req_valid;
	reg t_monitor_req_valid;
	reg [63:0] r_monitor_rsp_data;
	reg [63:0] n_monitor_rsp_data;
	reg r_monitor_rsp_data_valid;
	reg n_monitor_rsp_data_valid;
	reg n_machine_clr;
	reg r_machine_clr;
	reg n_flush_req;
	reg r_flush_req;
	reg n_flush_cl_req;
	reg r_flush_cl_req;
	reg [63:0] n_flush_cl_addr;
	reg [63:0] r_flush_cl_addr;
	reg r_ds_done;
	reg n_ds_done;
	reg t_can_retire_rob_head;
	reg [4:0] n_delayslot_rob_ptr;
	reg [4:0] r_delayslot_rob_ptr;
	reg [4:0] r_state;
	reg [4:0] n_state;
	reg [31:0] r_restart_cycles;
	reg [31:0] n_restart_cycles;
	wire t_divide_ready;
	always @(*) begin
		core_mem_req_valid = t_mem_req_valid;
		core_mem_req = t_mem_req;
	end
	assign ready_for_resume = r_ready_for_resume;
	assign head_of_rob_ptr_valid = (r_state == 5'd1) || ((r_state == 5'd2) && !r_ds_done);
	assign head_of_rob_ptr = r_rob_head_ptr[4:0];
	assign flush_req = r_flush_req;
	assign flush_cl_req = r_flush_cl_req;
	assign flush_cl_addr = r_flush_cl_addr;
	assign monitor_req_reason = r_monitor_reason;
	assign monitor_req_valid = t_monitor_req_valid;
	assign got_break = r_got_break;
	assign got_syscall = r_got_syscall;
	assign got_ud = r_got_ud;
	popcount #(5) inflight0(
		.in(r_rob_inflight),
		.out(inflight)
	);
	reg [206:0] t_uop;
	wire [206:0] t_dec_uop;
	reg [206:0] t_alloc_uop;
	reg [206:0] t_uop2;
	wire [206:0] t_dec_uop2;
	reg [206:0] t_alloc_uop2;
	assign insn_ack = (!t_dq_full && insn_valid) && (r_state == 5'd1);
	assign insn_ack_two = (((!t_dq_full && insn_valid) && !t_dq_next_full) && insn_valid_two) && (r_state == 5'd1);
	assign restart_pc = r_restart_pc;
	assign restart_src_pc = r_restart_src_pc;
	assign restart_src_is_indirect = r_restart_src_is_indirect;
	assign dead_rob_mask = r_rob_dead_insns;
	assign restart_valid = r_restart_valid;
	assign branch_pc = r_branch_pc;
	assign branch_pc_valid = r_branch_valid;
	assign branch_fault = r_branch_fault;
	assign branch_pht_idx = r_branch_pht_idx;
	assign took_branch = r_took_branch;
	reg [63:0] r_cycle;
	always @(posedge clk) r_cycle <= (reset ? 'd0 : r_cycle + 'd1);
	always @(posedge clk)
		if (reset) begin
			r_flush_req <= 1'b0;
			r_flush_cl_req <= 1'b0;
			r_flush_cl_addr <= 'd0;
			r_restart_pc <= 'd0;
			r_restart_src_pc <= 'd0;
			r_restart_src_is_indirect <= 1'b0;
			r_branch_pc <= 'd0;
			r_took_branch <= 1'b0;
			r_branch_valid <= 1'b0;
			r_branch_fault <= 1'b0;
			r_branch_pht_idx <= 'd0;
			r_in_delay_slot <= 1'b0;
			r_restart_valid <= 1'b0;
			r_has_delay_slot <= 1'b0;
			r_has_nullifying_delay_slot <= 1'b0;
			r_take_br <= 1'b0;
			r_monitor_rsp_data <= 'd0;
			r_monitor_rsp_data_valid <= 1'b0;
			r_got_break <= 1'b0;
			r_got_syscall <= 1'b0;
			r_got_ud <= 1'b0;
			r_ready_for_resume <= 1'b0;
			r_l1i_flush_complete <= 1'b0;
			r_l1d_flush_complete <= 1'b0;
			r_ds_done <= 1'b0;
			drain_ds_complete <= 1'b0;
		end
		else begin
			r_flush_req <= n_flush_req;
			r_flush_cl_req <= n_flush_cl_req;
			r_flush_cl_addr <= n_flush_cl_addr;
			r_restart_pc <= n_restart_pc;
			r_restart_src_pc <= n_restart_src_pc;
			r_restart_src_is_indirect <= n_restart_src_is_indirect;
			r_branch_pc <= n_branch_pc;
			r_took_branch <= n_took_branch;
			r_branch_valid <= n_branch_valid;
			r_branch_fault <= n_branch_fault;
			r_branch_pht_idx <= n_branch_pht_idx;
			r_in_delay_slot <= n_in_delay_slot;
			r_restart_valid <= n_restart_valid;
			r_has_delay_slot <= n_has_delay_slot;
			r_has_nullifying_delay_slot <= n_has_nullifying_delay_slot;
			r_take_br <= n_take_br;
			r_monitor_rsp_data <= n_monitor_rsp_data;
			r_monitor_rsp_data_valid <= n_monitor_rsp_data_valid;
			r_got_break <= n_got_break;
			r_got_syscall <= n_got_syscall;
			r_got_ud <= n_got_ud;
			r_ready_for_resume <= n_ready_for_resume;
			r_l1i_flush_complete <= n_l1i_flush_complete;
			r_l1d_flush_complete <= n_l1d_flush_complete;
			r_ds_done <= n_ds_done;
			drain_ds_complete <= r_ds_done;
		end
	always @(posedge clk)
		if (reset) begin
			r_state <= 5'd0;
			r_restart_cycles <= 'd0;
			r_machine_clr <= 1'b0;
			r_delayslot_rob_ptr <= 'd0;
			r_got_restart_ack <= 1'b0;
			r_cause <= 5'd0;
		end
		else begin
			r_state <= n_state;
			r_restart_cycles <= n_restart_cycles;
			r_machine_clr <= n_machine_clr;
			r_delayslot_rob_ptr <= n_delayslot_rob_ptr;
			r_got_restart_ack <= n_got_restart_ack;
			r_cause <= n_cause;
		end
	always @(posedge clk)
		if (reset)
			r_arch_a0 <= 'd0;
		else if ((t_rob_head[236] && t_retire) && (t_rob_head[229-:5] == 'd4))
			r_arch_a0 <= t_rob_head[79-:64];
	always @(posedge clk)
		if (reset) begin
			retire_reg_ptr <= 'd0;
			retire_reg_data <= 'd0;
			retire_reg_valid <= 1'b0;
			retire_reg_fp_valid <= 1'b0;
			retire_reg_two_ptr <= 'd0;
			retire_reg_two_data <= 'd0;
			retire_reg_two_valid <= 1'b0;
			retire_valid <= 1'b0;
			retire_two_valid <= 1'b0;
			retire_pc <= 'd0;
			retire_two_pc <= 'd0;
			retire_delay_slot <= 1'b0;
			retired_call <= 1'b0;
			retired_ret <= 1'b0;
			retired_rob_ptr_valid <= 1'b0;
			retired_rob_ptr_two_valid <= 1'b0;
			retired_rob_ptr <= 'd0;
			retired_rob_ptr_two <= 'd0;
			r_monitor_reason <= 16'd0;
		end
		else begin
			retire_reg_ptr <= t_rob_head[229-:5];
			retire_reg_data <= t_rob_head[79-:64];
			retire_reg_valid <= t_rob_head[236] && t_retire;
			retire_reg_fp_valid <= t_rob_head[233] && t_retire;
			retire_reg_two_ptr <= t_rob_next_head[229-:5];
			retire_reg_two_data <= t_rob_next_head[79-:64];
			retire_reg_two_valid <= t_rob_next_head[236] && t_retire_two;
			retire_reg_fp_two_valid <= t_rob_next_head[233] && t_retire_two;
			retire_valid <= t_retire;
			retire_two_valid <= t_retire_two;
			retire_pc <= t_rob_head[212-:64];
			retire_two_pc <= t_rob_next_head[212-:64];
			retire_delay_slot <= t_rob_head[230] && t_retire;
			retired_ret <= t_rob_head[240] && t_retire;
			retired_call <= t_rob_head[239] && t_retire;
			retired_rob_ptr_valid <= t_retire;
			retired_rob_ptr_two_valid <= t_retire_two;
			retired_rob_ptr <= r_rob_head_ptr[4:0];
			retired_rob_ptr_two <= r_rob_next_head_ptr[4:0];
			r_monitor_reason <= n_monitor_reason;
		end
	reg t_restart_complete;
	reg t_clr_extern_irq;
	reg r_extern_irq;
	always @(posedge clk)
		if (reset)
			r_extern_irq <= 1'b0;
		else if (t_clr_extern_irq)
			r_extern_irq <= 1'b0;
		else if (extern_irq)
			r_extern_irq <= 1'b1;
	always @(*) begin
		t_clr_extern_irq = 1'b0;
		t_restart_complete = 1'b0;
		t_exception_wr_cpr0_val = 1'b0;
		t_exception_wr_cpr0_ptr = 5'd0;
		t_exception_wr_cpr0_data = 64'd0;
		n_cause = r_cause;
		n_machine_clr = r_machine_clr;
		n_delayslot_rob_ptr = r_delayslot_rob_ptr;
		t_alloc = 1'b0;
		t_alloc_two = 1'b0;
		t_possible_to_alloc = 1'b0;
		n_in_delay_slot = r_in_delay_slot;
		t_retire = 1'b0;
		t_retire_two = 1'b0;
		t_rat_copy = 1'b0;
		t_clr_rob = 1'b0;
		t_clr_dq = 1'b0;
		n_state = r_state;
		n_restart_cycles = r_restart_cycles + 'd1;
		n_restart_pc = r_restart_pc;
		n_restart_src_pc = r_restart_src_pc;
		n_restart_src_is_indirect = r_restart_src_is_indirect;
		n_restart_valid = 1'b0;
		n_has_delay_slot = r_has_delay_slot;
		n_has_nullifying_delay_slot = r_has_nullifying_delay_slot;
		n_take_br = r_take_br;
		t_bump_rob_head = 1'b0;
		t_monitor_req_valid = 1'b0;
		n_monitor_rsp_data = r_monitor_rsp_data;
		n_monitor_rsp_data_valid = r_monitor_rsp_data_valid;
		t_enough_iprfs = !(t_uop[168] && (r_prf_free == 'd0));
		t_enough_hlprfs = !(t_uop[165] && (r_hilo_prf_free == 'd0));
		t_enough_fprfs = !(t_uop[167] && (r_fp_prf_free == 'd0));
		t_enough_fcrprfs = !(t_uop[166] && (r_fcr_prf_free == 'd0));
		t_enough_next_iprfs = !(t_uop2[168] && (t_prf_free_cnt == 'd1));
		t_enough_next_hlprfs = !t_uop2[165];
		t_enough_next_fprfs = !(t_uop2[167] && (t_fp_prf_free_cnt == 'd1));
		t_enough_next_fcrprfs = !t_uop2[166];
		t_fold_uop = (((t_uop[206-:8] == 8'd156) || (t_uop[206-:8] == 8'd39)) || (t_uop[206-:8] == 8'd160)) || (t_uop[206-:8] == 8'd150);
		t_fold_uop2 = (((t_uop2[206-:8] == 8'd156) || (t_uop2[206-:8] == 8'd39)) || (t_uop2[206-:8] == 8'd160)) || (t_uop2[206-:8] == 8'd150);
		n_ds_done = r_ds_done;
		n_flush_req = 1'b0;
		n_flush_cl_req = 1'b0;
		n_flush_cl_addr = r_flush_cl_addr;
		n_got_break = r_got_break;
		n_got_syscall = r_got_syscall;
		n_got_ud = r_got_ud;
		n_monitor_reason = r_monitor_reason;
		n_got_restart_ack = r_got_restart_ack;
		n_ready_for_resume = 1'b0;
		n_l1i_flush_complete = r_l1i_flush_complete || l1i_flush_complete;
		n_l1d_flush_complete = r_l1d_flush_complete || l1d_flush_complete;
		if (r_state == 5'd1)
			n_got_restart_ack = 1'b0;
		else if (!r_got_restart_ack)
			n_got_restart_ack = restart_ack;
		t_can_retire_rob_head = 1'b0;
		if (t_rob_head_complete && !t_rob_empty)
			t_can_retire_rob_head = ((t_rob_head[232] || t_rob_head[231]) && t_rob_head[247] ? !t_rob_next_empty : 1'b1);
		case (r_state)
			5'd1:
				if ((r_extern_irq && !t_rob_empty) && !t_rob_head[230]) begin
					n_state = 5'd16;
					n_restart_pc = t_rob_head[212-:64];
					n_machine_clr = 1'b1;
					n_ds_done = 1'b1;
					t_clr_extern_irq = 1'b1;
					n_restart_valid = 1'b1;
				end
				else if (t_can_retire_rob_head) begin
					if (t_rob_head[247]) begin
						if (t_rob_head[237]) begin
							n_got_break = 1'b1;
							n_flush_req = 1'b1;
							n_cause = 5'd9;
							n_state = 5'd13;
						end
						else if (t_rob_head[81]) begin
							n_got_break = 1'b1;
							n_flush_req = 1'b1;
							n_cause = 5'd9;
							n_state = 5'd13;
						end
						else if (t_rob_head[246]) begin
							n_got_ud = 1'b1;
							n_flush_req = 1'b1;
							n_cause = 5'd10;
							n_state = 5'd13;
						end
						else if (t_rob_head[245]) begin
							n_flush_req = 1'b1;
							n_cause = 5'd13;
							n_state = 5'd13;
						end
						else if (t_rob_head[244]) begin
							n_flush_req = 1'b1;
							n_cause = (t_rob_head[241] ? 5'd3 : 5'd2);
							n_state = 5'd15;
						end
						else begin
							n_ds_done = !t_rob_head[232];
							n_state = 5'd2;
							n_restart_cycles = 'd1;
							n_restart_valid = 1'b1;
						end
						n_machine_clr = 1'b1;
						n_delayslot_rob_ptr = r_rob_next_head_ptr[4:0];
						n_restart_pc = t_rob_head[148-:64];
						n_restart_src_pc = t_rob_head[212-:64];
						n_restart_src_is_indirect = t_rob_head[83] && !t_rob_head[240];
						n_has_delay_slot = t_rob_head[232];
						n_has_nullifying_delay_slot = t_rob_head[231];
						n_take_br = t_rob_head[82];
						t_bump_rob_head = 1'b1;
					end
					else if (!t_dq_empty)
						if (t_uop[23]) begin
							if (t_rob_empty) begin
								n_state = ((t_uop[206-:8] == 8'd155) || (t_uop[206-:8] == 8'd8) ? 5'd7 : 5'd5);
								n_monitor_reason = t_uop[156-:16];
							end
						end
						else begin
							t_possible_to_alloc = (!t_rob_full && !t_uq_full) && !t_dq_empty;
							t_alloc = (((((!t_rob_full && !t_uq_full) && !t_dq_empty) && t_enough_iprfs) && t_enough_hlprfs) && t_enough_fprfs) && t_enough_fcrprfs;
							t_alloc_two = (((((((t_alloc && !t_uop2[23]) && !t_dq_next_empty) && !t_rob_next_full) && !t_uq_next_full) && t_enough_next_iprfs) && t_enough_next_hlprfs) && t_enough_next_fprfs) && t_enough_next_fcrprfs;
						end
					t_retire = t_rob_head_complete;
					t_retire_two = ((((((((!t_rob_next_empty && !t_rob_head[247]) && !t_rob_next_head[247]) && t_rob_head_complete) && t_rob_next_head_complete) && !t_rob_head[84]) && !t_rob_next_head[240]) && !t_rob_next_head[239]) && !t_rob_next_head[234]) && !t_rob_next_head[235];
				end
				else if (!t_dq_empty)
					if (t_uop[23] && t_rob_empty) begin
						if (t_uop[206-:8] == 8'd155) begin
							n_monitor_reason = t_uop[156-:16];
							case (t_uop[156-:16])
								'd50: n_state = 5'd7;
								'd52: begin
									n_state = 5'd6;
									n_l1i_flush_complete = 1'b1;
									n_flush_cl_addr = r_arch_a0;
									n_flush_cl_req = 1'b1;
								end
								'd53: n_state = 5'd7;
								default: begin
									n_flush_req = 1'b1;
									n_state = 5'd6;
								end
							endcase
						end
						else if (t_uop[206-:8] == 8'd8) begin
							n_flush_req = 1'b1;
							n_state = 5'd6;
						end
						else
							n_state = 5'd5;
					end
					else if (!t_uop[23]) begin
						t_possible_to_alloc = (!t_rob_full && !t_uq_full) && !t_dq_empty;
						t_alloc = ((((((!t_rob_full && !t_uop[23]) && !t_uq_full) && !t_dq_empty) && t_enough_iprfs) && t_enough_hlprfs) && t_enough_fprfs) && t_enough_fcrprfs;
						t_alloc_two = (((((((t_alloc && !t_uop2[23]) && !t_dq_next_empty) && !t_rob_next_full) && !t_uq_next_full) && t_enough_next_iprfs) && t_enough_next_hlprfs) && t_enough_next_fprfs) && t_enough_next_fcrprfs;
					end
			5'd2: begin
				if ((r_has_nullifying_delay_slot && t_rob_head_complete) && !r_ds_done) begin
					t_retire = r_take_br;
					n_ds_done = 1'b1;
				end
				else if ((r_has_delay_slot && t_rob_head_complete) && !r_ds_done) begin
					t_retire = 1'b1;
					n_ds_done = 1'b1;
				end
				if ((((r_rob_inflight == 'd0) && r_ds_done) && memq_empty) && t_divide_ready)
					n_state = 5'd3;
			end
			5'd16:
				if (((r_rob_inflight == 'd0) && memq_empty) && t_divide_ready)
					n_state = 5'd3;
			5'd3: begin
				t_rat_copy = 1'b1;
				t_clr_rob = 1'b1;
				t_clr_dq = 1'b1;
				n_machine_clr = 1'b0;
				if (n_got_restart_ack) begin
					n_state = 5'd1;
					n_ds_done = 1'b0;
					t_restart_complete = 1'b1;
				end
			end
			5'd5: begin
				t_alloc = ((!t_rob_full && !t_uq_full) && (r_prf_free != 'd0)) && !t_dq_empty;
				n_state = (t_alloc ? 5'd12 : 5'd5);
			end
			5'd12:
				if (t_rob_head_complete) begin
					t_clr_dq = 1'b1;
					n_restart_pc = t_rob_head[148-:64];
					n_restart_src_pc = t_rob_head[212-:64];
					n_restart_src_is_indirect = 1'b0;
					n_restart_valid = 1'b1;
					if (n_got_restart_ack)
						n_state = 5'd1;
				end
			5'd6:
				if (n_l1i_flush_complete && n_l1d_flush_complete) begin
					n_state = 5'd7;
					n_l1i_flush_complete = 1'b0;
					n_l1d_flush_complete = 1'b0;
				end
			5'd7: begin
				t_monitor_req_valid = 1'b1;
				if (monitor_rsp_valid) begin
					n_state = 5'd8;
					n_monitor_rsp_data = monitor_rsp_data;
					n_monitor_rsp_data_valid = monitor_rsp_data_valid;
				end
			end
			5'd8: begin
				t_alloc = ((!t_rob_full && !t_uq_full) && (r_prf_free != 'd0)) && !t_dq_empty;
				n_state = 5'd9;
			end
			5'd9:
				if (t_rob_head_complete) begin
					t_clr_dq = 1'b1;
					n_restart_pc = t_rob_head[148-:64];
					n_restart_src_pc = t_rob_head[212-:64];
					n_restart_src_is_indirect = 1'b0;
					n_restart_valid = 1'b1;
					if (n_got_restart_ack) begin
						t_retire = 1'b1;
						n_state = 5'd1;
					end
				end
			5'd10:
				if (n_l1i_flush_complete && n_l1d_flush_complete) begin
					n_state = 5'd0;
					n_ready_for_resume = 1'b1;
					n_l1i_flush_complete = 1'b0;
					n_l1d_flush_complete = 1'b0;
				end
			5'd0:
				if (resume) begin
					n_restart_pc = resume_pc;
					n_restart_src_pc = t_rob_head[212-:64];
					n_restart_src_is_indirect = 1'b0;
					n_restart_valid = 1'b1;
					n_state = 5'd11;
					n_got_break = 1'b0;
					n_got_ud = 1'b0;
					n_got_syscall = 1'b0;
					t_clr_dq = 1'b1;
				end
				else
					n_ready_for_resume = 1'b1;
			5'd11:
				if (n_got_restart_ack)
					n_state = 5'd1;
			5'd13: begin
				t_exception_wr_cpr0_val = 1'b1;
				t_exception_wr_cpr0_ptr = 5'd14;
				t_exception_wr_cpr0_data = (t_rob_head[230] ? t_rob_head[212-:64] - 'd4 : t_rob_head[212-:64]);
				n_state = 5'd14;
			end
			5'd14: begin
				t_exception_wr_cpr0_val = 1'b1;
				t_exception_wr_cpr0_ptr = 5'd13;
				t_exception_wr_cpr0_data = {32'd0, t_rob_head[230], 15'd0, 8'd0, 1'b0, r_cause, 2'b00};
				n_state = 5'd10;
			end
			5'd15: begin
				t_exception_wr_cpr0_val = 1'b1;
				t_exception_wr_cpr0_ptr = 5'd8;
				t_exception_wr_cpr0_data = t_rob_head[79-:64];
				n_state = 5'd13;
			end
			default:
				;
		endcase
		if (t_alloc)
			n_in_delay_slot = (t_alloc_two ? t_uop2[158] : t_uop[158]);
		else if (t_clr_dq || t_clr_rob)
			n_in_delay_slot = 1'b0;
	end
	always @(posedge clk)
		if (reset) begin
			r_rob_head_ptr <= 'd0;
			r_rob_tail_ptr <= 'd0;
			r_rob_next_head_ptr <= 'd1;
			r_rob_next_tail_ptr <= 'd1;
		end
		else begin
			r_rob_head_ptr <= n_rob_head_ptr;
			r_rob_tail_ptr <= n_rob_tail_ptr;
			r_rob_next_head_ptr <= n_rob_next_head_ptr;
			r_rob_next_tail_ptr <= n_rob_next_tail_ptr;
		end
	always @(posedge clk)
		if (reset) begin
			r_hilo_alloc_rat <= 'd0;
			r_hilo_retire_rat <= 'd0;
			r_fcr_alloc_rat <= 'd0;
			r_fcr_retire_rat <= 'd0;
		end
		else begin
			r_hilo_alloc_rat <= (t_rat_copy ? r_hilo_retire_rat : n_hilo_alloc_rat);
			r_hilo_retire_rat <= n_hilo_retire_rat;
			r_fcr_alloc_rat <= (t_rat_copy ? r_fcr_retire_rat : n_fcr_alloc_rat);
			r_fcr_retire_rat <= n_fcr_retire_rat;
		end
	always @(posedge clk)
		if (reset) begin : sv2v_autoblock_1
			reg [5:0] i_rat;
			for (i_rat = 'd0; i_rat < 'd32; i_rat = i_rat + 'd1)
				begin
					r_alloc_rat[i_rat[4:0] * 6+:6] <= i_rat;
					r_retire_rat[i_rat[4:0] * 6+:6] <= i_rat;
					r_fp_alloc_rat[i_rat[4:0] * 6+:6] <= i_rat;
					r_fp_retire_rat[i_rat[4:0] * 6+:6] <= i_rat;
				end
		end
		else begin
			r_alloc_rat <= (t_rat_copy ? r_retire_rat : n_alloc_rat);
			r_retire_rat <= n_retire_rat;
			r_fp_alloc_rat <= (t_rat_copy ? r_fp_retire_rat : n_fp_alloc_rat);
			r_fp_retire_rat <= n_fp_retire_rat;
		end
	always @(*) begin
		n_alloc_rat = r_alloc_rat;
		n_hilo_alloc_rat = r_hilo_alloc_rat;
		n_fp_alloc_rat = r_fp_alloc_rat;
		n_fcr_alloc_rat = r_fcr_alloc_rat;
		t_alloc_uop = t_uop;
		t_alloc_uop2 = t_uop2;
		if (t_uop[192] || t_uop[191])
			t_alloc_uop[198-:6] = (t_uop[191] ? r_fp_alloc_rat[t_uop[197:193] * 6+:6] : r_alloc_rat[t_uop[197:193] * 6+:6]);
		if (t_uop[184] || t_uop[183])
			t_alloc_uop[190-:6] = (t_uop[183] ? r_fp_alloc_rat[t_uop[189:185] * 6+:6] : r_alloc_rat[t_uop[189:185] * 6+:6]);
		if (t_uop[176] || t_uop[175])
			t_alloc_uop[182-:6] = (t_uop[175] ? r_fp_alloc_rat[t_uop[181:177] * 6+:6] : r_alloc_rat[t_uop[181:177] * 6+:6]);
		if (t_uop[161])
			t_alloc_uop[160-:2] = r_hilo_alloc_rat;
		else if (t_uop[162])
			t_alloc_uop[160-:2] = r_fcr_alloc_rat;
		if (t_uop2[192] || t_uop2[191])
			t_alloc_uop2[198-:6] = (t_uop2[191] ? (t_uop[167] && (t_uop2[197:193] == t_uop[173:169]) ? n_fp_prf_entry : r_fp_alloc_rat[t_uop2[197:193] * 6+:6]) : (t_uop[168] && (t_uop2[197:193] == t_uop[173:169]) ? n_prf_entry : r_alloc_rat[t_uop2[197:193] * 6+:6]));
		if (t_uop2[184] || t_uop2[183])
			t_alloc_uop2[190-:6] = (t_uop2[183] ? (t_uop[167] && (t_uop2[189:185] == t_uop[173:169]) ? n_fp_prf_entry : r_fp_alloc_rat[t_uop2[189:185] * 6+:6]) : (t_uop[168] && (t_uop2[189:185] == t_uop[173:169]) ? n_prf_entry : r_alloc_rat[t_uop2[189:185] * 6+:6]));
		if (t_uop2[176] || t_uop2[175])
			t_alloc_uop2[182-:6] = (t_uop2[175] ? (t_uop[167] && (t_uop2[181:177] == t_uop[173:169]) ? n_fp_prf_entry : r_fp_alloc_rat[t_uop2[181:177] * 6+:6]) : (t_uop[168] && (t_uop2[181:177] == t_uop[173:169]) ? n_prf_entry : r_alloc_rat[t_uop2[181:177] * 6+:6]));
		if (t_uop2[161])
			t_alloc_uop2[160-:2] = (t_uop[165] ? n_hilo_prf_entry : r_hilo_alloc_rat);
		else if (t_uop2[162])
			t_alloc_uop2[160-:2] = (t_uop[166] ? n_fcr_prf_entry : r_fcr_alloc_rat);
		if (t_alloc) begin
			if (t_uop[168]) begin
				n_alloc_rat[t_uop[173:169] * 6+:6] = n_prf_entry;
				t_alloc_uop[174-:6] = n_prf_entry;
			end
			else if (t_uop[165]) begin
				n_hilo_alloc_rat = n_hilo_prf_entry;
				t_alloc_uop[164-:2] = n_hilo_prf_entry;
			end
			else if (t_uop[166]) begin
				n_fcr_alloc_rat = n_fcr_prf_entry;
				t_alloc_uop[164-:2] = n_fcr_prf_entry;
			end
			else if (t_uop[167]) begin
				n_fp_alloc_rat[t_uop[173:169] * 6+:6] = n_fp_prf_entry;
				t_alloc_uop[174-:6] = n_fp_prf_entry;
			end
			t_alloc_uop[28-:5] = r_rob_tail_ptr[4:0];
		end
		if (t_alloc_two) begin
			if (t_uop2[168]) begin
				n_alloc_rat[t_uop2[173:169] * 6+:6] = n_prf_entry2;
				t_alloc_uop2[174-:6] = n_prf_entry2;
			end
			else if (t_uop2[167]) begin
				n_fp_alloc_rat[t_uop2[173:169] * 6+:6] = n_fp_prf_entry2;
				t_alloc_uop2[174-:6] = n_fp_prf_entry2;
			end
			t_alloc_uop2[28-:5] = r_rob_next_tail_ptr[4:0];
		end
	end
	always @(*) begin
		n_retire_rat = r_retire_rat;
		n_hilo_retire_rat = r_hilo_retire_rat;
		n_fp_retire_rat = r_fp_retire_rat;
		n_fcr_retire_rat = r_fcr_retire_rat;
		t_free_reg = 1'b0;
		t_free_reg_ptr = 'd0;
		t_free_reg_two = 1'b0;
		t_free_reg_two_ptr = 'd0;
		t_free_fp_reg = 1'b0;
		t_free_fp_reg_ptr = 'd0;
		t_free_fp_two_reg = 1'b0;
		t_free_fp_reg_two_ptr = 'd0;
		t_free_hilo = 1'b0;
		t_free_hilo_ptr = 'd0;
		t_free_fcr = 1'b0;
		t_free_fcr_ptr = 'd0;
		n_retire_prf_free = r_retire_prf_free;
		n_retire_hilo_prf_free = r_retire_hilo_prf_free;
		n_retire_fcr_prf_free = r_retire_fcr_prf_free;
		n_retire_fp_prf_free = r_retire_fp_prf_free;
		n_branch_pc = {{HI_EBITS {1'b0}}, 32'd0};
		n_took_branch = 1'b0;
		n_branch_valid = 1'b0;
		n_branch_fault = 1'b0;
		n_branch_pht_idx = 'd0;
		if (t_retire) begin
			if (t_rob_head[236]) begin
				t_free_reg = 1'b1;
				t_free_reg_ptr = t_rob_head[218-:6];
				n_retire_rat[t_rob_head[229-:5] * 6+:6] = t_rob_head[224-:6];
				n_retire_prf_free[t_rob_head[224-:6]] = 1'b0;
				n_retire_prf_free[t_rob_head[218-:6]] = 1'b1;
			end
			else if (t_rob_head[235]) begin
				t_free_hilo = 1'b1;
				t_free_hilo_ptr = t_rob_head[214:213];
				n_hilo_retire_rat = t_rob_head[220:219];
				n_retire_hilo_prf_free[t_rob_head[220:219]] = 1'b0;
				n_retire_hilo_prf_free[t_rob_head[214:213]] = 1'b1;
			end
			else if (t_rob_head[234]) begin
				t_free_fcr = 1'b1;
				t_free_fcr_ptr = t_rob_head[214:213];
				n_fcr_retire_rat = t_rob_head[220:219];
				n_retire_fcr_prf_free[t_rob_head[220:219]] = 1'b0;
				n_retire_fcr_prf_free[t_rob_head[214:213]] = 1'b1;
			end
			else if (t_rob_head[233]) begin
				t_free_fp_reg = 1'b1;
				t_free_fp_reg_ptr = t_rob_head[218-:6];
				n_fp_retire_rat[t_rob_head[229-:5] * 6+:6] = t_rob_head[224-:6];
				n_retire_fp_prf_free[t_rob_head[224-:6]] = 1'b0;
				n_retire_fp_prf_free[t_rob_head[218-:6]] = 1'b1;
			end
			if (t_retire_two && t_rob_next_head[236]) begin
				t_free_reg_two = 1'b1;
				t_free_reg_two_ptr = t_rob_next_head[218-:6];
				n_retire_rat[t_rob_next_head[229-:5] * 6+:6] = t_rob_next_head[224-:6];
				n_retire_prf_free[t_rob_next_head[224-:6]] = 1'b0;
				n_retire_prf_free[t_rob_next_head[218-:6]] = 1'b1;
			end
			if (t_retire_two && t_rob_next_head[233]) begin
				t_free_fp_two_reg = 1'b1;
				t_free_fp_reg_two_ptr = t_rob_next_head[218-:6];
				n_fp_retire_rat[t_rob_next_head[229-:5] * 6+:6] = t_rob_next_head[224-:6];
				n_retire_fp_prf_free[t_rob_next_head[224-:6]] = 1'b0;
				n_retire_fp_prf_free[t_rob_next_head[218-:6]] = 1'b1;
			end
			n_branch_pc = (t_retire_two ? t_rob_next_head[212-:64] : t_rob_head[212-:64]);
			n_took_branch = (t_retire_two ? t_rob_next_head[82] : t_rob_head[82]);
			n_branch_valid = (t_retire_two ? t_rob_next_head[84] : t_rob_head[84]);
			n_branch_fault = t_rob_head[247];
			n_branch_pht_idx = (t_retire_two ? t_rob_next_head[15-:16] : t_rob_head[15-:16]);
		end
	end
	always @(*) begin
		t_rob_tail[247] = 1'b0;
		t_rob_tail[236] = 1'b0;
		t_rob_tail[235] = 1'b0;
		t_rob_tail[234] = 1'b0;
		t_rob_tail[233] = 1'b0;
		t_rob_tail[229-:5] = 'd0;
		t_rob_tail[224-:6] = 'd0;
		t_rob_tail[218-:6] = 'd0;
		t_rob_tail[212-:64] = 'd0;
		t_rob_tail[148-:64] = 'd0;
		t_rob_tail[246] = 1'b0;
		t_rob_tail[245] = 1'b0;
		t_rob_tail[244] = 1'b0;
		t_rob_tail[243] = 1'b0;
		t_rob_tail[242] = 1'b0;
		t_rob_tail[241] = 1'b0;
		t_rob_tail[239] = 1'b0;
		t_rob_tail[240] = 1'b0;
		t_rob_tail[81] = 1'b0;
		t_rob_tail[80] = 1'b0;
		t_rob_tail[82] = 1'b0;
		t_rob_tail[84] = 1'b0;
		t_rob_tail[83] = 1'b0;
		t_rob_tail[230] = r_in_delay_slot;
		t_rob_tail[79-:64] = {64 {1'b0}};
		t_rob_tail[15-:16] = 'd0;
		t_rob_next_tail[247] = 1'b0;
		t_rob_next_tail[236] = 1'b0;
		t_rob_next_tail[235] = 1'b0;
		t_rob_next_tail[234] = 1'b0;
		t_rob_next_tail[233] = 1'b0;
		t_rob_next_tail[229-:5] = 'd0;
		t_rob_next_tail[224-:6] = 'd0;
		t_rob_next_tail[218-:6] = 'd0;
		t_rob_next_tail[212-:64] = 'd0;
		t_rob_next_tail[148-:64] = 'd0;
		t_rob_next_tail[246] = 1'b0;
		t_rob_next_tail[245] = 1'b0;
		t_rob_next_tail[244] = 1'b0;
		t_rob_next_tail[243] = 1'b0;
		t_rob_next_tail[242] = 1'b0;
		t_rob_next_tail[241] = 1'b0;
		t_rob_next_tail[239] = 1'b0;
		t_rob_next_tail[240] = 1'b0;
		t_rob_next_tail[81] = 1'b0;
		t_rob_next_tail[80] = 1'b0;
		t_rob_next_tail[82] = 1'b0;
		t_rob_next_tail[84] = 1'b0;
		t_rob_next_tail[83] = 1'b0;
		t_rob_next_tail[230] = r_in_delay_slot;
		t_rob_next_tail[79-:64] = {64 {1'b0}};
		t_rob_next_tail[15-:16] = 'd0;
		if (t_alloc) begin
			t_rob_tail[212-:64] = t_alloc_uop[92-:64];
			t_rob_tail[84] = t_alloc_uop[19];
			t_rob_tail[232] = t_alloc_uop[158];
			t_rob_tail[231] = t_alloc_uop[157];
			t_rob_tail[15-:16] = t_alloc_uop[15-:16];
			t_rob_tail[241] = t_alloc_uop[16];
			t_rob_tail[239] = ((t_alloc_uop[206-:8] == 8'd40) || (t_alloc_uop[206-:8] == 8'd7)) || (t_alloc_uop[206-:8] == 8'd95);
			t_rob_tail[240] = (t_alloc_uop[206-:8] == 8'd6) && (t_uop[198-:6] == 'd31);
			t_rob_tail[80] = t_alloc_uop[206-:8] == 8'd8;
			t_rob_tail[81] = t_alloc_uop[206-:8] == 8'd101;
			t_rob_tail[238] = t_alloc_uop[206-:8] == 8'd150;
			t_rob_tail[237] = t_alloc_uop[206-:8] == 8'd159;
			t_rob_tail[83] = (t_alloc_uop[206-:8] == 8'd7) || (t_alloc_uop[206-:8] == 8'd6);
			if (t_uop[168]) begin
				t_rob_tail[236] = 1'b1;
				t_rob_tail[229-:5] = t_uop[173:169];
				t_rob_tail[224-:6] = n_prf_entry;
				t_rob_tail[218-:6] = r_alloc_rat[t_uop[173:169] * 6+:6];
			end
			else if (t_uop[165]) begin
				t_rob_tail[235] = 1'b1;
				t_rob_tail[224-:6] = {{4 {1'b0}}, n_hilo_prf_entry};
				t_rob_tail[218-:6] = {{4 {1'b0}}, r_hilo_alloc_rat};
			end
			else if (t_uop[166]) begin
				t_rob_tail[234] = 1'b1;
				t_rob_tail[224-:6] = {{4 {1'b0}}, n_fcr_prf_entry};
				t_rob_tail[218-:6] = {{4 {1'b0}}, r_fcr_alloc_rat};
			end
			else if (t_uop[167]) begin
				t_rob_tail[233] = 1'b1;
				t_rob_tail[229-:5] = t_uop[173:169];
				t_rob_tail[224-:6] = n_fp_prf_entry;
				t_rob_tail[218-:6] = r_fp_alloc_rat[t_uop[173:169] * 6+:6];
			end
			if (t_fold_uop)
				if (t_uop[206-:8] == 8'd160) begin
					t_rob_tail[247] = 1'b1;
					t_rob_tail[246] = 1'b1;
				end
				else if (t_uop[206-:8] == 8'd150) begin
					t_rob_tail[247] = 1'b1;
					t_rob_tail[238] = 1'b1;
				end
				else if (t_uop[206-:8] == 8'd39)
					t_rob_tail[82] = 1'b1;
		end
		if (t_alloc_two) begin
			t_rob_next_tail[212-:64] = t_alloc_uop2[92-:64];
			t_rob_next_tail[84] = t_alloc_uop2[19];
			t_rob_next_tail[232] = t_uop2[158];
			t_rob_next_tail[231] = t_uop2[157];
			t_rob_next_tail[15-:16] = t_alloc_uop2[15-:16];
			t_rob_next_tail[241] = t_alloc_uop2[16];
			t_rob_next_tail[239] = ((t_alloc_uop2[206-:8] == 8'd40) || (t_alloc_uop2[206-:8] == 8'd7)) || (t_alloc_uop2[206-:8] == 8'd95);
			t_rob_next_tail[240] = (t_alloc_uop2[206-:8] == 8'd6) && (t_uop[198-:6] == 'd31);
			t_rob_next_tail[80] = t_alloc_uop2[206-:8] == 8'd8;
			t_rob_next_tail[81] = t_alloc_uop2[206-:8] == 8'd101;
			t_rob_next_tail[237] = t_alloc_uop2[206-:8] == 8'd159;
			t_rob_next_tail[238] = t_alloc_uop2[206-:8] == 8'd150;
			t_rob_next_tail[83] = (t_alloc_uop2[206-:8] == 8'd7) || (t_alloc_uop2[206-:8] == 8'd6);
			t_rob_next_tail[230] = t_uop[158];
			if (t_uop2[168]) begin
				t_rob_next_tail[236] = 1'b1;
				t_rob_next_tail[229-:5] = t_uop2[173:169];
				t_rob_next_tail[224-:6] = n_prf_entry2;
				t_rob_next_tail[218-:6] = (t_uop[168] && (t_uop[174-:6] == t_uop2[174-:6]) ? t_rob_tail[224-:6] : r_alloc_rat[t_uop2[173:169] * 6+:6]);
			end
			else if (t_uop2[167]) begin
				t_rob_next_tail[233] = 1'b1;
				t_rob_next_tail[229-:5] = t_uop2[173:169];
				t_rob_next_tail[224-:6] = n_fp_prf_entry2;
				t_rob_next_tail[218-:6] = (t_uop[167] && (t_uop[174-:6] == t_uop2[174-:6]) ? t_rob_tail[224-:6] : r_fp_alloc_rat[t_uop2[173:169] * 6+:6]);
			end
			if (t_fold_uop2)
				if (t_uop2[206-:8] == 8'd160) begin
					t_rob_next_tail[247] = 1'b1;
					t_rob_next_tail[246] = 1'b1;
				end
				else if (t_uop2[206-:8] == 8'd150) begin
					t_rob_next_tail[247] = 1'b1;
					t_rob_next_tail[238] = 1'b1;
				end
				else if (t_uop2[206-:8] == 8'd39)
					t_rob_next_tail[82] = 1'b1;
		end
	end
	always @(posedge clk)
		if (reset || t_clr_rob)
			r_rob_complete <= 'd0;
		else begin
			if (t_alloc)
				r_rob_complete[r_rob_tail_ptr[4:0]] <= t_fold_uop;
			if (t_alloc_two)
				r_rob_complete[r_rob_next_tail_ptr[4:0]] <= t_fold_uop2;
			if (t_complete_valid_1)
				r_rob_complete[t_complete_bundle_1[137:133]] <= t_complete_bundle_1[132];
			if (t_complete_valid_2)
				r_rob_complete[t_complete_bundle_2[137:133]] <= t_complete_bundle_2[132];
			if (core_mem_rsp_valid)
				r_rob_complete[core_mem_rsp[82-:5]] <= 1'b1;
		end
	always @(posedge clk)
		if (reset || t_clr_rob) begin : sv2v_autoblock_2
			integer i;
			for (i = 0; i < N_ROB_ENTRIES; i = i + 1)
				r_rob[i][247] <= 1'b0;
		end
		else begin
			if (t_alloc)
				r_rob[r_rob_tail_ptr[4:0]] <= t_rob_tail;
			if (t_alloc_two)
				r_rob[r_rob_next_tail_ptr[4:0]] <= t_rob_next_tail;
			if (t_complete_valid_1) begin
				r_rob[t_complete_bundle_1[137:133]][247] <= t_complete_bundle_1[131];
				r_rob[t_complete_bundle_1[137:133]][148-:64] <= t_complete_bundle_1[130-:64];
				r_rob[t_complete_bundle_1[137:133]][246] <= t_complete_bundle_1[65];
				r_rob[t_complete_bundle_1[137:133]][245] <= t_complete_bundle_1[64];
				r_rob[t_complete_bundle_1[137:133]][82] <= t_complete_bundle_1[66];
				r_rob[t_complete_bundle_1[137:133]][79-:64] <= t_complete_bundle_1[63-:64];
			end
			if (t_complete_valid_2) begin
				r_rob[t_complete_bundle_2[137:133]][247] <= t_complete_bundle_2[131];
				r_rob[t_complete_bundle_2[137:133]][148-:64] <= t_complete_bundle_2[130-:64];
				r_rob[t_complete_bundle_2[137:133]][246] <= t_complete_bundle_2[65];
				r_rob[t_complete_bundle_2[137:133]][82] <= t_complete_bundle_2[66];
				r_rob[t_complete_bundle_2[137:133]][245] <= t_complete_bundle_2[64];
				r_rob[t_complete_bundle_2[137:133]][79-:64] <= t_complete_bundle_2[63-:64];
			end
			if (core_mem_rsp_valid) begin
				r_rob[core_mem_rsp[82-:5]][79-:64] <= core_mem_rsp[146:83];
				r_rob[core_mem_rsp[82-:5]][247] <= core_mem_rsp[69];
				r_rob[core_mem_rsp[82-:5]][244] <= core_mem_rsp[68];
				r_rob[core_mem_rsp[82-:5]][243] <= core_mem_rsp[67];
				r_rob[core_mem_rsp[82-:5]][242] <= core_mem_rsp[66];
			end
		end
	always @(posedge clk)
		if (reset || t_clr_rob)
			r_rob_dead_insns <= 'd0;
		else begin
			if (t_retire)
				r_rob_dead_insns[r_rob_head_ptr[4:0]] <= 1'b0;
			if (t_retire_two)
				r_rob_dead_insns[r_rob_next_head_ptr[4:0]] <= 1'b0;
			if (t_alloc)
				r_rob_dead_insns[r_rob_tail_ptr[4:0]] <= 1'b1;
			if (t_alloc_two)
				r_rob_dead_insns[r_rob_next_tail_ptr[4:0]] <= 1'b1;
		end
	always @(*) begin
		t_clr_mask = (uq_wait | mq_wait) | fq_wait;
		if (t_complete_valid_1)
			t_clr_mask[t_complete_bundle_1[137-:5]] = 1'b1;
		if (t_complete_valid_2)
			t_clr_mask[t_complete_bundle_2[137-:5]] = 1'b1;
		if (core_mem_rsp_valid)
			t_clr_mask[core_mem_rsp[82-:5]] = 1'b1;
	end
	always @(posedge clk)
		if (reset)
			r_rob_inflight <= 'd0;
		else if (r_ds_done)
			r_rob_inflight <= r_rob_inflight & ~t_clr_mask;
		else begin
			if (t_complete_valid_1)
				r_rob_inflight[t_complete_bundle_1[137-:5]] <= 1'b0;
			if (t_complete_valid_2)
				r_rob_inflight[t_complete_bundle_2[137-:5]] <= 1'b0;
			if (core_mem_rsp_valid)
				r_rob_inflight[core_mem_rsp[82-:5]] <= 1'b0;
			if (t_alloc && !t_fold_uop)
				r_rob_inflight[r_rob_tail_ptr[4:0]] <= 1'b1;
			if (t_alloc_two && !t_fold_uop2)
				r_rob_inflight[r_rob_next_tail_ptr[4:0]] <= 1'b1;
		end
	always @(*) begin
		n_rob_head_ptr = r_rob_head_ptr;
		n_rob_tail_ptr = r_rob_tail_ptr;
		n_rob_next_head_ptr = r_rob_next_head_ptr;
		n_rob_next_tail_ptr = r_rob_next_tail_ptr;
		if (t_clr_rob) begin
			n_rob_head_ptr = 'd0;
			n_rob_tail_ptr = 'd0;
			n_rob_next_head_ptr = 'd1;
			n_rob_next_tail_ptr = 'd1;
		end
		else begin
			if (t_alloc && !t_alloc_two) begin
				n_rob_tail_ptr = r_rob_tail_ptr + 'd1;
				n_rob_next_tail_ptr = r_rob_next_tail_ptr + 'd1;
			end
			else if (t_alloc && t_alloc_two) begin
				n_rob_tail_ptr = r_rob_tail_ptr + 'd2;
				n_rob_next_tail_ptr = r_rob_next_tail_ptr + 'd2;
			end
			if (t_retire || t_bump_rob_head) begin
				n_rob_head_ptr = (t_retire_two ? r_rob_head_ptr + 'd2 : r_rob_head_ptr + 'd1);
				n_rob_next_head_ptr = (t_retire_two ? r_rob_next_head_ptr + 'd2 : r_rob_next_head_ptr + 'd1);
			end
		end
		t_rob_empty = r_rob_head_ptr == r_rob_tail_ptr;
		t_rob_next_empty = r_rob_next_head_ptr == r_rob_tail_ptr;
		t_rob_full = (r_rob_head_ptr[4:0] == r_rob_tail_ptr[4:0]) && (r_rob_head_ptr != r_rob_tail_ptr);
		t_rob_next_full = (r_rob_head_ptr[4:0] == r_rob_next_tail_ptr[4:0]) && (r_rob_head_ptr != r_rob_next_tail_ptr);
	end
	always @(*) begin
		t_rob_head = r_rob[r_rob_head_ptr[4:0]];
		t_rob_next_head = r_rob[r_rob_next_head_ptr[4:0]];
		t_rob_head_complete = r_rob_complete[r_rob_head_ptr[4:0]];
		t_rob_next_head_complete = r_rob_complete[r_rob_next_head_ptr[4:0]];
	end
	always @(posedge clk)
		if (reset) begin : sv2v_autoblock_3
			integer i;
			for (i = 0; i < N_HILO_ENTRIES; i = i + 1)
				begin
					r_hilo_prf_free[i] <= (i == 0 ? 1'b0 : 1'b1);
					r_retire_hilo_prf_free[i] <= (i == 0 ? 1'b0 : 1'b1);
				end
		end
		else begin
			r_hilo_prf_free <= (t_rat_copy ? r_retire_hilo_prf_free : n_hilo_prf_free);
			r_retire_hilo_prf_free <= n_retire_hilo_prf_free;
		end
	always @(posedge clk)
		if (reset) begin : sv2v_autoblock_4
			integer i;
			for (i = 0; i < N_FCR_ENTRIES; i = i + 1)
				begin
					r_fcr_prf_free[i] <= (i == 0 ? 1'b0 : 1'b1);
					r_retire_fcr_prf_free[i] <= (i == 0 ? 1'b0 : 1'b1);
				end
		end
		else begin
			r_fcr_prf_free <= (t_rat_copy ? r_retire_fcr_prf_free : n_fcr_prf_free);
			r_retire_fcr_prf_free <= n_retire_fcr_prf_free;
		end
	popcount #(6) cnt_fpr(
		.in(r_fp_prf_free),
		.out(t_fp_prf_free_cnt)
	);
	find_first_set #(6) ffs_fp(
		.in(r_fp_prf_free),
		.y(t_fp_ffs)
	);
	always @(*) begin
		t_fp_prf_free = r_fp_prf_free;
		t_fp_prf_free[t_fp_ffs[5:0]] = 1'b0;
	end
	find_first_set #(6) ffs_fp2(
		.in(t_fp_prf_free),
		.y(t_fp_ffs2)
	);
	always @(posedge clk)
		if (reset) begin : sv2v_autoblock_5
			integer i;
			for (i = 0; i < N_PRF_ENTRIES; i = i + 1)
				begin
					r_prf_free[i] <= (i < 32 ? 1'b0 : 1'b1);
					r_retire_prf_free[i] <= (i < 32 ? 1'b0 : 1'b1);
				end
		end
		else begin
			r_prf_free <= (t_rat_copy ? r_retire_prf_free : n_prf_free);
			r_retire_prf_free <= n_retire_prf_free;
		end
	always @(posedge clk)
		if (reset) begin : sv2v_autoblock_6
			integer i;
			for (i = 0; i < N_PRF_ENTRIES; i = i + 1)
				begin
					r_fp_prf_free[i] <= (i < 32 ? 1'b0 : 1'b1);
					r_retire_fp_prf_free[i] <= (i < 32 ? 1'b0 : 1'b1);
				end
		end
		else begin
			r_fp_prf_free <= (t_rat_copy ? r_retire_fp_prf_free : n_fp_prf_free);
			r_retire_fp_prf_free <= n_retire_fp_prf_free;
		end
	find_first_set #(2) ffs_hilo(
		.in(r_hilo_prf_free),
		.y(t_hilo_ffs)
	);
	always @(*) begin
		n_hilo_prf_free = r_hilo_prf_free;
		n_hilo_prf_entry = t_hilo_ffs[1:0];
		if (t_alloc & t_uop[165])
			n_hilo_prf_free[n_hilo_prf_entry] = 1'b0;
		if (t_free_hilo)
			n_hilo_prf_free[t_free_hilo_ptr] = 1'b1;
	end
	find_first_set #(2) ffs_fcr(
		.in(r_fcr_prf_free),
		.y(t_fcr_ffs)
	);
	always @(*) begin
		n_fcr_prf_free = r_fcr_prf_free;
		n_fcr_prf_entry = t_fcr_ffs[1:0];
		if (t_alloc & t_uop[166])
			n_fcr_prf_free[n_fcr_prf_entry] = 1'b0;
		if (t_free_fcr)
			n_fcr_prf_free[t_free_fcr_ptr] = 1'b1;
	end
	always @(*) begin
		n_fp_prf_free = r_fp_prf_free;
		n_fp_prf_entry = t_fp_ffs[5:0];
		n_fp_prf_entry2 = t_fp_ffs2[5:0];
		if (t_alloc && t_uop[167])
			n_fp_prf_free[n_fp_prf_entry] = 1'b0;
		if (t_alloc_two && t_uop2[167])
			n_fp_prf_free[n_fp_prf_entry2] = 1'b0;
		if (t_free_fp_reg)
			n_fp_prf_free[t_free_fp_reg_ptr] = 1'b1;
		if (t_free_fp_two_reg)
			n_fp_prf_free[t_free_fp_reg_two_ptr] = 1'b1;
	end
	popcount #(6) cnt_gpr(
		.in(r_prf_free),
		.out(t_prf_free_cnt)
	);
	find_first_set #(6) ffs_gpr(
		.in(r_prf_free),
		.y(t_gpr_ffs)
	);
	always @(*) begin
		t_prf_free = r_prf_free;
		t_prf_free[t_gpr_ffs[5:0]] = 1'b0;
	end
	find_first_set #(6) ffs_gpr2(
		.in(t_prf_free),
		.y(t_gpr_ffs2)
	);
	always @(*) begin
		n_prf_free = r_prf_free;
		n_prf_entry = t_gpr_ffs[5:0];
		n_prf_entry2 = t_gpr_ffs2[5:0];
		if (t_alloc & t_uop[168])
			n_prf_free[n_prf_entry] = 1'b0;
		if (t_alloc_two && t_uop2[168])
			n_prf_free[n_prf_entry2] = 1'b0;
		if (t_free_reg)
			n_prf_free[t_free_reg_ptr] = 1'b1;
		if (t_free_reg_two)
			n_prf_free[t_free_reg_two_ptr] = 1'b1;
	end
	decode_mips32 dec0(
		.in_64b_fpreg_mode(t_in_32fp_reg_mode),
		.insn(insn[176-:32]),
		.pc(insn[144-:64]),
		.insn_pred(insn[16]),
		.pht_idx(insn[15-:16]),
		.insn_pred_target(insn[80-:64]),
		.uop(t_dec_uop)
	);
	decode_mips32 dec1(
		.in_64b_fpreg_mode(t_in_32fp_reg_mode),
		.insn(insn_two[176-:32]),
		.pc(insn_two[144-:64]),
		.insn_pred(insn_two[16]),
		.pht_idx(insn_two[15-:16]),
		.insn_pred_target(insn_two[80-:64]),
		.uop(t_dec_uop2)
	);
	reg t_push_1;
	reg t_push_2;
	always @(*) begin
		t_any_complete = (t_complete_valid_1 | t_complete_valid_2) | core_mem_rsp_valid;
		t_push_1 = t_alloc && !t_fold_uop;
		t_push_2 = t_alloc_two && !t_fold_uop2;
	end
	exec e(
		.clk(clk),
		.reset(reset),
		.divide_ready(t_divide_ready),
		.ds_done(r_ds_done),
		.machine_clr(r_machine_clr),
		.restart_complete(t_restart_complete),
		.delayslot_rob_ptr(r_delayslot_rob_ptr),
		.in_32fp_reg_mode(t_in_32fp_reg_mode),
		.cpr0_status_reg(t_cpr0_status_reg),
		.mq_wait(mq_wait),
		.uq_wait(uq_wait),
		.fq_wait(fq_wait),
		.uq_empty(t_uq_empty),
		.uq_full(t_uq_full),
		.uq_next_full(t_uq_next_full),
		.uq_uop((t_push_1 ? t_alloc_uop : t_alloc_uop2)),
		.uq_uop_two(t_alloc_uop2),
		.uq_push(t_push_1 || (!t_push_1 && t_push_2)),
		.uq_push_two(t_push_2 && t_push_1),
		.complete_bundle_1(t_complete_bundle_1),
		.complete_valid_1(t_complete_valid_1),
		.complete_bundle_2(t_complete_bundle_2),
		.complete_valid_2(t_complete_valid_2),
		.exception_wr_cpr0_val(t_exception_wr_cpr0_val),
		.exception_wr_cpr0_ptr(t_exception_wr_cpr0_ptr),
		.exception_wr_cpr0_data(t_exception_wr_cpr0_data),
		.mem_req(t_mem_req),
		.mem_req_valid(t_mem_req_valid),
		.mem_req_ack(core_mem_req_ack),
		.mem_rsp_dst_ptr(core_mem_rsp[77-:6]),
		.mem_rsp_dst_valid(core_mem_rsp[71]),
		.mem_rsp_fp_dst_valid(core_mem_rsp[70]),
		.mem_rsp_load_data(core_mem_rsp[146-:64]),
		.mem_rsp_rob_ptr(core_mem_rsp[82-:5]),
		.monitor_rsp_data(r_monitor_rsp_data),
		.monitor_rsp_data_valid(r_monitor_rsp_data_valid)
	);
	always @(posedge clk)
		if (reset) begin
			r_dq_head_ptr <= 'd0;
			r_dq_next_head_ptr <= 'd1;
			r_dq_next_tail_ptr <= 'd1;
			r_dq_tail_ptr <= 'd0;
			r_dq_cnt <= 'd0;
		end
		else begin
			r_dq_head_ptr <= (t_clr_rob ? 'd0 : n_dq_head_ptr);
			r_dq_tail_ptr <= (t_clr_rob ? 'd0 : n_dq_tail_ptr);
			r_dq_next_head_ptr <= (t_clr_rob ? 'd1 : n_dq_next_head_ptr);
			r_dq_next_tail_ptr <= (t_clr_rob ? 'd1 : n_dq_next_tail_ptr);
			r_dq_cnt <= (t_clr_rob ? 'd0 : n_dq_cnt);
		end
	always @(posedge clk) r_dq <= n_dq;
	always @(negedge clk)
		if ((insn_ack && insn_ack_two) && 1'b0)
			$display("ack two insns in cycle %d, valid %b, %b, pc %x %x", r_cycle, insn_valid, insn_valid_two, insn[144-:64], insn_two[144-:64]);
		else if ((insn_ack && !insn_ack_two) && 1'b0)
			$display("ack one insn in cycle %d, valid %b, pc %x ", r_cycle, insn_valid, insn[144-:64]);
	always @(*) begin
		n_dq = r_dq;
		n_dq_tail_ptr = r_dq_tail_ptr;
		n_dq_head_ptr = r_dq_head_ptr;
		n_dq_next_head_ptr = r_dq_next_head_ptr;
		n_dq_next_tail_ptr = r_dq_next_tail_ptr;
		t_dq_empty = r_dq_tail_ptr == r_dq_head_ptr;
		t_dq_next_empty = r_dq_tail_ptr == r_dq_next_head_ptr;
		t_dq_full = (r_dq_tail_ptr[1:0] == r_dq_head_ptr[1:0]) && (r_dq_tail_ptr != r_dq_head_ptr);
		t_dq_next_full = (r_dq_next_tail_ptr[1:0] == r_dq_head_ptr[1:0]) && (r_dq_next_tail_ptr != r_dq_head_ptr);
		n_dq_cnt = r_dq_cnt;
		t_uop = r_dq[r_dq_head_ptr[1:0] * 207+:207];
		t_uop2 = r_dq[r_dq_next_head_ptr[1:0] * 207+:207];
		if (t_clr_dq) begin
			n_dq_tail_ptr = 'd0;
			n_dq_head_ptr = 'd0;
			n_dq_next_head_ptr = 'd1;
			n_dq_next_tail_ptr = 'd1;
			n_dq_cnt = 'd0;
		end
		else begin
			if ((insn_valid && !t_dq_full) && !(!t_dq_next_full && insn_valid_two)) begin
				n_dq[r_dq_tail_ptr[1:0] * 207+:207] = t_dec_uop;
				n_dq_tail_ptr = r_dq_tail_ptr + 'd1;
				n_dq_next_tail_ptr = r_dq_next_tail_ptr + 'd1;
				n_dq_cnt = n_dq_cnt + 'd1;
			end
			else if (((insn_valid && !t_dq_full) && !t_dq_next_full) && insn_valid_two) begin
				n_dq[r_dq_tail_ptr[1:0] * 207+:207] = t_dec_uop;
				n_dq[r_dq_next_tail_ptr[1:0] * 207+:207] = t_dec_uop2;
				n_dq_tail_ptr = r_dq_tail_ptr + 'd2;
				n_dq_next_tail_ptr = r_dq_next_tail_ptr + 'd2;
				n_dq_cnt = n_dq_cnt + 'd2;
			end
			if (t_alloc && !t_alloc_two) begin
				n_dq_head_ptr = r_dq_head_ptr + 'd1;
				n_dq_next_head_ptr = r_dq_next_head_ptr + 'd1;
				n_dq_cnt = n_dq_cnt - 'd1;
			end
			else if (t_alloc && t_alloc_two) begin
				n_dq_head_ptr = r_dq_head_ptr + 'd2;
				n_dq_next_head_ptr = r_dq_next_head_ptr + 'd2;
				n_dq_cnt = n_dq_cnt - 'd2;
			end
		end
	end
endmodule

module exec (
	clk,
	reset,
	divide_ready,
	ds_done,
	machine_clr,
	restart_complete,
	delayslot_rob_ptr,
	in_32fp_reg_mode,
	cpr0_status_reg,
	uq_wait,
	mq_wait,
	fq_wait,
	uq_empty,
	uq_full,
	uq_next_full,
	uq_uop,
	uq_uop_two,
	uq_push,
	uq_push_two,
	complete_bundle_1,
	complete_valid_1,
	complete_bundle_2,
	complete_valid_2,
	exception_wr_cpr0_val,
	exception_wr_cpr0_ptr,
	exception_wr_cpr0_data,
	mem_req,
	mem_req_valid,
	mem_req_ack,
	mem_rsp_dst_ptr,
	mem_rsp_dst_valid,
	mem_rsp_rob_ptr,
	mem_rsp_fp_dst_valid,
	mem_rsp_load_data,
	monitor_rsp_data,
	monitor_rsp_data_valid
);
	input wire clk;
	input wire reset;
	output wire divide_ready;
	input wire ds_done;
	input wire machine_clr;
	input wire restart_complete;
	input wire [4:0] delayslot_rob_ptr;
	output wire in_32fp_reg_mode;
	output reg [63:0] cpr0_status_reg;
	localparam N_ROB_ENTRIES = 32;
	output wire [31:0] uq_wait;
	output wire [31:0] mq_wait;
	output wire [31:0] fq_wait;
	output reg uq_empty;
	output reg uq_full;
	output reg uq_next_full;
	input wire [206:0] uq_uop;
	input wire [206:0] uq_uop_two;
	input wire uq_push;
	input wire uq_push_two;
	output reg [137:0] complete_bundle_1;
	output reg complete_valid_1;
	output reg [137:0] complete_bundle_2;
	output reg complete_valid_2;
	input wire exception_wr_cpr0_val;
	input wire [4:0] exception_wr_cpr0_ptr;
	input wire [63:0] exception_wr_cpr0_data;
	output wire [245:0] mem_req;
	output wire mem_req_valid;
	input wire mem_req_ack;
	input wire [5:0] mem_rsp_dst_ptr;
	input wire mem_rsp_dst_valid;
	input wire mem_rsp_fp_dst_valid;
	input wire [63:0] mem_rsp_load_data;
	input wire [4:0] mem_rsp_rob_ptr;
	input wire [63:0] monitor_rsp_data;
	input wire monitor_rsp_data_valid;
	localparam N_MQ_ENTRIES = 8;
	localparam N_INT_PRF_ENTRIES = 64;
	localparam N_HILO_PRF_ENTRIES = 4;
	localparam N_FCR_PRF_ENTRIES = 4;
	localparam N_FP_PRF_ENTRIES = 64;
	localparam N_UQ_ENTRIES = 8;
	localparam N_MEM_UQ_ENTRIES = 8;
	localparam N_FP_UQ_ENTRIES = 8;
	reg [63:0] r_int_prf [63:0];
	reg [63:0] r_fp_prf [63:0];
	reg [63:0] r_hilo_prf [3:0];
	reg [7:0] r_fcr_prf [3:0];
	reg [63:0] r_cpr0 [31:0];
	localparam FP_ZP = 1;
	localparam Z_BITS = 0;
	reg [63:0] r_prf_inflight;
	reg [63:0] n_prf_inflight;
	reg [63:0] r_fp_prf_inflight;
	reg [63:0] n_fp_prf_inflight;
	reg [3:0] r_fcr_prf_inflight;
	reg [3:0] n_fcr_prf_inflight;
	reg [3:0] r_hilo_inflight;
	reg [3:0] n_hilo_inflight;
	reg n_in_32b_mode;
	reg r_in_32b_mode;
	reg n_in_32fp_reg_mode;
	reg r_in_32fp_reg_mode;
	wire [63:0] t_fpu_result;
	wire t_fpu_result_valid;
	wire t_fpu_fcr_valid;
	wire [1:0] t_fpu_fcr_ptr;
	wire [5:0] t_fpu_dst_ptr;
	wire [4:0] t_fpu_rob_ptr;
	wire t_sp_div_valid;
	wire t_dp_div_valid;
	wire [63:0] t_dp_div_result;
	wire [31:0] t_sp_div_result;
	wire [5:0] t_sp_div_dst_ptr;
	wire [4:0] t_sp_div_rob_ptr;
	wire [5:0] t_dp_div_dst_ptr;
	wire [4:0] t_dp_div_rob_ptr;
	reg t_wr_int_prf;
	reg t_wr_cpr0;
	reg [4:0] t_dst_cpr0;
	reg t_wr_hilo;
	reg t_take_br;
	reg t_mispred_br;
	reg t_alu_valid;
	reg t_got_break;
	reg t_got_syscall;
	reg t_set_thread_area;
	reg [245:0] r_mem_q [7:0];
	reg [3:0] r_mq_head_ptr;
	reg [3:0] n_mq_head_ptr;
	reg [3:0] r_mq_tail_ptr;
	reg [3:0] n_mq_tail_ptr;
	reg [245:0] t_mem_tail;
	reg [245:0] t_mem_head;
	reg mem_q_full;
	reg mem_q_empty;
	reg t_pop_uq;
	reg t_pop_mem_uq;
	reg t_pop_fp_uq;
	reg t_push_mq;
	reg t_start_fpu;
	localparam E_BITS = 48;
	localparam HI_EBITS = 32;
	reg [63:0] t_simm;
	reg [63:0] t_mem_simm;
	reg [63:0] t_result;
	reg [63:0] t_cpr0_result;
	reg [31:0] t_result32;
	reg [63:0] t_hilo_result;
	reg [63:0] t_pc;
	reg [63:0] t_pc4;
	reg [63:0] t_pc8;
	reg [27:0] t_jaddr;
	wire t_srcs_rdy;
	reg t_mem_srcs_rdy;
	reg t_fp_srcs_rdy;
	reg t_fp_wr_prf;
	reg [63:0] t_fp_result;
	reg [63:0] t_srcA;
	reg [63:0] t_srcB;
	reg [63:0] t_srcC;
	reg [63:0] tt_srcA;
	reg [63:0] tt_srcB;
	reg [63:0] tt_srcC;
	reg [63:0] t_mem_srcA;
	reg [63:0] t_mem_srcB;
	wire [63:0] t_fp_srcA;
	wire [63:0] t_fp_srcB;
	wire [63:0] t_fp_srcC;
	reg [63:0] t_mem_fp_srcB;
	wire [63:0] t_mem_fp_srcC;
	reg [63:0] t_src_hilo;
	reg [63:0] t_cpr0_srcA;
	wire [5:0] w_clz;
	reg t_unimp_op;
	reg t_fault;
	reg t_signed_shift;
	reg [4:0] t_shift_amt;
	wire [31:0] t_shift_right;
	wire [31:0] t_ext;
	reg t_start_mul;
	wire t_mul_complete;
	wire [63:0] t_mul_result;
	wire t_gpr_prf_ptr_val_out;
	wire t_hilo_prf_ptr_val_out;
	wire [4:0] t_rob_ptr_out;
	wire [5:0] t_gpr_prf_ptr_out;
	wire [1:0] t_hilo_prf_ptr_out;
	reg [67:0] r_wb_bitvec;
	reg [67:0] n_wb_bitvec;
	reg [8:0] r_fp_wb_bitvec;
	reg [8:0] n_fp_wb_bitvec;
	wire t_div_ready;
	reg t_signed_div;
	reg t_start_div32;
	wire [4:0] t_div_rob_ptr_out;
	wire [63:0] t_div_result;
	wire [1:0] t_div_hilo_prf_ptr_out;
	wire t_div_complete;
	reg [31:0] r_uq_wait;
	reg [31:0] r_mq_wait;
	reg [31:0] r_fq_wait;
	reg [206:0] r_uq [0:7];
	reg [206:0] uq;
	reg [206:0] int_uop;
	reg r_start_int;
	wire t_uq_read;
	reg t_uq_empty;
	reg t_uq_full;
	reg t_uq_next_full;
	reg [3:0] r_uq_head_ptr;
	reg [3:0] n_uq_head_ptr;
	reg [3:0] r_uq_tail_ptr;
	reg [3:0] n_uq_tail_ptr;
	reg [3:0] r_uq_next_head_ptr;
	reg [3:0] n_uq_next_head_ptr;
	reg [3:0] r_uq_next_tail_ptr;
	reg [3:0] n_uq_next_tail_ptr;
	reg [206:0] r_mem_uq [0:7];
	reg [206:0] mem_uq;
	wire t_mem_uq_read;
	reg t_mem_uq_empty;
	reg t_mem_uq_full;
	reg t_mem_uq_next_full;
	reg [3:0] r_mem_uq_head_ptr;
	reg [3:0] n_mem_uq_head_ptr;
	reg [3:0] r_mem_uq_tail_ptr;
	reg [3:0] n_mem_uq_tail_ptr;
	reg [3:0] r_mem_uq_next_head_ptr;
	reg [3:0] n_mem_uq_next_head_ptr;
	reg [3:0] r_mem_uq_next_tail_ptr;
	reg [3:0] n_mem_uq_next_tail_ptr;
	reg [206:0] r_fp_uq [0:7];
	reg [206:0] fp_uq;
	wire t_fp_uq_read;
	reg t_fp_uq_empty;
	reg t_fp_uq_full;
	reg t_fp_uq_next_full;
	reg t_push_two_mem;
	reg t_push_two_fp;
	reg t_push_two_int;
	reg t_push_one_mem;
	reg t_push_one_fp;
	reg t_push_one_int;
	reg [3:0] r_fp_uq_head_ptr;
	reg [3:0] n_fp_uq_head_ptr;
	reg [3:0] r_fp_uq_tail_ptr;
	reg [3:0] n_fp_uq_tail_ptr;
	reg [3:0] r_fp_uq_next_head_ptr;
	reg [3:0] n_fp_uq_next_head_ptr;
	reg [3:0] r_fp_uq_next_tail_ptr;
	reg [3:0] n_fp_uq_next_tail_ptr;
	reg t_flash_clear;
	always @(*) t_flash_clear = ds_done;
	always @(*) begin
		uq_full = (t_uq_full || t_mem_uq_full) || t_fp_uq_full;
		uq_next_full = (t_uq_next_full || t_mem_uq_next_full) || t_fp_uq_next_full;
		uq_empty = t_uq_empty;
	end
	always @(posedge clk)
		if (reset) begin
			r_in_32b_mode <= 1'b1;
			r_in_32fp_reg_mode <= 1'b0;
		end
		else begin
			r_in_32b_mode <= 1'b1;
			r_in_32fp_reg_mode <= n_in_32fp_reg_mode;
		end
	always @(posedge clk)
		if (reset || t_flash_clear) begin
			r_uq_head_ptr <= 'd0;
			r_uq_tail_ptr <= 'd0;
			r_uq_next_head_ptr <= 'd1;
			r_uq_next_tail_ptr <= 'd1;
		end
		else begin
			r_uq_head_ptr <= n_uq_head_ptr;
			r_uq_tail_ptr <= n_uq_tail_ptr;
			r_uq_next_head_ptr <= n_uq_next_head_ptr;
			r_uq_next_tail_ptr <= n_uq_next_tail_ptr;
		end
	always @(posedge clk)
		if (reset || t_flash_clear) begin
			r_mem_uq_head_ptr <= 'd0;
			r_mem_uq_tail_ptr <= 'd0;
			r_mem_uq_next_head_ptr <= 'd1;
			r_mem_uq_next_tail_ptr <= 'd1;
		end
		else begin
			r_mem_uq_head_ptr <= n_mem_uq_head_ptr;
			r_mem_uq_tail_ptr <= n_mem_uq_tail_ptr;
			r_mem_uq_next_head_ptr <= n_mem_uq_next_head_ptr;
			r_mem_uq_next_tail_ptr <= n_mem_uq_next_tail_ptr;
		end
	always @(*) begin
		n_mem_uq_head_ptr = r_mem_uq_head_ptr;
		n_mem_uq_tail_ptr = r_mem_uq_tail_ptr;
		n_mem_uq_next_head_ptr = r_mem_uq_next_head_ptr;
		n_mem_uq_next_tail_ptr = r_mem_uq_next_tail_ptr;
		t_mem_uq_empty = r_mem_uq_head_ptr == r_mem_uq_tail_ptr;
		t_mem_uq_full = (r_mem_uq_head_ptr != r_mem_uq_tail_ptr) && (r_mem_uq_head_ptr[2:0] == r_mem_uq_tail_ptr[2:0]);
		t_mem_uq_next_full = (r_mem_uq_head_ptr != r_mem_uq_next_tail_ptr) && (r_mem_uq_head_ptr[2:0] == r_mem_uq_next_tail_ptr[2:0]);
		mem_uq = r_mem_uq[r_mem_uq_head_ptr[2:0]];
		t_push_two_mem = ((uq_push && uq_push_two) && uq_uop[18]) && uq_uop_two[18];
		t_push_one_mem = ((uq_push && uq_uop[18]) || (uq_push_two && uq_uop_two[18])) && !t_push_two_mem;
		if (t_push_two_mem) begin
			n_mem_uq_tail_ptr = r_mem_uq_tail_ptr + 'd2;
			n_mem_uq_next_tail_ptr = r_mem_uq_next_tail_ptr + 'd2;
		end
		else if ((uq_push_two && uq_uop_two[18]) || (uq_push && uq_uop[18])) begin
			n_mem_uq_tail_ptr = r_mem_uq_tail_ptr + 'd1;
			n_mem_uq_next_tail_ptr = r_mem_uq_next_tail_ptr + 'd1;
		end
		if (t_pop_mem_uq)
			n_mem_uq_head_ptr = r_mem_uq_head_ptr + 'd1;
	end
	always @(posedge clk)
		if (reset) begin
			r_mq_wait <= 'd0;
			r_uq_wait <= 'd0;
			r_fq_wait <= 'd0;
		end
		else if (restart_complete) begin
			r_mq_wait <= 'd0;
			r_uq_wait <= 'd0;
			r_fq_wait <= 'd0;
		end
		else begin
			if (t_push_two_mem) begin
				r_mq_wait[uq_uop_two[28-:5]] <= 1'b1;
				r_mq_wait[uq_uop[28-:5]] <= 1'b1;
			end
			else if (t_push_one_mem)
				r_mq_wait[(uq_uop[18] ? uq_uop[28-:5] : uq_uop_two[28-:5])] <= 1'b1;
			if (t_pop_mem_uq)
				r_mq_wait[mem_uq[28-:5]] <= 1'b0;
			if (t_push_two_int) begin
				r_uq_wait[uq_uop[28-:5]] <= 1'b1;
				r_uq_wait[uq_uop_two[28-:5]] <= 1'b1;
			end
			else if (t_push_one_int)
				r_uq_wait[(uq_uop[20] ? uq_uop[28-:5] : uq_uop_two[28-:5])] <= 1'b1;
			if (r_start_int)
				r_uq_wait[int_uop[28-:5]] <= 1'b0;
			if (t_push_two_fp) begin
				r_fq_wait[uq_uop[28-:5]] <= 1'b1;
				r_fq_wait[uq_uop_two[28-:5]] <= 1'b1;
			end
			else if (t_push_one_fp)
				r_fq_wait[(uq_uop[17] ? uq_uop[28-:5] : uq_uop_two[28-:5])] <= 1'b1;
			if (t_pop_fp_uq)
				r_fq_wait[fp_uq[28-:5]] <= 1'b0;
		end
	always @(posedge clk)
		if (t_push_two_mem) begin
			r_mem_uq[r_mem_uq_next_tail_ptr[2:0]] <= uq_uop_two;
			r_mem_uq[r_mem_uq_tail_ptr[2:0]] <= uq_uop;
		end
		else if (t_push_one_mem)
			r_mem_uq[r_mem_uq_tail_ptr[2:0]] <= (uq_uop[18] ? uq_uop : uq_uop_two);
	always @(posedge clk)
		if (reset || t_flash_clear) begin
			r_fp_uq_head_ptr <= 'd0;
			r_fp_uq_tail_ptr <= 'd0;
			r_fp_uq_next_head_ptr <= 'd1;
			r_fp_uq_next_tail_ptr <= 'd1;
		end
		else begin
			r_fp_uq_head_ptr <= n_fp_uq_head_ptr;
			r_fp_uq_tail_ptr <= n_fp_uq_tail_ptr;
			r_fp_uq_next_head_ptr <= n_fp_uq_next_head_ptr;
			r_fp_uq_next_tail_ptr <= n_fp_uq_next_tail_ptr;
		end
	always @(*) begin
		n_fp_uq_head_ptr = r_fp_uq_head_ptr;
		n_fp_uq_tail_ptr = r_fp_uq_tail_ptr;
		n_fp_uq_next_head_ptr = r_fp_uq_next_head_ptr;
		n_fp_uq_next_tail_ptr = r_fp_uq_next_tail_ptr;
		t_fp_uq_empty = r_fp_uq_head_ptr == r_fp_uq_tail_ptr;
		t_fp_uq_full = (r_fp_uq_head_ptr != r_fp_uq_tail_ptr) && (r_fp_uq_head_ptr[2:0] == r_fp_uq_tail_ptr[2:0]);
		t_fp_uq_next_full = (r_fp_uq_head_ptr != r_fp_uq_next_tail_ptr) && (r_fp_uq_head_ptr[2:0] == r_fp_uq_next_tail_ptr[2:0]);
		fp_uq = r_fp_uq[r_fp_uq_head_ptr[2:0]];
		t_push_two_fp = ((uq_push && uq_push_two) && uq_uop[17]) && uq_uop_two[17];
		t_push_one_fp = ((uq_push && uq_uop[17]) || (uq_push_two && uq_uop_two[17])) && !t_push_two_fp;
		if (t_push_two_fp) begin
			n_fp_uq_tail_ptr = r_fp_uq_tail_ptr + 'd2;
			n_fp_uq_next_tail_ptr = r_fp_uq_next_tail_ptr + 'd2;
		end
		else if ((uq_push_two && uq_uop_two[17]) || (uq_push && uq_uop[17])) begin
			n_fp_uq_tail_ptr = r_fp_uq_tail_ptr + 'd1;
			n_fp_uq_next_tail_ptr = r_fp_uq_next_tail_ptr + 'd1;
		end
		if (t_pop_fp_uq)
			n_fp_uq_head_ptr = r_fp_uq_head_ptr + 'd1;
	end
	always @(posedge clk)
		if (t_push_two_fp) begin
			r_fp_uq[r_fp_uq_tail_ptr[2:0]] <= uq_uop;
			r_fp_uq[r_fp_uq_next_tail_ptr[2:0]] <= uq_uop_two;
		end
		else if (t_push_one_fp)
			r_fp_uq[r_fp_uq_tail_ptr[2:0]] <= (uq_uop[17] ? uq_uop : uq_uop_two);
	always @(*) begin
		n_uq_head_ptr = r_uq_head_ptr;
		n_uq_tail_ptr = r_uq_tail_ptr;
		n_uq_next_head_ptr = r_uq_next_head_ptr;
		n_uq_next_tail_ptr = r_uq_next_tail_ptr;
		t_uq_empty = r_uq_head_ptr == r_uq_tail_ptr;
		t_uq_full = (r_uq_head_ptr != r_uq_tail_ptr) && (r_uq_head_ptr[2:0] == r_uq_tail_ptr[2:0]);
		t_uq_next_full = (r_uq_head_ptr != r_uq_next_tail_ptr) && (r_uq_head_ptr[2:0] == r_uq_next_tail_ptr[2:0]);
		t_push_two_int = ((uq_push && uq_push_two) && uq_uop[20]) && uq_uop_two[20];
		t_push_one_int = ((uq_push && uq_uop[20]) || (uq_push_two && uq_uop_two[20])) && !t_push_two_int;
		uq = r_uq[r_uq_head_ptr[2:0]];
		if (t_push_two_int) begin
			n_uq_tail_ptr = r_uq_tail_ptr + 'd2;
			n_uq_next_tail_ptr = r_uq_next_tail_ptr + 'd2;
		end
		else if ((uq_push_two && uq_uop_two[20]) || (uq_push && uq_uop[20])) begin
			n_uq_tail_ptr = r_uq_tail_ptr + 'd1;
			n_uq_next_tail_ptr = r_uq_next_tail_ptr + 'd1;
		end
		if (t_pop_uq)
			n_uq_head_ptr = r_uq_head_ptr + 'd1;
	end
	always @(posedge clk)
		if (t_push_two_int) begin
			r_uq[r_uq_tail_ptr[2:0]] <= uq_uop;
			r_uq[r_uq_next_tail_ptr[2:0]] <= uq_uop_two;
		end
		else if (t_push_one_int)
			r_uq[r_uq_tail_ptr[2:0]] <= (uq_uop[20] ? uq_uop : uq_uop_two);
	reg [31:0] r_cycle;
	always @(posedge clk) r_cycle <= (reset ? 'd0 : r_cycle + 'd1);
	always @(posedge clk)
		if (reset)
			r_wb_bitvec <= 'd0;
		else
			r_wb_bitvec <= n_wb_bitvec;
	always @(*) begin
		begin : sv2v_autoblock_1
			integer i;
			for (i = 66; i > -1; i = i - 1)
				n_wb_bitvec[i] = r_wb_bitvec[i + 1];
		end
		n_wb_bitvec[35] = t_start_div32 & r_start_int;
		if (t_start_mul & r_start_int)
			n_wb_bitvec[2] = 1'b1;
	end
	always @(posedge clk) r_fp_wb_bitvec <= (reset ? 'd0 : n_fp_wb_bitvec);
	always @(*) begin
		begin : sv2v_autoblock_2
			integer i;
			for (i = 7; i > -1; i = i - 1)
				n_fp_wb_bitvec[i] = r_fp_wb_bitvec[i + 1];
		end
		n_fp_wb_bitvec[3] = t_start_fpu;
	end
	always @(*) begin
		tt_srcA = r_int_prf[int_uop[198-:6]];
		tt_srcB = r_int_prf[int_uop[190-:6]];
		tt_srcC = r_int_prf[int_uop[182-:6]];
		t_srcA = (r_in_32b_mode ? {{HI_EBITS {1'b0}}, tt_srcA[31:0]} : tt_srcA);
		t_srcB = (r_in_32b_mode ? {{HI_EBITS {1'b0}}, tt_srcB[31:0]} : tt_srcB);
		t_srcC = (r_in_32b_mode ? {{HI_EBITS {1'b0}}, tt_srcC[31:0]} : tt_srcC);
		t_src_hilo = r_hilo_prf[int_uop[160-:2]];
		t_mem_srcA = r_int_prf[mem_uq[198-:6]];
		t_mem_srcB = r_int_prf[mem_uq[190-:6]];
		t_mem_fp_srcB = r_fp_prf[mem_uq[190-:6]];
		t_cpr0_srcA = r_cpr0[int_uop[197:193]];
	end
	localparam LG_INT_SCHED_ENTRIES = 2;
	localparam N_INT_SCHED_ENTRIES = 4;
	reg [3:0] r_alu_sched_valid;
	wire [LG_INT_SCHED_ENTRIES:0] t_alu_sched_alloc_ptr;
	reg t_alu_sched_full;
	reg [3:0] t_alu_alloc_entry;
	reg [3:0] t_alu_select_entry;
	reg [206:0] r_alu_sched_uops [3:0];
	reg [3:0] t_alu_entry_rdy;
	wire [LG_INT_SCHED_ENTRIES:0] t_alu_sched_select_ptr;
	reg [3:0] r_alu_srcA_rdy;
	reg [3:0] r_alu_srcB_rdy;
	reg [3:0] r_alu_srcC_rdy;
	reg [3:0] r_alu_hilo_rdy;
	reg [3:0] r_alu_fcr_rdy;
	reg [3:0] t_alu_srcA_match;
	reg [3:0] t_alu_srcB_match;
	reg [3:0] t_alu_srcC_match;
	reg [3:0] t_alu_hilo_match;
	reg [3:0] t_alu_fcr_match;
	reg t_alu_alloc_srcA_match;
	reg t_alu_alloc_srcB_match;
	reg t_alu_alloc_srcC_match;
	reg t_alu_alloc_hilo_match;
	reg t_alu_alloc_fcr_match;
	find_first_set #(LG_INT_SCHED_ENTRIES) ffs_int_sched_alloc(
		.in(~r_alu_sched_valid),
		.y(t_alu_sched_alloc_ptr)
	);
	fair_sched #(LG_INT_SCHED_ENTRIES) ffs_int_sched_select(
		.clk(clk),
		.rst(reset),
		.in(t_alu_entry_rdy),
		.y(t_alu_sched_select_ptr)
	);
	always @(*) begin
		t_alu_alloc_entry = 'd0;
		t_alu_select_entry = 'd0;
		if (t_pop_uq)
			t_alu_alloc_entry[t_alu_sched_alloc_ptr[1:0]] = 1'b1;
		if (t_alu_entry_rdy != 'd0)
			t_alu_select_entry[t_alu_sched_select_ptr[1:0]] = 1'b1;
	end
	always @(posedge clk) int_uop <= r_alu_sched_uops[t_alu_sched_select_ptr[1:0]];
	always @(posedge clk)
		if (reset)
			r_start_int <= 1'b0;
		else
			r_start_int <= (t_alu_entry_rdy != 'd0) & !ds_done;
	always @(*) begin
		t_alu_alloc_srcA_match = uq[192] && (((mem_rsp_dst_valid & (mem_rsp_dst_ptr == uq[198-:6])) || (t_gpr_prf_ptr_val_out & (t_gpr_prf_ptr_out == uq[198-:6]))) || (r_start_int && (t_wr_int_prf & (int_uop[174-:6] == uq[198-:6]))));
		t_alu_alloc_srcB_match = uq[184] && (((mem_rsp_dst_valid & (mem_rsp_dst_ptr == uq[190-:6])) || (t_gpr_prf_ptr_val_out & (t_gpr_prf_ptr_out == uq[190-:6]))) || (r_start_int && (t_wr_int_prf & (int_uop[174-:6] == uq[190-:6]))));
		t_alu_alloc_srcC_match = uq[176] && (((mem_rsp_dst_valid & (mem_rsp_dst_ptr == uq[182-:6])) || (t_gpr_prf_ptr_val_out & (t_gpr_prf_ptr_out == uq[182-:6]))) || (r_start_int && (t_wr_int_prf & (int_uop[174-:6] == uq[182-:6]))));
		t_alu_alloc_hilo_match = uq[161] && (((t_hilo_prf_ptr_val_out & (t_hilo_prf_ptr_out == uq[160-:2])) || (t_div_complete && (t_div_hilo_prf_ptr_out == uq[160-:2]))) || ((r_start_int && t_wr_hilo) && (int_uop[164-:2] == uq[160-:2])));
		t_alu_alloc_fcr_match = uq[162] && (t_fpu_fcr_valid & (t_fpu_fcr_ptr == uq[160-:2]));
	end
	genvar i;
	function is_div;
		input reg [7:0] op;
		reg x;
		begin
			case (op)
				8'd13: x = 1'b1;
				8'd14: x = 1'b1;
				default: x = 1'b0;
			endcase
			is_div = x;
		end
	endfunction
	function is_mult;
		input reg [7:0] op;
		reg x;
		begin
			case (op)
				8'd68: x = 1'b1;
				8'd66: x = 1'b1;
				8'd69: x = 1'b1;
				8'd11: x = 1'b1;
				8'd12: x = 1'b1;
				default: x = 1'b0;
			endcase
			is_mult = x;
		end
	endfunction
	generate
		for (i = 0; i < N_INT_SCHED_ENTRIES; i = i + 1) begin : genblk1
			always @(*) begin
				t_alu_srcA_match[i] = r_alu_sched_uops[i][192] && (((mem_rsp_dst_valid & (mem_rsp_dst_ptr == r_alu_sched_uops[i][198-:6])) || (t_gpr_prf_ptr_val_out & (t_gpr_prf_ptr_out == r_alu_sched_uops[i][198-:6]))) || (r_start_int && (t_wr_int_prf & (int_uop[174-:6] == r_alu_sched_uops[i][198-:6]))));
				t_alu_srcB_match[i] = r_alu_sched_uops[i][184] && (((mem_rsp_dst_valid & (mem_rsp_dst_ptr == r_alu_sched_uops[i][190-:6])) || (t_gpr_prf_ptr_val_out & (t_gpr_prf_ptr_out == r_alu_sched_uops[i][190-:6]))) || (r_start_int && (t_wr_int_prf & (int_uop[174-:6] == r_alu_sched_uops[i][190-:6]))));
				t_alu_srcC_match[i] = r_alu_sched_uops[i][176] && (((mem_rsp_dst_valid & (mem_rsp_dst_ptr == r_alu_sched_uops[i][182-:6])) || (t_gpr_prf_ptr_val_out & (t_gpr_prf_ptr_out == r_alu_sched_uops[i][182-:6]))) || (r_start_int && (t_wr_int_prf & (int_uop[174-:6] == r_alu_sched_uops[i][182-:6]))));
				t_alu_hilo_match[i] = r_alu_sched_uops[i][161] && (((t_hilo_prf_ptr_val_out & (t_hilo_prf_ptr_out == r_alu_sched_uops[i][160-:2])) || (t_div_complete && (t_div_hilo_prf_ptr_out == r_alu_sched_uops[i][160-:2]))) || ((r_start_int && t_wr_hilo) && (int_uop[164-:2] == r_alu_sched_uops[i][160-:2])));
				t_alu_fcr_match[i] = r_alu_sched_uops[i][162] && (t_fpu_fcr_valid & (t_fpu_fcr_ptr == r_alu_sched_uops[i][160-:2]));
				t_alu_entry_rdy[i] = (r_alu_sched_valid[i] && (is_div(r_alu_sched_uops[i][206-:8]) ? t_div_ready : (is_mult(r_alu_sched_uops[i][206-:8]) ? !r_wb_bitvec[3] : !r_wb_bitvec[1])) ? ((((t_alu_srcA_match[i] | r_alu_srcA_rdy[i]) & (t_alu_srcB_match[i] | r_alu_srcB_rdy[i])) & (t_alu_srcC_match[i] | r_alu_srcC_rdy[i])) & (t_alu_hilo_match[i] | r_alu_hilo_rdy[i])) & (t_alu_fcr_match[i] | r_alu_fcr_rdy[i]) : 1'b0);
			end
			always @(posedge clk)
				if (reset) begin
					r_alu_srcA_rdy[i] <= 1'b0;
					r_alu_srcB_rdy[i] <= 1'b0;
					r_alu_srcC_rdy[i] <= 1'b0;
					r_alu_hilo_rdy[i] <= 1'b0;
					r_alu_fcr_rdy[i] <= 1'b0;
				end
				else if (t_alu_alloc_entry[i]) begin
					r_alu_srcA_rdy[i] <= (uq[192] ? !r_prf_inflight[uq[198-:6]] | t_alu_alloc_srcA_match : 1'b1);
					r_alu_srcB_rdy[i] <= (uq[184] ? !r_prf_inflight[uq[190-:6]] | t_alu_alloc_srcB_match : 1'b1);
					r_alu_srcC_rdy[i] <= (uq[176] ? !r_prf_inflight[uq[182-:6]] | t_alu_alloc_srcC_match : 1'b1);
					r_alu_hilo_rdy[i] <= (uq[161] ? !r_hilo_inflight[uq[160-:2]] | t_alu_alloc_hilo_match : 1'b1);
					r_alu_fcr_rdy[i] <= (uq[162] ? !r_fcr_prf_inflight[uq[160-:2]] | t_alu_alloc_fcr_match : 1'b1);
				end
				else if (t_alu_select_entry[i]) begin
					r_alu_srcA_rdy[i] <= 1'b0;
					r_alu_srcB_rdy[i] <= 1'b0;
					r_alu_srcC_rdy[i] <= 1'b0;
					r_alu_hilo_rdy[i] <= 1'b0;
					r_alu_fcr_rdy[i] <= 1'b0;
				end
				else if (r_alu_sched_valid[i]) begin
					r_alu_srcA_rdy[i] <= r_alu_srcA_rdy[i] | t_alu_srcA_match[i];
					r_alu_srcB_rdy[i] <= r_alu_srcB_rdy[i] | t_alu_srcB_match[i];
					r_alu_srcC_rdy[i] <= r_alu_srcC_rdy[i] | t_alu_srcC_match[i];
					r_alu_hilo_rdy[i] <= r_alu_hilo_rdy[i] | t_alu_hilo_match[i];
					r_alu_fcr_rdy[i] <= r_alu_fcr_rdy[i] | t_alu_fcr_match[i];
				end
		end
	endgenerate
	always @(*) begin
		t_pop_uq = 1'b0;
		t_alu_sched_full = &r_alu_sched_valid;
		t_pop_uq = !((t_flash_clear || t_uq_empty) || t_alu_sched_full);
	end
	always @(posedge clk)
		if (reset || t_flash_clear)
			r_alu_sched_valid <= 'd0;
		else begin
			if (t_pop_uq) begin
				r_alu_sched_valid[t_alu_sched_alloc_ptr[1:0]] <= 1'b1;
				r_alu_sched_uops[t_alu_sched_alloc_ptr[1:0]] <= uq;
			end
			if (t_alu_entry_rdy != 'd0)
				r_alu_sched_valid[t_alu_sched_select_ptr[1:0]] <= 1'b0;
		end
	count_leading_zeros #(.LG_N(5)) c0(
		.in(t_srcA[31:0]),
		.y(w_clz)
	);
	shift_right #(.LG_W(5)) s0(
		.is_signed(t_signed_shift),
		.data(t_srcA[31:0]),
		.distance(t_shift_amt),
		.y(t_shift_right)
	);
	ext_mask em(
		.x(t_shift_right),
		.sz(int_uop[156:152]),
		.y(t_ext)
	);
	mul m(
		.clk(clk),
		.reset(reset),
		.opcode(int_uop[206-:8]),
		.go(t_start_mul & r_start_int),
		.src_A(t_srcA[31:0]),
		.src_B(t_srcB[31:0]),
		.src_hilo(t_src_hilo),
		.rob_ptr_in(int_uop[28-:5]),
		.gpr_prf_ptr_in(int_uop[174-:6]),
		.hilo_prf_ptr_in(int_uop[164-:2]),
		.y(t_mul_result),
		.complete(t_mul_complete),
		.rob_ptr_out(t_rob_ptr_out),
		.gpr_prf_ptr_val_out(t_gpr_prf_ptr_val_out),
		.gpr_prf_ptr_out(t_gpr_prf_ptr_out),
		.hilo_prf_ptr_val_out(t_hilo_prf_ptr_val_out),
		.hilo_prf_ptr_out(t_hilo_prf_ptr_out)
	);
	divider #(.LG_W(5)) d32(
		.clk(clk),
		.reset(reset),
		.srcA(t_srcA[31:0]),
		.srcB(t_srcB[31:0]),
		.rob_ptr_in(int_uop[28-:5]),
		.hilo_prf_ptr_in(int_uop[164-:2]),
		.is_signed_div(t_signed_div),
		.start_div(t_start_div32),
		.y(t_div_result),
		.rob_ptr_out(t_div_rob_ptr_out),
		.hilo_prf_ptr_out(t_div_hilo_prf_ptr_out),
		.complete(t_div_complete),
		.ready(t_div_ready)
	);
	assign divide_ready = t_div_ready;
	always @(*) begin
		n_mq_head_ptr = r_mq_head_ptr;
		n_mq_tail_ptr = r_mq_tail_ptr;
		if (t_push_mq)
			n_mq_tail_ptr = r_mq_tail_ptr + 'd1;
		if (mem_req_ack)
			n_mq_head_ptr = r_mq_head_ptr + 'd1;
		t_mem_head = r_mem_q[r_mq_head_ptr[2:0]];
		mem_q_empty = r_mq_head_ptr == r_mq_tail_ptr;
		mem_q_full = (r_mq_head_ptr != r_mq_tail_ptr) && (r_mq_head_ptr[2:0] == r_mq_tail_ptr[2:0]);
	end
	always @(posedge clk)
		if (t_push_mq)
			r_mem_q[r_mq_tail_ptr[2:0]] = t_mem_tail;
	assign mem_req = t_mem_head;
	assign mem_req_valid = !mem_q_empty;
	assign in_32fp_reg_mode = r_in_32fp_reg_mode;
	assign uq_wait = r_uq_wait;
	assign mq_wait = r_mq_wait;
	assign fq_wait = r_fq_wait;
	always @(posedge clk)
		if (reset) begin
			r_mq_head_ptr <= 'd0;
			r_mq_tail_ptr <= 'd0;
		end
		else begin
			r_mq_head_ptr <= n_mq_head_ptr;
			r_mq_tail_ptr <= n_mq_tail_ptr;
		end
	always @(posedge clk)
		if (reset) begin
			r_prf_inflight <= 'd0;
			r_fp_prf_inflight <= 'd0;
			r_hilo_inflight <= 'd0;
			r_fcr_prf_inflight <= 'd0;
		end
		else begin
			r_prf_inflight <= (ds_done ? 'd0 : n_prf_inflight);
			r_fp_prf_inflight <= (ds_done ? 'd0 : n_fp_prf_inflight);
			r_hilo_inflight <= (ds_done ? 'd0 : n_hilo_inflight);
			r_fcr_prf_inflight <= (ds_done ? 'd0 : n_fcr_prf_inflight);
		end
	always @(*) begin
		n_prf_inflight = r_prf_inflight;
		if (uq_push && uq_uop[168])
			n_prf_inflight[uq_uop[174-:6]] = 1'b1;
		if (uq_push_two && uq_uop_two[168])
			n_prf_inflight[uq_uop_two[174-:6]] = 1'b1;
		if (mem_rsp_dst_valid)
			n_prf_inflight[mem_rsp_dst_ptr] = 1'b0;
		if (t_gpr_prf_ptr_val_out)
			n_prf_inflight[t_gpr_prf_ptr_out] = 1'b0;
		if (r_start_int && t_wr_int_prf)
			n_prf_inflight[int_uop[174-:6]] = 1'b0;
	end
	always @(*) begin
		n_hilo_inflight = r_hilo_inflight;
		if (uq_push && uq_uop[165])
			n_hilo_inflight[uq_uop[164-:2]] = 1'b1;
		if (uq_push_two && uq_uop_two[165])
			n_hilo_inflight[uq_uop_two[164-:2]] = 1'b1;
		if (t_hilo_prf_ptr_val_out)
			n_hilo_inflight[t_hilo_prf_ptr_out] = 1'b0;
		if (t_div_complete)
			n_hilo_inflight[t_div_hilo_prf_ptr_out] = 1'b0;
		if (r_start_int && t_wr_hilo)
			n_hilo_inflight[int_uop[164-:2]] = 1'b0;
	end
	always @(*) begin
		n_fcr_prf_inflight = r_fcr_prf_inflight;
		if (uq_push && uq_uop[166])
			n_fcr_prf_inflight[uq_uop[164-:2]] = 1'b1;
		if (uq_push_two && uq_uop_two[166])
			n_fcr_prf_inflight[uq_uop_two[164-:2]] = 1'b1;
		if (t_fpu_fcr_valid)
			n_fcr_prf_inflight[t_fpu_fcr_ptr] = 1'b0;
	end
	always @(*) begin
		n_fp_prf_inflight = r_fp_prf_inflight;
		if (uq_push && uq_uop[167])
			n_fp_prf_inflight[uq_uop[174-:6]] = 1'b1;
		if (uq_push_two && uq_uop_two[167])
			n_fp_prf_inflight[uq_uop_two[174-:6]] = 1'b1;
		if (mem_rsp_fp_dst_valid)
			n_fp_prf_inflight[mem_rsp_dst_ptr] = 1'b0;
		if (t_fpu_result_valid)
			n_fp_prf_inflight[t_fpu_dst_ptr] = 1'b0;
		else if (t_sp_div_valid)
			n_fp_prf_inflight[t_sp_div_dst_ptr] = 1'b0;
		else if (t_dp_div_valid)
			n_fp_prf_inflight[t_dp_div_dst_ptr] = 1'b0;
		if (t_fp_wr_prf)
			n_fp_prf_inflight[fp_uq[174-:6]] = 1'b0;
	end
	always @(posedge clk)
		if (reset) begin : sv2v_autoblock_3
			integer i;
			for (i = 0; i < N_FCR_PRF_ENTRIES; i = i + 1)
				r_fcr_prf[i] <= 'd0;
		end
		else if (t_fpu_fcr_valid)
			r_fcr_prf[t_fpu_fcr_ptr] <= t_fpu_result[7:0];
	always @(*) begin
		n_in_32b_mode = r_in_32b_mode;
		n_in_32fp_reg_mode = r_in_32fp_reg_mode;
		t_pc = int_uop[92-:64];
		t_pc4 = int_uop[92-:64] + {{HI_EBITS {1'b0}}, 32'd4};
		t_pc8 = int_uop[92-:64] + {{HI_EBITS {1'b0}}, 32'd8};
		t_result = {64 {1'b0}};
		t_cpr0_result = {64 {1'b0}};
		t_set_thread_area = 1'b0;
		t_result32 = 32'd0;
		t_unimp_op = 1'b0;
		t_fault = 1'b0;
		t_simm = {{E_BITS {int_uop[156]}}, int_uop[156-:16]};
		t_wr_int_prf = 1'b0;
		t_wr_cpr0 = 1'b0;
		t_dst_cpr0 = int_uop[173:169];
		t_take_br = 1'b0;
		t_mispred_br = 1'b0;
		t_jaddr = {int_uop[102:93], int_uop[156-:16], 2'd0};
		t_alu_valid = 1'b0;
		t_hilo_result = 'd0;
		t_wr_hilo = 1'b0;
		t_got_break = 1'b0;
		t_got_syscall = 1'b0;
		t_signed_shift = 1'b0;
		t_shift_amt = 5'd0;
		t_start_mul = 1'b0;
		t_signed_div = 1'b0;
		t_start_div32 = 1'b0;
		case (int_uop[206-:8])
			8'd156: t_alu_valid = 1'b1;
			8'd101: begin
				t_alu_valid = 1'b1;
				t_got_break = 1'b1;
				t_fault = 1'b1;
			end
			8'd8: begin
				t_alu_valid = 1'b1;
				t_got_syscall = 1'b1;
				t_mispred_br = 1'b1;
				if (t_srcB == 'd4283) begin
					t_result = 'd0;
					t_set_thread_area = 1'b1;
					t_cpr0_result = monitor_rsp_data;
				end
				else
					t_result = monitor_rsp_data;
				t_wr_int_prf = 1'b1;
				t_pc = t_pc4;
			end
			8'd0: begin
				t_result = t_srcA << int_uop[190-:6];
				t_wr_int_prf = 1'b1;
				t_alu_valid = 1'b1;
			end
			8'd145: begin
				if (r_fcr_prf[int_uop[160-:2]][int_uop[179:177]] == 1'b1)
					t_result = t_srcA;
				else
					t_result = t_srcB;
				t_wr_int_prf = 1'b1;
				t_alu_valid = 1'b1;
			end
			8'd144: begin
				if (r_fcr_prf[int_uop[160-:2]][int_uop[179:177]] == 1'b1)
					t_result = t_srcB;
				else
					t_result = t_srcA;
				t_wr_int_prf = 1'b1;
				t_alu_valid = 1'b1;
			end
			8'd2: begin
				t_signed_shift = 1'b1;
				t_shift_amt = int_uop[189:185];
				t_result = {{HI_EBITS {t_shift_right[31]}}, t_shift_right};
				t_wr_int_prf = 1'b1;
				t_alu_valid = 1'b1;
			end
			8'd5: begin
				t_signed_shift = 1'b1;
				t_shift_amt = t_srcB[4:0];
				t_result = {{HI_EBITS {t_shift_right[31]}}, t_shift_right};
				t_wr_int_prf = 1'b1;
				t_alu_valid = 1'b1;
			end
			8'd1: begin
				t_result = t_srcA >> int_uop[190-:6];
				t_wr_int_prf = 1'b1;
				t_alu_valid = 1'b1;
			end
			8'd3: begin
				t_result = t_srcA << t_srcB[4:0];
				t_wr_int_prf = 1'b1;
				t_alu_valid = 1'b1;
			end
			8'd4: begin
				t_result = t_srcA >> t_srcB[4:0];
				t_wr_int_prf = 1'b1;
				t_alu_valid = 1'b1;
			end
			8'd26: begin
				t_hilo_result = {r_hilo_prf[int_uop[160-:2]][63:32], t_srcA[31:0]};
				t_wr_hilo = 1'b1;
				t_alu_valid = 1'b1;
			end
			8'd10: begin
				t_hilo_result = {t_srcA[31:0], r_hilo_prf[int_uop[160-:2]][31:0]};
				t_wr_hilo = 1'b1;
				t_alu_valid = 1'b1;
			end
			8'd25: begin
				t_result = {{HI_EBITS {1'b0}}, r_hilo_prf[int_uop[160-:2]][31:0]};
				t_wr_int_prf = 1'b1;
				t_alu_valid = 1'b1;
			end
			8'd9: begin
				t_result = {{HI_EBITS {1'b0}}, r_hilo_prf[int_uop[160-:2]][63:32]};
				t_wr_int_prf = 1'b1;
				t_alu_valid = 1'b1;
			end
			8'd16: begin
				t_result = t_srcA + t_srcB;
				t_wr_int_prf = 1'b1;
				t_alu_valid = 1'b1;
			end
			8'd77: begin
				t_result = t_srcA + t_srcB;
				t_wr_int_prf = 1'b1;
				t_alu_valid = 1'b1;
				t_unimp_op = r_in_32b_mode;
			end
			8'd70: begin
				t_result = {{58 {1'b0}}, w_clz};
				t_wr_int_prf = 1'b1;
				t_alu_valid = 1'b1;
			end
			8'd61: begin
				t_result = (t_srcA != 'd0 ? t_srcB : t_srcC);
				t_wr_int_prf = 1'b1;
				t_alu_valid = 1'b1;
			end
			8'd62: begin
				t_result = (t_srcA == 'd0 ? t_srcB : t_srcC);
				t_wr_int_prf = 1'b1;
				t_alu_valid = 1'b1;
			end
			8'd68: t_start_mul = r_start_int & !ds_done;
			8'd66: t_start_mul = r_start_int & !ds_done;
			8'd69: t_start_mul = r_start_int & !ds_done;
			8'd11: t_start_mul = r_start_int & !ds_done;
			8'd12: t_start_mul = r_start_int & !ds_done;
			8'd13: begin
				t_signed_div = 1'b1;
				t_start_div32 = r_start_int & !ds_done;
			end
			8'd14: t_start_div32 = r_start_int & !ds_done;
			8'd64: begin
				t_signed_shift = 1'b0;
				t_shift_amt = int_uop[151:147];
				t_result = {{HI_EBITS {t_ext[31]}}, t_ext};
				t_alu_valid = 1'b1;
				t_wr_int_prf = 1'b1;
			end
			8'd75: begin
				t_result = {{56 {t_srcA[7]}}, t_srcA[7:0]};
				t_wr_int_prf = 1'b1;
				t_alu_valid = 1'b1;
			end
			8'd76: begin
				t_result = {{E_BITS {t_srcA[15]}}, t_srcA[15:0]};
				t_wr_int_prf = 1'b1;
				t_alu_valid = 1'b1;
			end
			8'd18: begin
				t_result = t_srcA - t_srcB;
				t_wr_int_prf = 1'b1;
				t_alu_valid = 1'b1;
			end
			8'd79: begin
				t_result = t_srcA + t_srcB;
				t_wr_int_prf = 1'b1;
				t_alu_valid = 1'b1;
				t_unimp_op = r_in_32b_mode;
			end
			8'd19: begin
				t_result = t_srcA & t_srcB;
				t_wr_int_prf = 1'b1;
				t_alu_valid = 1'b1;
			end
			8'd154: begin
				t_result = t_srcA;
				t_wr_int_prf = 1'b1;
				t_alu_valid = 1'b1;
			end
			8'd20: begin
				t_result = t_srcA | t_srcB;
				t_wr_int_prf = 1'b1;
				t_alu_valid = 1'b1;
			end
			8'd21: begin
				t_result = t_srcA ^ t_srcB;
				t_wr_int_prf = 1'b1;
				t_alu_valid = 1'b1;
			end
			8'd22: begin
				t_result = ~(t_srcA | t_srcB);
				t_wr_int_prf = 1'b1;
				t_alu_valid = 1'b1;
			end
			8'd23: begin
				t_result = (r_in_32b_mode ? ($signed(t_srcB[31:0]) < $signed(t_srcA[31:0]) ? 'd1 : 'd0) : ($signed(t_srcB) < $signed(t_srcA) ? 'd1 : 'd0));
				t_wr_int_prf = 1'b1;
				t_alu_valid = 1'b1;
			end
			8'd24: begin
				t_result = (t_srcB < t_srcA ? 'd1 : 'd0);
				t_wr_int_prf = 1'b1;
				t_alu_valid = 1'b1;
			end
			8'd27: begin
				t_take_br = t_srcA == t_srcB;
				t_mispred_br = int_uop[21] != t_take_br;
				t_pc = (t_take_br ? t_pc4 + {t_simm[61:0], 2'd0} : t_pc8);
				t_alu_valid = 1'b1;
			end
			8'd53: begin
				t_take_br = t_srcA == t_srcB;
				t_mispred_br = (int_uop[21] != t_take_br) || !t_take_br;
				t_pc = (t_take_br ? t_pc4 + {t_simm[61:0], 2'd0} : t_pc8);
				t_alu_valid = 1'b1;
			end
			8'd28: begin
				t_take_br = t_srcA != t_srcB;
				t_mispred_br = int_uop[21] != t_take_br;
				t_pc = (t_take_br ? t_pc4 + {t_simm[61:0], 2'd0} : t_pc8);
				t_alu_valid = 1'b1;
			end
			8'd56: begin
				t_take_br = (r_in_32b_mode ? t_srcA[31] == 1'b0 : t_srcA[63] == 1'b0);
				t_mispred_br = int_uop[21] != t_take_br;
				t_pc = (t_take_br ? t_pc4 + {t_simm[61:0], 2'd0} : t_pc8);
				t_alu_valid = 1'b1;
			end
			8'd96: begin
				t_take_br = (r_in_32b_mode ? t_srcA[31] == 1'b0 : t_srcA[63] == 1'b0);
				t_mispred_br = int_uop[21] != t_take_br;
				t_pc = (t_take_br ? t_pc4 + {t_simm[61:0], 2'd0} : t_pc8);
				t_result = (t_take_br ? int_uop[92-:64] + {{HI_EBITS {1'b0}}, 32'd8} : t_srcB);
				t_alu_valid = 1'b1;
				t_wr_int_prf = 1'b1;
			end
			8'd95: begin
				t_take_br = 1'b1;
				t_mispred_br = int_uop[21] != t_take_br;
				t_pc = (t_take_br ? t_pc4 + {t_simm[61:0], 2'd0} : t_pc8);
				t_result = int_uop[92-:64] + {{HI_EBITS {1'b0}}, 32'd8};
				t_alu_valid = 1'b1;
				t_wr_int_prf = 1'b1;
			end
			8'd55: begin
				t_take_br = (r_in_32b_mode ? $signed(t_srcA[31:0]) < $signed(32'd0) : $signed(t_srcA) < $signed({64 {1'b0}}));
				t_mispred_br = int_uop[21] != t_take_br;
				t_pc = (t_take_br ? t_pc4 + {t_simm[61:0], 2'd0} : t_pc8);
				t_alu_valid = 1'b1;
			end
			8'd29: begin
				t_take_br = (r_in_32b_mode ? $signed(t_srcA[31:0]) <= $signed(32'd0) : $signed(t_srcA) <= $signed({64 {1'b0}}));
				t_mispred_br = int_uop[21] != t_take_br;
				t_pc = (t_take_br ? t_pc4 + {t_simm[61:0], 2'd0} : t_pc8);
				t_alu_valid = 1'b1;
			end
			8'd60: begin
				t_take_br = (r_in_32b_mode ? ($signed(t_srcA[31:0]) < $signed(32'd0)) || (t_srcA[31:0] == 32'd0) : ($signed(t_srcA) < $signed({64 {1'b0}})) || (t_srcA == {64 {1'b0}}));
				t_mispred_br = (int_uop[21] != t_take_br) || !t_take_br;
				t_pc = (t_take_br ? t_pc4 + {t_simm[61:0], 2'd0} : t_pc8);
				t_alu_valid = 1'b1;
			end
			8'd30: begin
				t_take_br = (r_in_32b_mode ? $signed(t_srcA[31:0]) > $signed(32'd0) : $signed(t_srcA) > $signed({64 {1'b0}}));
				t_mispred_br = int_uop[21] != t_take_br;
				t_pc = (t_take_br ? t_pc4 + {t_simm[61:0], 2'd0} : t_pc8);
				t_alu_valid = 1'b1;
			end
			8'd54: begin
				t_take_br = t_srcA != t_srcB;
				t_mispred_br = int_uop[21] != t_take_br;
				t_pc = (t_take_br ? t_pc4 + {t_simm[61:0], 2'd0} : t_pc8);
				t_alu_valid = 1'b1;
			end
			8'd57: begin
				t_take_br = (r_in_32b_mode ? $signed(t_srcA[31:0]) < $signed(32'd0) : $signed(t_srcA) < $signed({64 {1'b0}}));
				t_mispred_br = (int_uop[21] != t_take_br) || !t_take_br;
				t_pc = (t_take_br ? t_pc4 + {t_simm[61:0], 2'd0} : t_pc8);
				t_alu_valid = 1'b1;
			end
			8'd59: begin
				t_take_br = (r_in_32b_mode ? $signed(t_srcA[31:0]) > $signed(32'd0) : $signed(t_srcA) > $signed({64 {1'b0}}));
				t_mispred_br = (int_uop[21] != t_take_br) || !t_take_br;
				t_pc = (t_take_br ? t_pc4 + {t_simm[61:0], 2'd0} : t_pc8);
				t_alu_valid = 1'b1;
			end
			8'd58: begin
				t_take_br = (r_in_32b_mode ? $signed(t_srcA[31:0]) >= $signed(32'd0) : $signed(t_srcA) >= $signed({64 {1'b0}}));
				t_mispred_br = (int_uop[21] != t_take_br) || !t_take_br;
				t_pc = (t_take_br ? t_pc4 + {t_simm[61:0], 2'd0} : t_pc8);
				t_alu_valid = 1'b1;
			end
			8'd40: begin
				t_take_br = 1'b1;
				t_mispred_br = int_uop[21] != t_take_br;
				t_pc = {t_pc4[63:28], t_jaddr};
				t_result = int_uop[92-:64] + {{HI_EBITS {1'b0}}, 32'd8};
				t_alu_valid = 1'b1;
				t_wr_int_prf = 1'b1;
			end
			8'd6: begin
				t_take_br = 1'b1;
				t_mispred_br = t_srcA != {int_uop[140-:48], int_uop[156-:16]};
				t_pc = t_srcA;
				t_alu_valid = 1'b1;
			end
			8'd7: begin
				t_take_br = 1'b1;
				t_mispred_br = t_srcA != {int_uop[140-:48], int_uop[156-:16]};
				t_pc = t_srcA;
				t_alu_valid = 1'b1;
				t_result = int_uop[92-:64] + {{HI_EBITS {1'b0}}, 32'd8};
				t_wr_int_prf = 1'b1;
			end
			8'd155: begin
				t_take_br = 1'b1;
				t_mispred_br = 1'b1;
				t_pc = t_srcA;
				t_alu_valid = 1'b1;
				t_result = monitor_rsp_data;
				t_wr_int_prf = 1'b1;
			end
			8'd35: begin
				t_result = t_srcA & {{E_BITS {1'b0}}, int_uop[156-:16]};
				t_wr_int_prf = 1'b1;
				t_alu_valid = 1'b1;
			end
			8'd36: begin
				t_result = t_srcA | {{E_BITS {1'b0}}, int_uop[156-:16]};
				t_wr_int_prf = 1'b1;
				t_alu_valid = 1'b1;
			end
			8'd37: begin
				t_result = t_srcA ^ {{E_BITS {1'b0}}, int_uop[156-:16]};
				t_wr_int_prf = 1'b1;
				t_alu_valid = 1'b1;
			end
			8'd38: begin
				t_result = {{HI_EBITS {int_uop[156]}}, int_uop[156-:16], 16'd0};
				t_wr_int_prf = 1'b1;
				t_alu_valid = 1'b1;
			end
			8'd32: begin
				t_result32 = t_srcA[31:0] + t_simm[31:0];
				t_result = {{HI_EBITS {t_result32[31]}}, t_result32};
				t_wr_int_prf = 1'b1;
				t_alu_valid = 1'b1;
			end
			8'd153: begin
				t_result = {{HI_EBITS {t_simm[31]}}, t_simm[31:0]};
				t_wr_int_prf = 1'b1;
				t_alu_valid = 1'b1;
			end
			8'd78: begin
				t_result = t_srcA + t_simm;
				t_wr_int_prf = 1'b1;
				t_alu_valid = 1'b1;
				t_unimp_op = r_in_32b_mode;
			end
			8'd33: begin
				t_result = (r_in_32b_mode ? ($signed(t_srcA[31:0]) < $signed(t_simm[31:0]) ? 'd1 : 'd0) : ($signed(t_srcA) < $signed(t_simm) ? 'd1 : 'd0));
				t_wr_int_prf = 1'b1;
				t_alu_valid = 1'b1;
			end
			8'd34: begin
				t_result = (r_in_32b_mode ? (t_srcA[31:0] < t_simm[31:0] ? 'd1 : 'd0) : (t_srcA < t_simm ? 'd1 : 'd0));
				t_wr_int_prf = 1'b1;
				t_alu_valid = 1'b1;
			end
			8'd41: begin
				t_result = t_cpr0_srcA;
				t_alu_valid = 1'b1;
				t_wr_int_prf = 1'b1;
				t_pc = t_pc4;
			end
			8'd157: begin
				t_result = t_cpr0_srcA;
				t_alu_valid = 1'b1;
				t_wr_int_prf = int_uop[168];
				t_pc = t_pc4;
				t_wr_cpr0 = 1'b1;
				t_dst_cpr0 = 'd12;
				t_cpr0_result = {t_cpr0_srcA[63:1], 1'b0};
			end
			8'd158: begin
				t_result = t_cpr0_srcA;
				t_alu_valid = 1'b1;
				t_wr_int_prf = int_uop[168];
				t_pc = t_pc4;
				t_wr_cpr0 = 1'b1;
				t_dst_cpr0 = 'd12;
				t_cpr0_result = {t_cpr0_srcA[63:1], 1'b1};
			end
			8'd159: begin
				t_unimp_op = 1'b1;
				t_alu_valid = 1'b1;
				t_fault = 1'b1;
				t_pc = t_pc4;
			end
			8'd98: begin
				t_result = t_cpr0_srcA;
				t_wr_int_prf = 1'b1;
				t_alu_valid = 1'b1;
			end
			8'd42: begin
				t_wr_cpr0 = 1'b1;
				if (int_uop[173:169] == 5'd12) begin
					n_in_32b_mode = t_srcA[5] == 1'b0;
					n_in_32fp_reg_mode = t_srcA[26] == 1'b1;
				end
				t_cpr0_result = t_srcA;
				t_alu_valid = 1'b1;
				t_pc = t_pc4;
			end
			8'd160: begin
				t_unimp_op = 1'b1;
				t_alu_valid = 1'b1;
			end
			8'd128: begin
				t_take_br = r_fcr_prf[int_uop[160-:2]][int_uop[179:177]];
				t_mispred_br = int_uop[21] != t_take_br;
				t_pc = (t_take_br ? t_pc4 + {t_simm[61:0], 2'd0} : t_pc8);
				t_alu_valid = 1'b1;
			end
			8'd131: begin
				t_take_br = r_fcr_prf[int_uop[160-:2]][int_uop[179:177]] == 1'b0;
				t_mispred_br = int_uop[21] != t_take_br;
				t_pc = (t_take_br ? t_pc4 + {t_simm[61:0], 2'd0} : t_pc8);
				t_alu_valid = 1'b1;
			end
			8'd130: begin
				t_take_br = r_fcr_prf[int_uop[160-:2]][int_uop[179:177]] == 1'b0;
				t_mispred_br = int_uop[21] != t_take_br;
				t_pc = (t_take_br ? t_pc4 + {t_simm[61:0], 2'd0} : t_pc8);
				t_alu_valid = 1'b1;
			end
			8'd129: begin
				t_take_br = r_fcr_prf[int_uop[160-:2]][int_uop[179:177]];
				t_mispred_br = int_uop[21] != t_take_br;
				t_pc = (t_take_br ? t_pc4 + {t_simm[61:0], 2'd0} : t_pc8);
				t_alu_valid = 1'b1;
			end
			default: begin
				t_unimp_op = 1'b1;
				t_alu_valid = 1'b1;
			end
		endcase
	end
	always @(*) begin
		t_start_fpu = 1'b0;
		t_fp_wr_prf = 1'b0;
		t_pop_fp_uq = 1'b0;
		t_fp_srcs_rdy = 1'b0;
		t_fp_result = 64'd0;
	end
	always @(*) begin
		t_pop_mem_uq = 1'b0;
		t_mem_simm = {{E_BITS {mem_uq[156]}}, mem_uq[156-:16]};
		t_push_mq = 1'b0;
		t_mem_tail[177-:5] = 5'd4;
		t_mem_tail[245-:64] = 'd0;
		t_mem_tail[172-:64] = 'd0;
		t_mem_tail[108-:5] = mem_uq[28-:5];
		t_mem_tail[97] = 1'b0;
		t_mem_tail[96] = 1'b0;
		t_mem_tail[103-:6] = mem_uq[174-:6];
		t_mem_tail[180] = 1'b0;
		t_mem_tail[178] = 1'b0;
		t_mem_tail[181] = 1'b0;
		t_mem_tail[179] = 1'b0;
		t_mem_tail[95-:64] = mem_uq[92-:64];
		t_mem_tail[31-:32] = r_cycle;
		t_mem_srcs_rdy = 1'b0;
		case (mem_uq[206-:8])
			8'd50:
				if (!((mem_q_full || r_prf_inflight[mem_uq[198-:6]]) || r_prf_inflight[mem_uq[190-:6]])) begin
					t_mem_tail[177-:5] = 5'd5;
					t_mem_tail[180] = 1'b1;
					t_mem_tail[245-:64] = t_mem_srcA + t_mem_simm;
					t_mem_tail[172-:64] = {{Z_BITS {1'b0}}, t_mem_srcB};
					t_mem_tail[108-:5] = mem_uq[28-:5];
					t_mem_tail[97] = 1'b0;
					t_mem_srcs_rdy = !(r_prf_inflight[mem_uq[198-:6]] || r_prf_inflight[mem_uq[190-:6]]);
					t_push_mq = !t_mem_uq_empty & t_mem_srcs_rdy;
				end
			8'd51:
				if (!((mem_q_full || r_prf_inflight[mem_uq[198-:6]]) || r_prf_inflight[mem_uq[190-:6]])) begin
					t_mem_tail[177-:5] = 5'd6;
					t_mem_tail[180] = 1'b1;
					t_mem_tail[245-:64] = t_mem_srcA + t_mem_simm;
					t_mem_tail[172-:64] = {{Z_BITS {1'b0}}, t_mem_srcB};
					t_mem_tail[108-:5] = mem_uq[28-:5];
					t_mem_tail[97] = 1'b0;
					t_mem_srcs_rdy = !(r_prf_inflight[mem_uq[198-:6]] || r_prf_inflight[mem_uq[190-:6]]);
					t_push_mq = !t_mem_uq_empty & t_mem_srcs_rdy;
				end
			8'd52:
				if (!((mem_q_full || r_prf_inflight[mem_uq[198-:6]]) || r_prf_inflight[mem_uq[190-:6]])) begin
					t_mem_tail[177-:5] = 5'd7;
					t_mem_tail[180] = 1'b1;
					t_mem_tail[245-:64] = t_mem_srcA + t_mem_simm;
					t_mem_tail[172-:64] = {{Z_BITS {1'b0}}, t_mem_srcB};
					t_mem_tail[108-:5] = mem_uq[28-:5];
					t_mem_tail[97] = 1'b0;
					t_mem_srcs_rdy = !(r_prf_inflight[mem_uq[198-:6]] || r_prf_inflight[mem_uq[190-:6]]);
					t_push_mq = !t_mem_uq_empty & t_mem_srcs_rdy;
				end
			8'd102:
				if (!((mem_q_full || r_prf_inflight[mem_uq[198-:6]]) || r_fp_prf_inflight[mem_uq[190-:6]])) begin
					t_mem_tail[177-:5] = 5'd14;
					t_mem_tail[180] = 1'b1;
					t_mem_tail[245-:64] = t_mem_srcA + t_mem_simm;
					t_mem_tail[172-:64] = t_mem_fp_srcB;
					t_mem_tail[108-:5] = mem_uq[28-:5];
					t_mem_tail[97] = 1'b0;
					t_mem_srcs_rdy = !(r_prf_inflight[mem_uq[198-:6]] || r_fp_prf_inflight[mem_uq[190-:6]]);
					t_push_mq = !t_mem_uq_empty & t_mem_srcs_rdy;
					t_mem_tail[179] = 1'b1;
				end
			8'd107:
				if (!((mem_q_full || r_prf_inflight[mem_uq[198-:6]]) || r_fp_prf_inflight[mem_uq[190-:6]])) begin
					t_mem_tail[177-:5] = 5'd20;
					t_mem_tail[180] = 1'b1;
					t_mem_tail[178] = mem_uq[93];
					t_mem_tail[245-:64] = t_mem_srcA + t_mem_simm;
					t_mem_tail[172-:64] = t_mem_fp_srcB;
					t_mem_tail[108-:5] = mem_uq[28-:5];
					t_mem_tail[97] = 1'b0;
					t_mem_srcs_rdy = !(r_prf_inflight[mem_uq[198-:6]] || r_fp_prf_inflight[mem_uq[190-:6]]);
					t_push_mq = !t_mem_uq_empty & t_mem_srcs_rdy;
					t_mem_tail[179] = 1'b1;
				end
			8'd100:
				if (mem_q_empty) begin
					t_mem_tail[177-:5] = 5'd23;
					t_mem_tail[245-:64] = 'd0;
					t_mem_tail[108-:5] = mem_uq[28-:5];
					t_mem_tail[97] = 1'b0;
					t_mem_srcs_rdy = 1'b1;
					t_push_mq = !t_mem_uq_empty;
				end
			8'd99:
				if (!((mem_q_full || r_prf_inflight[mem_uq[198-:6]]) || r_prf_inflight[mem_uq[190-:6]])) begin
					t_mem_tail[177-:5] = 5'd13;
					t_mem_tail[180] = 1'b1;
					t_mem_tail[245-:64] = t_mem_srcA + t_mem_simm;
					t_mem_tail[172-:64] = {{Z_BITS {1'b0}}, t_mem_srcB};
					t_mem_tail[108-:5] = mem_uq[28-:5];
					t_mem_srcs_rdy = !(r_prf_inflight[mem_uq[198-:6]] || r_prf_inflight[mem_uq[190-:6]]);
					t_mem_tail[97] = 1'b1;
					t_mem_tail[103-:6] = mem_uq[174-:6];
					t_push_mq = !t_mem_uq_empty & t_mem_srcs_rdy;
				end
			8'd74:
				if (!((mem_q_full || r_prf_inflight[mem_uq[198-:6]]) || r_prf_inflight[mem_uq[190-:6]])) begin
					t_mem_tail[177-:5] = 5'd8;
					t_mem_tail[180] = 1'b1;
					t_mem_tail[245-:64] = t_mem_srcA + t_mem_simm;
					t_mem_tail[172-:64] = {{Z_BITS {1'b0}}, t_mem_srcB};
					t_mem_tail[108-:5] = mem_uq[28-:5];
					t_mem_tail[97] = 1'b0;
					t_mem_srcs_rdy = !(r_prf_inflight[mem_uq[198-:6]] || r_prf_inflight[mem_uq[190-:6]]);
					t_push_mq = !t_mem_uq_empty & t_mem_srcs_rdy;
				end
			8'd73:
				if (!((mem_q_full || r_prf_inflight[mem_uq[198-:6]]) || r_prf_inflight[mem_uq[190-:6]])) begin
					t_mem_tail[177-:5] = 5'd9;
					t_mem_tail[180] = 1'b1;
					t_mem_tail[245-:64] = t_mem_srcA + t_mem_simm;
					t_mem_tail[172-:64] = {{Z_BITS {1'b0}}, t_mem_srcB};
					t_mem_tail[108-:5] = mem_uq[28-:5];
					t_mem_tail[97] = 1'b0;
					t_mem_srcs_rdy = !(r_prf_inflight[mem_uq[198-:6]] || r_prf_inflight[mem_uq[190-:6]]);
					t_push_mq = !t_mem_uq_empty & t_mem_srcs_rdy;
				end
			8'd45:
				if (!(mem_q_full || r_prf_inflight[mem_uq[198-:6]])) begin
					t_mem_tail[177-:5] = 5'd4;
					t_mem_tail[245-:64] = t_mem_srcA + t_mem_simm;
					t_mem_tail[108-:5] = mem_uq[28-:5];
					t_mem_tail[97] = 1'b1;
					t_mem_tail[103-:6] = mem_uq[174-:6];
					t_mem_srcs_rdy = !r_prf_inflight[mem_uq[198-:6]];
					t_push_mq = !t_mem_uq_empty & t_mem_srcs_rdy;
				end
			8'd103:
				if (!(mem_q_full || r_prf_inflight[mem_uq[198-:6]])) begin
					t_mem_tail[177-:5] = 5'd15;
					t_mem_tail[245-:64] = t_mem_srcA + t_mem_simm;
					t_mem_tail[108-:5] = mem_uq[28-:5];
					t_mem_tail[96] = 1'b1;
					t_mem_tail[103-:6] = mem_uq[174-:6];
					t_mem_srcs_rdy = !r_prf_inflight[mem_uq[198-:6]];
					t_push_mq = !t_mem_uq_empty & t_mem_srcs_rdy;
					t_mem_tail[179] = 1'b1;
				end
			8'd106:
				if (!((mem_q_full || r_prf_inflight[mem_uq[198-:6]]) || r_fp_prf_inflight[mem_uq[190-:6]])) begin
					t_mem_tail[177-:5] = 5'd19;
					t_mem_tail[178] = mem_uq[93];
					t_mem_tail[172-:64] = t_mem_fp_srcB;
					t_mem_tail[245-:64] = t_mem_srcA + t_mem_simm;
					t_mem_tail[108-:5] = mem_uq[28-:5];
					t_mem_tail[96] = 1'b1;
					t_mem_tail[103-:6] = mem_uq[174-:6];
					t_mem_srcs_rdy = !(r_prf_inflight[mem_uq[198-:6]] || r_fp_prf_inflight[mem_uq[190-:6]]);
					t_push_mq = !t_mem_uq_empty & t_mem_srcs_rdy;
					t_mem_tail[179] = 1'b1;
				end
			8'd71:
				if (!((mem_q_full || r_prf_inflight[mem_uq[198-:6]]) || r_prf_inflight[mem_uq[190-:6]])) begin
					t_mem_tail[177-:5] = 5'd11;
					t_mem_tail[245-:64] = t_mem_srcA + t_mem_simm;
					t_mem_tail[108-:5] = mem_uq[28-:5];
					t_mem_tail[97] = 1'b1;
					t_mem_tail[103-:6] = mem_uq[174-:6];
					t_mem_tail[172-:64] = {{Z_BITS {1'b0}}, t_mem_srcB};
					t_mem_srcs_rdy = !r_prf_inflight[mem_uq[198-:6]];
					t_push_mq = !t_mem_uq_empty & t_mem_srcs_rdy;
				end
			8'd72:
				if (!((mem_q_full || r_prf_inflight[mem_uq[198-:6]]) || r_prf_inflight[mem_uq[190-:6]])) begin
					t_mem_tail[177-:5] = 5'd10;
					t_mem_tail[245-:64] = t_mem_srcA + t_mem_simm;
					t_mem_tail[108-:5] = mem_uq[28-:5];
					t_mem_tail[97] = 1'b1;
					t_mem_tail[103-:6] = mem_uq[174-:6];
					t_mem_tail[172-:64] = {{Z_BITS {1'b0}}, t_mem_srcB};
					t_mem_srcs_rdy = !r_prf_inflight[mem_uq[198-:6]];
					t_push_mq = !t_mem_uq_empty & t_mem_srcs_rdy;
				end
			8'd46:
				if (!(mem_q_full || r_prf_inflight[mem_uq[198-:6]])) begin
					t_mem_tail[177-:5] = 5'd0;
					t_mem_tail[245-:64] = t_mem_srcA + t_mem_simm;
					t_mem_tail[108-:5] = mem_uq[28-:5];
					t_mem_tail[97] = 1'b1;
					t_mem_tail[103-:6] = mem_uq[174-:6];
					t_mem_srcs_rdy = !r_prf_inflight[mem_uq[198-:6]];
					t_push_mq = !t_mem_uq_empty & t_mem_srcs_rdy;
				end
			8'd47:
				if (!(mem_q_full || r_prf_inflight[mem_uq[198-:6]])) begin
					t_mem_tail[177-:5] = 5'd1;
					t_mem_tail[245-:64] = t_mem_srcA + t_mem_simm;
					t_mem_tail[108-:5] = mem_uq[28-:5];
					t_mem_tail[97] = 1'b1;
					t_mem_tail[103-:6] = mem_uq[174-:6];
					t_mem_srcs_rdy = !r_prf_inflight[mem_uq[198-:6]];
					t_push_mq = !t_mem_uq_empty & t_mem_srcs_rdy;
				end
			8'd49:
				if (!(mem_q_full || r_prf_inflight[mem_uq[198-:6]])) begin
					t_mem_tail[177-:5] = 5'd3;
					t_mem_tail[245-:64] = t_mem_srcA + t_mem_simm;
					t_mem_tail[108-:5] = mem_uq[28-:5];
					t_mem_tail[97] = 1'b1;
					t_mem_tail[103-:6] = mem_uq[174-:6];
					t_mem_srcs_rdy = !r_prf_inflight[mem_uq[198-:6]];
					t_push_mq = !t_mem_uq_empty & t_mem_srcs_rdy;
				end
			8'd48:
				if (!(mem_q_full || r_prf_inflight[mem_uq[198-:6]])) begin
					t_mem_tail[177-:5] = 5'd2;
					t_mem_tail[245-:64] = t_mem_srcA + t_mem_simm;
					t_mem_tail[108-:5] = mem_uq[28-:5];
					t_mem_tail[97] = 1'b1;
					t_mem_tail[103-:6] = mem_uq[174-:6];
					t_mem_srcs_rdy = !r_prf_inflight[mem_uq[198-:6]];
					t_push_mq = !t_mem_uq_empty & t_mem_srcs_rdy;
				end
			8'd152:
				if (!(mem_q_full || r_fp_prf_inflight[mem_uq[190-:6]])) begin
					t_mem_tail[177-:5] = 5'd22;
					t_mem_tail[178] = mem_uq[93];
					t_mem_tail[172-:64] = t_mem_fp_srcB;
					t_mem_tail[108-:5] = mem_uq[28-:5];
					t_mem_tail[97] = 1'b1;
					t_mem_tail[103-:6] = mem_uq[174-:6];
					t_mem_srcs_rdy = !r_fp_prf_inflight[mem_uq[190-:6]];
					t_push_mq = !t_mem_uq_empty & t_mem_srcs_rdy;
					t_mem_tail[179] = 1'b1;
				end
			8'd151:
				if (!((mem_q_full || r_prf_inflight[mem_uq[198-:6]]) || r_fp_prf_inflight[mem_uq[190-:6]])) begin
					t_mem_tail[177-:5] = 5'd21;
					t_mem_tail[178] = mem_uq[93];
					t_mem_tail[172-:64] = t_mem_fp_srcB;
					t_mem_tail[245-:64] = t_mem_srcA;
					t_mem_tail[108-:5] = mem_uq[28-:5];
					t_mem_tail[96] = 1'b1;
					t_mem_tail[103-:6] = mem_uq[174-:6];
					t_mem_srcs_rdy = !(r_prf_inflight[mem_uq[198-:6]] || r_fp_prf_inflight[mem_uq[190-:6]]);
					t_push_mq = !t_mem_uq_empty & t_mem_srcs_rdy;
					t_mem_tail[179] = 1'b1;
				end
			default:
				;
		endcase
		t_pop_mem_uq = (t_mem_uq_empty || t_flash_clear ? 1'b0 : (!t_mem_srcs_rdy ? 1'b0 : 1'b1));
	end
	initial begin : sv2v_autoblock_4
		integer i;
		for (i = 0; i < N_INT_PRF_ENTRIES; i = i + 1)
			r_int_prf[i] = 'd0;
	end
	always @(posedge clk) begin
		if (r_start_int && t_wr_int_prf)
			r_int_prf[int_uop[174-:6]] <= (r_in_32b_mode ? {{HI_EBITS {1'b0}}, t_result[31:0]} : t_result);
		else if (t_gpr_prf_ptr_val_out)
			r_int_prf[t_gpr_prf_ptr_out] <= (r_in_32b_mode ? {{HI_EBITS {1'b0}}, t_mul_result[31:0]} : {{HI_EBITS {t_mul_result[31]}}, t_mul_result[31:0]});
		if (mem_rsp_dst_valid)
			r_int_prf[mem_rsp_dst_ptr] <= (r_in_32b_mode ? {{HI_EBITS {1'b0}}, mem_rsp_load_data[31:0]} : mem_rsp_load_data[63:0]);
		else if (t_got_syscall && r_start_int)
			r_int_prf[int_uop[198-:6]] <= 'd0;
	end
	initial begin : sv2v_autoblock_5
		integer i;
		for (i = 0; i < N_HILO_PRF_ENTRIES; i = i + 1)
			r_hilo_prf[i] = 'd0;
	end
	always @(posedge clk)
		if (r_start_int && t_wr_hilo)
			r_hilo_prf[int_uop[164-:2]] <= t_hilo_result;
		else if (t_hilo_prf_ptr_val_out)
			r_hilo_prf[t_hilo_prf_ptr_out] <= t_mul_result;
		else if (t_div_complete)
			r_hilo_prf[t_div_hilo_prf_ptr_out] <= t_div_result;
	always @(posedge clk)
		if (reset)
			cpr0_status_reg <= 'd4194308;
		else if ((r_start_int && t_wr_cpr0) && (t_dst_cpr0 == 'd12))
			cpr0_status_reg <= t_cpr0_result;
	always @(posedge clk)
		if (reset)
			r_cpr0['d12] <= 'd4194308;
		else if (r_start_int && t_wr_cpr0)
			r_cpr0[t_dst_cpr0] <= t_cpr0_result;
		else if (r_start_int && t_set_thread_area)
			r_cpr0['d29] <= t_cpr0_result;
		else if (exception_wr_cpr0_val)
			r_cpr0[exception_wr_cpr0_ptr] <= exception_wr_cpr0_data;
	always @(posedge clk) begin
		if (t_fp_wr_prf)
			r_fp_prf[fp_uq[174-:6]] <= t_fp_result;
		else if (t_fpu_result_valid)
			r_fp_prf[t_fpu_dst_ptr] <= t_fpu_result;
		else if (t_sp_div_valid)
			r_fp_prf[t_sp_div_dst_ptr] <= {32'd0, t_sp_div_result};
		else if (t_dp_div_valid)
			r_fp_prf[t_dp_div_dst_ptr] <= t_dp_div_result;
		if (mem_rsp_fp_dst_valid)
			r_fp_prf[mem_rsp_dst_ptr] <= mem_rsp_load_data;
	end
	always @(posedge clk)
		if (reset)
			complete_valid_1 <= 1'b0;
		else
			complete_valid_1 <= ((r_start_int && t_alu_valid) || t_mul_complete) || t_div_complete;
	always @(posedge clk)
		if (t_mul_complete || t_div_complete) begin
			complete_bundle_1[137-:5] <= (t_mul_complete ? t_rob_ptr_out : t_div_rob_ptr_out);
			complete_bundle_1[132] <= 1'b1;
			complete_bundle_1[131] <= 1'b0;
			complete_bundle_1[130-:64] <= 'd0;
			complete_bundle_1[65] <= 1'b0;
			complete_bundle_1[66] <= 1'b0;
			complete_bundle_1[64] <= 1'b0;
			complete_bundle_1[63-:64] <= t_mul_result[63:0];
		end
		else begin
			complete_bundle_1[137-:5] <= int_uop[28-:5];
			complete_bundle_1[132] <= t_alu_valid;
			complete_bundle_1[131] <= (t_mispred_br || t_unimp_op) || t_fault;
			complete_bundle_1[130-:64] <= t_pc;
			complete_bundle_1[65] <= t_unimp_op;
			complete_bundle_1[66] <= t_take_br;
			complete_bundle_1[64] <= 1'b0;
			complete_bundle_1[63-:64] <= (r_in_32b_mode ? {{HI_EBITS {1'b0}}, t_result[31:0]} : t_result);
		end
	always @(posedge clk)
		if (reset)
			complete_valid_2 <= 1'b0;
		else
			complete_valid_2 <= (((t_fp_wr_prf || t_fpu_result_valid) || t_fpu_fcr_valid) || t_sp_div_valid) || t_dp_div_valid;
	always @(posedge clk)
		if (t_fpu_result_valid || t_fpu_fcr_valid) begin
			complete_bundle_2[137-:5] <= t_fpu_rob_ptr;
			complete_bundle_2[132] <= 1'b1;
			complete_bundle_2[131] <= 1'b0;
			complete_bundle_2[130-:64] <= 'd0;
			complete_bundle_2[65] <= 1'b0;
			complete_bundle_2[66] <= 1'b0;
			complete_bundle_2[64] <= 1'b0;
			complete_bundle_2[63-:64] <= t_fpu_result;
		end
		else if (t_sp_div_valid) begin
			complete_bundle_2[137-:5] <= t_sp_div_rob_ptr;
			complete_bundle_2[132] <= 1'b1;
			complete_bundle_2[131] <= 1'b0;
			complete_bundle_2[130-:64] <= 'd0;
			complete_bundle_2[65] <= 1'b0;
			complete_bundle_2[66] <= 1'b0;
			complete_bundle_2[64] <= 1'b0;
			complete_bundle_2[63-:64] <= {32'd0, t_sp_div_result};
		end
		else if (t_dp_div_valid) begin
			complete_bundle_2[137-:5] <= t_dp_div_rob_ptr;
			complete_bundle_2[132] <= 1'b1;
			complete_bundle_2[131] <= 1'b0;
			complete_bundle_2[130-:64] <= 'd0;
			complete_bundle_2[65] <= 1'b0;
			complete_bundle_2[66] <= 1'b0;
			complete_bundle_2[64] <= 1'b0;
			complete_bundle_2[63-:64] <= t_dp_div_result;
		end
		else begin
			complete_bundle_2[137-:5] <= fp_uq[28-:5];
			complete_bundle_2[132] <= 1'b1;
			complete_bundle_2[131] <= 1'b0;
			complete_bundle_2[130-:64] <= 'd0;
			complete_bundle_2[65] <= 1'b0;
			complete_bundle_2[66] <= 1'b0;
			complete_bundle_2[64] <= 1'b0;
			complete_bundle_2[63-:64] <= t_fp_result;
		end
endmodule

module l1d (
	clk,
	reset,
	head_of_rob_ptr,
	head_of_rob_ptr_valid,
	retired_rob_ptr_valid,
	retired_rob_ptr_two_valid,
	retired_rob_ptr,
	retired_rob_ptr_two,
	restart_valid,
	memq_empty,
	drain_ds_complete,
	dead_rob_mask,
	flush_req,
	flush_complete,
	flush_cl_req,
	flush_cl_addr,
	core_mem_req_valid,
	core_mem_req,
	core_mem_req_ack,
	core_mem_rsp,
	core_mem_rsp_valid,
	mem_req_ack,
	mem_req_valid,
	mem_req_addr,
	mem_req_store_data,
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
	cache_hits,
	cache_hits_under_miss
);
	localparam L1D_NUM_SETS = 4096;
	localparam L1D_CL_LEN = 16;
	localparam L1D_CL_LEN_BITS = 128;
	input wire clk;
	input wire reset;
	input wire [4:0] head_of_rob_ptr;
	input wire head_of_rob_ptr_valid;
	input wire retired_rob_ptr_valid;
	input wire retired_rob_ptr_two_valid;
	input wire [4:0] retired_rob_ptr;
	input wire [4:0] retired_rob_ptr_two;
	input wire restart_valid;
	output reg memq_empty;
	input wire drain_ds_complete;
	input wire [31:0] dead_rob_mask;
	input wire flush_cl_req;
	input wire [63:0] flush_cl_addr;
	input wire flush_req;
	output wire flush_complete;
	input wire core_mem_req_valid;
	input wire [245:0] core_mem_req;
	output reg core_mem_req_ack;
	output wire [151:0] core_mem_rsp;
	output wire core_mem_rsp_valid;
	input wire mem_req_ack;
	output wire mem_req_valid;
	output wire [63:0] mem_req_addr;
	output wire [127:0] mem_req_store_data;
	output wire [1:0] mem_req_tag;
	output wire [4:0] mem_req_opcode;
	input wire mem_rsp_valid;
	input wire [127:0] mem_rsp_load_data;
	input wire [1:0] mem_rsp_tag;
	input wire [4:0] mem_rsp_opcode;
	output wire utlb_miss_req;
	output wire [51:0] utlb_miss_paddr;
	input wire tlb_rsp_valid;
	input wire [56:0] tlb_rsp;
	output wire [63:0] cache_accesses;
	output wire [63:0] cache_hits;
	output wire [63:0] cache_hits_under_miss;
	localparam LG_WORDS_PER_CL = 2;
	localparam LG_DWORDS_PER_CL = 1;
	localparam WORDS_PER_CL = 4;
	localparam N_TAG_BITS = 48;
	localparam IDX_START = 4;
	localparam IDX_STOP = 16;
	localparam WORD_START = 2;
	localparam WORD_STOP = 4;
	localparam DWORD_START = 3;
	localparam DWORD_STOP = 4;
	localparam N_MQ_ENTRIES = 8;
	function [127:0] merge_cl64;
		input reg [127:0] cl;
		input reg [63:0] w64;
		input reg pos;
		reg [127:0] cl_out;
		begin
			case (pos)
				1'b0: cl_out = {cl[127:64], w64};
				1'b1: cl_out = {w64, cl[63:0]};
			endcase
			merge_cl64 = cl_out;
		end
	endfunction
	function [127:0] merge_cl32;
		input reg [127:0] cl;
		input reg [31:0] w32;
		input reg [1:0] pos;
		reg [127:0] cl_out;
		begin
			case (pos)
				2'd0: cl_out = {cl[127:32], w32};
				2'd1: cl_out = {cl[127:64], w32, cl[31:0]};
				2'd2: cl_out = {cl[127:96], w32, cl[63:0]};
				2'd3: cl_out = {w32, cl[95:0]};
			endcase
			merge_cl32 = cl_out;
		end
	endfunction
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
	function [63:0] select_cl64;
		input reg [127:0] cl;
		input reg pos;
		reg [63:0] w64;
		begin
			case (pos)
				1'b0: w64 = cl[63:0];
				1'b1: w64 = cl[127:64];
			endcase
			select_cl64 = w64;
		end
	endfunction
	function non_mem_op;
		input reg [4:0] op;
		reg x;
		begin
			case (op)
				5'd24: x = 1'b1;
				5'd23: x = 1'b1;
				5'd25: x = 1'b1;
				5'd21: x = 1'b1;
				5'd22: x = 1'b1;
				default: x = 1'b0;
			endcase
			non_mem_op = x;
		end
	endfunction
	reg r_got_req;
	reg r_last_wr;
	reg n_last_wr;
	reg r_last_rd;
	reg n_last_rd;
	reg r_got_req2;
	reg r_last_wr2;
	reg n_last_wr2;
	reg r_last_rd2;
	reg n_last_rd2;
	reg rr_got_req;
	reg rr_last_wr;
	reg rr_is_retry;
	reg rr_did_reload;
	reg r_lock_cache;
	reg n_lock_cache;
	reg [31:0] rr_uuid;
	reg [3:0] r_n_inflight;
	reg [11:0] t_cache_idx;
	reg [11:0] r_cache_idx;
	reg [11:0] rr_cache_idx;
	reg [47:0] t_cache_tag;
	reg [47:0] r_cache_tag;
	wire [47:0] r_tag_out;
	reg [47:0] rr_cache_tag;
	wire r_valid_out;
	wire r_dirty_out;
	wire [127:0] r_array_out;
	reg [127:0] t_data;
	reg [127:0] t_data2;
	reg [11:0] t_cache_idx2;
	reg [11:0] r_cache_idx2;
	reg [47:0] t_cache_tag2;
	reg [47:0] r_cache_tag2;
	wire [47:0] r_tag_out2;
	wire r_valid_out2;
	wire r_dirty_out2;
	wire [127:0] r_array_out2;
	reg [11:0] t_miss_idx;
	reg [11:0] r_miss_idx;
	reg [63:0] t_miss_addr;
	reg [63:0] r_miss_addr;
	reg [11:0] t_array_wr_addr;
	reg [127:0] t_array_wr_data;
	reg [127:0] r_array_wr_data;
	reg t_array_wr_en;
	reg r_flush_req;
	reg n_flush_req;
	reg r_flush_cl_req;
	reg n_flush_cl_req;
	reg r_flush_complete;
	reg n_flush_complete;
	wire [31:0] t_array_out_b32 [3:0];
	reg [31:0] t_w32;
	reg [31:0] t_bswap_w32;
	reg [63:0] t_w64;
	reg [63:0] t_bswap_w64;
	reg [31:0] t_w32_2;
	reg [31:0] t_bswap_w32_2;
	reg [63:0] t_w64_2;
	reg [63:0] t_bswap_w64_2;
	reg t_got_rd_retry;
	reg t_port2_hit_cache;
	reg t_mark_invalid;
	reg t_wr_array;
	reg t_hit_cache;
	reg t_rsp_dst_valid;
	reg t_rsp_fp_dst_valid;
	reg [63:0] t_rsp_data;
	reg t_hit_cache2;
	reg t_rsp_dst_valid2;
	reg t_rsp_fp_dst_valid2;
	reg [63:0] t_rsp_data2;
	reg [127:0] t_array_data;
	reg [63:0] t_addr;
	reg t_got_req;
	reg t_got_req2;
	reg t_got_miss;
	reg t_push_miss;
	reg t_mh_block;
	reg t_cm_block;
	wire t_cm_block2;
	reg t_cm_block_stall;
	reg r_must_forward;
	reg r_must_forward2;
	reg n_inhibit_write;
	reg r_inhibit_write;
	reg t_got_non_mem;
	reg r_got_non_mem;
	reg t_incr_busy;
	reg t_force_clear_busy;
	reg n_stall_store;
	reg r_stall_store;
	reg n_is_retry;
	reg r_is_retry;
	reg r_q_priority;
	reg n_q_priority;
	reg n_core_mem_rsp_valid;
	reg r_core_mem_rsp_valid;
	reg [151:0] n_core_mem_rsp;
	reg [151:0] r_core_mem_rsp;
	reg [245:0] n_req;
	reg [245:0] r_req;
	wire [245:0] t_req;
	reg [245:0] tt_req;
	reg [245:0] n_req2;
	reg [245:0] r_req2;
	reg [245:0] r_mem_q [7:0];
	reg [3:0] r_mq_head_ptr;
	reg [3:0] n_mq_head_ptr;
	reg [3:0] r_mq_tail_ptr;
	reg [3:0] n_mq_tail_ptr;
	reg [3:0] t_mq_tail_ptr_plus_one;
	reg [7:0] r_mq_addr_valid;
	reg [11:0] r_mq_addr [7:0];
	wire [245:0] t_mem_tail;
	reg [245:0] t_mem_head;
	reg mem_q_full;
	reg mem_q_empty;
	reg mem_q_almost_full;
	reg [3:0] r_state;
	reg [3:0] n_state;
	reg t_pop_mq;
	reg n_reload_issue;
	reg r_reload_issue;
	reg n_did_reload;
	reg r_did_reload;
	reg r_mem_req_valid;
	reg n_mem_req_valid;
	reg [63:0] r_mem_req_addr;
	reg [63:0] n_mem_req_addr;
	reg [127:0] r_mem_req_store_data;
	reg [127:0] n_mem_req_store_data;
	reg [4:0] r_mem_req_opcode;
	reg [4:0] n_mem_req_opcode;
	reg [63:0] n_cache_accesses;
	reg [63:0] r_cache_accesses;
	reg [63:0] n_cache_hits;
	reg [63:0] r_cache_hits;
	reg [63:0] n_cache_hits_under_miss;
	reg [63:0] r_cache_hits_under_miss;
	reg [63:0] r_store_stalls;
	reg [63:0] n_store_stalls;
	wire t_utlb_hit;
	wire [56:0] t_utlb_hit_entry;
	reg n_utlb_miss_req;
	reg r_utlb_miss_req;
	reg [51:0] n_utlb_miss_paddr;
	reg [51:0] r_utlb_miss_paddr;
	reg [31:0] r_cycle;
	assign flush_complete = r_flush_complete;
	assign mem_req_addr = r_mem_req_addr;
	assign mem_req_store_data = r_mem_req_store_data;
	assign mem_req_opcode = r_mem_req_opcode;
	assign mem_req_valid = r_mem_req_valid;
	assign core_mem_rsp_valid = n_core_mem_rsp_valid;
	assign core_mem_rsp = n_core_mem_rsp;
	assign cache_accesses = r_cache_accesses;
	assign cache_hits = r_cache_hits;
	assign cache_hits_under_miss = r_cache_hits_under_miss;
	assign utlb_miss_req = r_utlb_miss_req;
	assign utlb_miss_paddr = r_utlb_miss_paddr;
	utlb utlb0(
		.clk(clk),
		.reset(reset),
		.flush(n_flush_complete),
		.req(t_got_req),
		.addr(t_addr),
		.tlb_rsp(tlb_rsp),
		.tlb_rsp_valid(tlb_rsp_valid),
		.hit(t_utlb_hit),
		.hit_entry(t_utlb_hit_entry)
	);
	always @(posedge clk) r_cycle <= (reset ? 'd0 : r_cycle + 'd1);
	always @(posedge clk)
		if (reset) begin
			r_mq_head_ptr <= 'd0;
			r_mq_tail_ptr <= 'd0;
		end
		else begin
			r_mq_head_ptr <= n_mq_head_ptr;
			r_mq_tail_ptr <= n_mq_tail_ptr;
		end
	localparam N_ROB_ENTRIES = 32;
	reg [1:0] r_graduated [31:0];
	always @(negedge clk)
		;
	reg t_reset_graduated;
	always @(posedge clk)
		if (reset) begin : sv2v_autoblock_1
			integer i;
			for (i = 0; i < N_ROB_ENTRIES; i = i + 1)
				r_graduated[i] <= 2'b00;
		end
		else begin
			if (retired_rob_ptr_valid && (r_graduated[retired_rob_ptr] == 2'b01))
				r_graduated[retired_rob_ptr] <= 2'b10;
			if (retired_rob_ptr_two_valid && (r_graduated[retired_rob_ptr_two] == 2'b01))
				r_graduated[retired_rob_ptr_two] <= 2'b10;
			if (t_incr_busy) begin
				if (r_graduated[r_req2[108-:5]] != 2'b00)
					$stop;
				r_graduated[r_req2[108-:5]] <= 2'b01;
			end
			if (t_reset_graduated)
				r_graduated[r_req[108-:5]] <= 2'b00;
			if (t_force_clear_busy)
				r_graduated[t_mem_head[108-:5]] <= 2'b00;
		end
	always @(negedge clk)
		if (drain_ds_complete && (retired_rob_ptr_valid || retired_rob_ptr_two_valid))
			$stop;
	always @(posedge clk)
		if (reset)
			r_n_inflight <= 'd0;
		else if ((core_mem_req_valid && core_mem_req_ack) && !core_mem_rsp_valid)
			r_n_inflight <= r_n_inflight + 'd1;
		else if (!(core_mem_req_valid && core_mem_req_ack) && core_mem_rsp_valid)
			r_n_inflight <= r_n_inflight - 'd1;
	always @(*) begin
		n_mq_head_ptr = r_mq_head_ptr;
		n_mq_tail_ptr = r_mq_tail_ptr;
		t_mq_tail_ptr_plus_one = r_mq_tail_ptr + 'd1;
		tt_req = r_req2;
		if (t_push_miss) begin
			n_mq_tail_ptr = r_mq_tail_ptr + 'd1;
			tt_req[181] = t_incr_busy;
		end
		if (t_pop_mq)
			n_mq_head_ptr = r_mq_head_ptr + 'd1;
		t_mem_head = r_mem_q[r_mq_head_ptr[2:0]];
		mem_q_empty = r_mq_head_ptr == r_mq_tail_ptr;
		mem_q_full = (r_mq_head_ptr != r_mq_tail_ptr) && (r_mq_head_ptr[2:0] == r_mq_tail_ptr[2:0]);
		mem_q_almost_full = (r_mq_head_ptr != t_mq_tail_ptr_plus_one) && (r_mq_head_ptr[2:0] == t_mq_tail_ptr_plus_one[2:0]);
	end
	always @(posedge clk)
		if (t_push_miss) begin
			r_mem_q[r_mq_tail_ptr[2:0]] <= tt_req;
			r_mq_addr[r_mq_tail_ptr[2:0]] <= tt_req[197:186];
		end
	always @(posedge clk)
		if (reset)
			r_mq_addr_valid <= 'd0;
		else begin
			if (t_push_miss)
				r_mq_addr_valid[r_mq_tail_ptr[2:0]] <= 1'b1;
			if (t_pop_mq)
				r_mq_addr_valid[r_mq_head_ptr[2:0]] <= 1'b0;
		end
	wire [7:0] w_hit_busy_addrs;
	reg [7:0] r_hit_busy_addrs;
	reg r_hit_busy_addr;
	wire [7:0] w_hit_busy_addrs2;
	reg [7:0] r_hit_busy_addrs2;
	reg r_hit_busy_addr2;
	genvar i;
	generate
		for (i = 0; i < N_MQ_ENTRIES; i = i + 1) begin : genblk1
			assign w_hit_busy_addrs[i] = (t_pop_mq && (r_mq_head_ptr[2:0] == i) ? 1'b0 : (r_mq_addr_valid[i] ? r_mq_addr[i] == t_cache_idx : 1'b0));
			assign w_hit_busy_addrs2[i] = (r_mq_addr_valid[i] ? r_mq_addr[i] == t_cache_idx2 : 1'b0);
		end
	endgenerate
	always @(posedge clk) begin
		r_hit_busy_addr <= (reset ? 1'b0 : |w_hit_busy_addrs);
		r_hit_busy_addrs <= (t_got_req ? w_hit_busy_addrs : {N_MQ_ENTRIES {1'b1}});
		r_hit_busy_addr2 <= (reset ? 1'b0 : |w_hit_busy_addrs2);
		r_hit_busy_addrs2 <= (t_got_req2 ? w_hit_busy_addrs2 : {N_MQ_ENTRIES {1'b1}});
	end
	always @(posedge clk) r_array_wr_data <= t_array_wr_data;
	always @(posedge clk)
		if (reset) begin
			r_reload_issue <= 1'b0;
			r_did_reload <= 1'b0;
			r_stall_store <= 1'b0;
			r_is_retry <= 1'b0;
			r_flush_complete <= 1'b0;
			r_flush_req <= 1'b0;
			r_flush_cl_req <= 1'b0;
			r_cache_idx <= 'd0;
			r_cache_tag <= 'd0;
			r_cache_idx2 <= 'd0;
			r_cache_tag2 <= 'd0;
			rr_cache_idx <= 'd0;
			rr_cache_tag <= 'd0;
			r_miss_addr <= 'd0;
			r_miss_idx <= 'd0;
			r_got_req <= 1'b0;
			r_got_req2 <= 1'b0;
			rr_got_req <= 1'b0;
			r_lock_cache <= 1'b0;
			rr_is_retry <= 1'b0;
			rr_did_reload <= 1'b0;
			rr_uuid <= 'd0;
			rr_last_wr <= 1'b0;
			r_got_non_mem <= 1'b0;
			r_last_wr <= 1'b0;
			r_last_rd <= 1'b0;
			r_last_wr2 <= 1'b0;
			r_last_rd2 <= 1'b0;
			r_state <= 4'd0;
			r_mem_req_valid <= 1'b0;
			r_mem_req_addr <= 'd0;
			r_mem_req_store_data <= 'd0;
			r_mem_req_opcode <= 'd0;
			r_core_mem_rsp_valid <= 1'b0;
			r_cache_hits <= 'd0;
			r_cache_accesses <= 'd0;
			r_cache_hits_under_miss <= 'd0;
			r_store_stalls <= 'd0;
			r_utlb_miss_req <= 1'b0;
			r_utlb_miss_paddr <= 'd0;
			r_inhibit_write <= 1'b0;
			memq_empty <= 1'b1;
			r_q_priority <= 1'b0;
			r_must_forward <= 1'b0;
			r_must_forward2 <= 1'b0;
		end
		else begin
			r_reload_issue <= n_reload_issue;
			r_did_reload <= n_did_reload;
			r_stall_store <= n_stall_store;
			r_is_retry <= n_is_retry;
			r_flush_complete <= n_flush_complete;
			r_flush_req <= n_flush_req;
			r_flush_cl_req <= n_flush_cl_req;
			r_cache_idx <= t_cache_idx;
			r_cache_tag <= t_cache_tag;
			r_cache_idx2 <= t_cache_idx2;
			r_cache_tag2 <= t_cache_tag2;
			rr_cache_idx <= r_cache_idx;
			rr_cache_tag <= r_cache_tag;
			r_miss_idx <= t_miss_idx;
			r_miss_addr <= t_miss_addr;
			r_got_req <= t_got_req;
			r_got_req2 <= t_got_req2;
			rr_got_req <= r_got_req;
			r_lock_cache <= n_lock_cache;
			rr_is_retry <= r_is_retry;
			rr_did_reload <= r_did_reload;
			rr_uuid <= r_req[31-:32];
			rr_last_wr <= r_last_wr;
			r_got_non_mem <= t_got_non_mem;
			r_last_wr <= n_last_wr;
			r_last_rd <= n_last_rd;
			r_last_wr2 <= n_last_wr2;
			r_last_rd2 <= n_last_rd2;
			r_state <= n_state;
			r_mem_req_valid <= n_mem_req_valid;
			r_mem_req_addr <= n_mem_req_addr;
			r_mem_req_store_data <= n_mem_req_store_data;
			r_mem_req_opcode <= n_mem_req_opcode;
			r_core_mem_rsp_valid <= n_core_mem_rsp_valid;
			r_cache_hits <= n_cache_hits;
			r_cache_accesses <= n_cache_accesses;
			r_cache_hits_under_miss <= n_cache_hits_under_miss;
			r_store_stalls <= n_store_stalls;
			r_utlb_miss_req <= n_utlb_miss_req;
			r_utlb_miss_paddr <= n_utlb_miss_paddr;
			r_inhibit_write <= n_inhibit_write;
			memq_empty <= (((((mem_q_empty && drain_ds_complete) && !core_mem_req_valid) && !t_got_req) && !t_got_req2) && !t_push_miss) && (r_n_inflight == 'd0);
			r_q_priority <= n_q_priority;
			r_must_forward <= t_mh_block & t_pop_mq;
			r_must_forward2 <= t_cm_block & core_mem_req_ack;
		end
	always @(posedge clk) begin
		r_req <= n_req;
		r_req2 <= n_req2;
		r_core_mem_rsp <= n_core_mem_rsp;
	end
	always @(*) begin
		t_array_wr_addr = (mem_rsp_valid ? r_mem_req_addr[15:IDX_START] : r_cache_idx);
		t_array_wr_data = (mem_rsp_valid ? mem_rsp_load_data : t_array_data);
		t_array_wr_en = mem_rsp_valid || t_wr_array;
	end
	ram2r1w #(
		.WIDTH(N_TAG_BITS),
		.LG_DEPTH(12)
	) dc_tag(
		.clk(clk),
		.rd_addr0(t_cache_idx),
		.rd_addr1(t_cache_idx2),
		.wr_addr(r_mem_req_addr[15:IDX_START]),
		.wr_data(r_mem_req_addr[63:IDX_STOP]),
		.wr_en(mem_rsp_valid),
		.rd_data0(r_tag_out),
		.rd_data1(r_tag_out2)
	);
	ram2r1w #(
		.WIDTH(L1D_CL_LEN_BITS),
		.LG_DEPTH(12)
	) dc_data(
		.clk(clk),
		.rd_addr0(t_cache_idx),
		.rd_addr1(t_cache_idx2),
		.wr_addr(t_array_wr_addr),
		.wr_data(t_array_wr_data),
		.wr_en(t_array_wr_en),
		.rd_data0(r_array_out),
		.rd_data1(r_array_out2)
	);
	reg t_dirty_value;
	reg t_write_dirty_en;
	reg [11:0] t_dirty_wr_addr;
	always @(*) begin
		t_dirty_value = 1'b0;
		t_write_dirty_en = 1'b0;
		t_dirty_wr_addr = r_cache_idx;
		if (mem_rsp_valid) begin
			t_dirty_wr_addr = r_mem_req_addr[15:IDX_START];
			t_write_dirty_en = 1'b1;
		end
		else if (t_wr_array) begin
			t_dirty_value = 1'b1;
			t_write_dirty_en = 1'b1;
		end
	end
	ram2r1w #(
		.WIDTH(1),
		.LG_DEPTH(12)
	) dc_dirty(
		.clk(clk),
		.rd_addr0(t_cache_idx),
		.rd_addr1(t_cache_idx2),
		.wr_addr(t_dirty_wr_addr),
		.wr_data(t_dirty_value),
		.wr_en(t_write_dirty_en),
		.rd_data0(r_dirty_out),
		.rd_data1(r_dirty_out2)
	);
	reg t_valid_value;
	reg t_write_valid_en;
	reg [11:0] t_valid_wr_addr;
	always @(*) begin
		t_valid_value = 1'b0;
		t_write_valid_en = 1'b0;
		t_valid_wr_addr = r_cache_idx;
		if (t_mark_invalid)
			t_write_valid_en = 1'b1;
		else if (mem_rsp_valid) begin
			t_valid_wr_addr = r_mem_req_addr[15:IDX_START];
			t_valid_value = !r_inhibit_write;
			t_write_valid_en = 1'b1;
		end
	end
	ram2r1w #(
		.WIDTH(1),
		.LG_DEPTH(12)
	) dc_valid(
		.clk(clk),
		.rd_addr0(t_cache_idx),
		.rd_addr1(t_cache_idx2),
		.wr_addr(t_valid_wr_addr),
		.wr_data(t_valid_value),
		.wr_en(t_write_valid_en),
		.rd_data0(r_valid_out),
		.rd_data1(r_valid_out2)
	);
	function [31:0] bswap32;
		input reg [31:0] in;
		bswap32 = {in[7:0], in[15:8], in[23:16], in[31:24]};
	endfunction
	generate
		for (i = 0; i < WORDS_PER_CL; i = i + 1) begin : genblk2
			assign t_array_out_b32[i] = bswap32(t_data[((i + 1) * 32) - 1:i * 32]);
		end
	endgenerate
	function [15:0] bswap16;
		input reg [15:0] in;
		bswap16 = {in[7:0], in[15:8]};
	endfunction
	function [63:0] bswap64;
		input reg [63:0] in;
		bswap64 = {in[7:0], in[15:8], in[23:16], in[31:24], in[39:32], in[47:40], in[55:48], in[63:56]};
	endfunction
	function sext16;
		input reg [15:0] in;
		sext16 = in[7];
	endfunction
	always @(*) begin
		t_data2 = (r_got_req2 && r_must_forward2 ? r_array_wr_data : r_array_out2);
		t_w32_2 = select_cl32(t_data2, r_req2[185:184]);
		t_w64_2 = select_cl64(t_data2, r_req2[185]);
		t_bswap_w32_2 = bswap32(t_w32_2);
		t_bswap_w64_2 = bswap64(t_w64_2);
		t_hit_cache2 = ((r_valid_out2 && (r_tag_out2 == r_cache_tag2)) && r_got_req2) && (r_state == 4'd0);
		t_rsp_dst_valid2 = 1'b0;
		t_rsp_fp_dst_valid2 = 1'b0;
		t_rsp_data2 = 'd0;
		case (r_req2[177-:5])
			5'd0: begin
				case (r_req2[183:182])
					2'd0: t_rsp_data2 = {{56 {t_w32_2[7]}}, t_w32_2[7:0]};
					2'd1: t_rsp_data2 = {{56 {t_w32_2[15]}}, t_w32_2[15:8]};
					2'd2: t_rsp_data2 = {{56 {t_w32_2[23]}}, t_w32_2[23:16]};
					2'd3: t_rsp_data2 = {{56 {t_w32_2[31]}}, t_w32_2[31:24]};
				endcase
				t_rsp_dst_valid2 = r_req2[97] & t_hit_cache2;
			end
			5'd1: begin
				case (r_req2[183:182])
					2'd0: t_rsp_data2 = {56'd0, t_w32_2[7:0]};
					2'd1: t_rsp_data2 = {56'd0, t_w32_2[15:8]};
					2'd2: t_rsp_data2 = {56'd0, t_w32_2[23:16]};
					2'd3: t_rsp_data2 = {56'd0, t_w32_2[31:24]};
				endcase
				t_rsp_dst_valid2 = r_req2[97] & t_hit_cache2;
			end
			5'd2: begin
				case (r_req2[183])
					1'b0: t_rsp_data2 = {{48 {sext16(t_w32_2[15:0])}}, bswap16(t_w32_2[15:0])};
					1'b1: t_rsp_data2 = {{48 {sext16(t_w32_2[31:16])}}, bswap16(t_w32_2[31:16])};
				endcase
				t_rsp_dst_valid2 = r_req2[97] & t_hit_cache2;
			end
			5'd3: begin
				t_rsp_data2 = {48'd0, bswap16((r_req2[183] ? t_w32_2[31:16] : t_w32_2[15:0]))};
				t_rsp_dst_valid2 = r_req2[97] & t_hit_cache2;
			end
			5'd4: begin
				t_rsp_data2 = {{32 {t_bswap_w32_2[31]}}, t_bswap_w32_2};
				t_rsp_dst_valid2 = r_req2[97] & t_hit_cache2;
			end
			5'd19: begin
				if (r_req2[178])
					t_rsp_data2 = {t_bswap_w32_2, r_req2[140:109]};
				else
					t_rsp_data2 = {r_req2[172:141], t_bswap_w32_2};
				t_rsp_fp_dst_valid2 = r_req2[96] & t_hit_cache2;
			end
			5'd15: begin
				t_rsp_data2 = t_bswap_w64_2;
				t_rsp_fp_dst_valid2 = r_req2[96] & t_hit_cache2;
			end
			5'd10: begin
				case (r_req2[183:182])
					2'd0: t_rsp_data2 = {{32 {r_req2[140]}}, r_req2[140:117], t_bswap_w32_2[31:24]};
					2'd1: t_rsp_data2 = {{32 {r_req2[140]}}, r_req2[140:125], t_bswap_w32_2[31:16]};
					2'd2: t_rsp_data2 = {{32 {r_req2[140]}}, r_req2[140:133], t_bswap_w32_2[31:8]};
					2'd3: t_rsp_data2 = {{32 {t_bswap_w32_2[31]}}, t_bswap_w32_2};
				endcase
				t_rsp_dst_valid2 = r_req2[97] & t_hit_cache2;
			end
			5'd11: begin
				case (r_req2[183:182])
					2'd0: t_rsp_data2 = {{32 {t_bswap_w32_2[31]}}, t_bswap_w32_2};
					2'd1: t_rsp_data2 = {{32 {t_bswap_w32_2[23]}}, t_bswap_w32_2[23:0], r_req2[116:109]};
					2'd2: t_rsp_data2 = {{32 {t_bswap_w32_2[15]}}, t_bswap_w32_2[15:0], r_req2[124:109]};
					2'd3: t_rsp_data2 = {{32 {t_bswap_w32_2[7]}}, t_bswap_w32_2[7:0], r_req2[132:109]};
				endcase
				t_rsp_dst_valid2 = r_req2[97] & t_hit_cache2;
			end
			default:
				;
		endcase
	end
	always @(*) begin
		t_data = (r_got_req && r_must_forward ? r_array_wr_data : r_array_out);
		t_w32 = select_cl32(t_data, r_req[185:184]);
		t_w64 = select_cl64(t_data, r_req[185]);
		t_bswap_w32 = bswap32(t_w32);
		t_bswap_w64 = bswap64(t_w64);
		t_hit_cache = ((r_valid_out && (r_tag_out == r_cache_tag)) && r_got_req) && ((r_state == 4'd0) || (r_state == 4'd1));
		t_array_data = 'd0;
		t_wr_array = 1'b0;
		t_rsp_dst_valid = 1'b0;
		t_rsp_fp_dst_valid = 1'b0;
		t_rsp_data = 'd0;
		case (r_req[177-:5])
			5'd0: begin
				case (r_req[183:182])
					2'd0: t_rsp_data = {{56 {t_w32[7]}}, t_w32[7:0]};
					2'd1: t_rsp_data = {{56 {t_w32[15]}}, t_w32[15:8]};
					2'd2: t_rsp_data = {{56 {t_w32[23]}}, t_w32[23:16]};
					2'd3: t_rsp_data = {{56 {t_w32[31]}}, t_w32[31:24]};
				endcase
				t_rsp_dst_valid = r_req[97] & t_hit_cache;
			end
			5'd1: begin
				case (r_req[183:182])
					2'd0: t_rsp_data = {56'd0, t_w32[7:0]};
					2'd1: t_rsp_data = {56'd0, t_w32[15:8]};
					2'd2: t_rsp_data = {56'd0, t_w32[23:16]};
					2'd3: t_rsp_data = {56'd0, t_w32[31:24]};
				endcase
				t_rsp_dst_valid = r_req[97] & t_hit_cache;
			end
			5'd2: begin
				case (r_req[183])
					1'b0: t_rsp_data = {{48 {sext16(t_w32[15:0])}}, bswap16(t_w32[15:0])};
					1'b1: t_rsp_data = {{48 {sext16(t_w32[31:16])}}, bswap16(t_w32[31:16])};
				endcase
				t_rsp_dst_valid = r_req[97] & t_hit_cache;
			end
			5'd3: begin
				t_rsp_data = {48'd0, bswap16((r_req[183] ? t_w32[31:16] : t_w32[15:0]))};
				t_rsp_dst_valid = r_req[97] & t_hit_cache;
			end
			5'd4: begin
				t_rsp_data = {{32 {t_bswap_w32[31]}}, t_bswap_w32};
				t_rsp_dst_valid = r_req[97] & t_hit_cache;
			end
			5'd19: begin
				if (r_req[178])
					t_rsp_data = {t_bswap_w32, r_req[140:109]};
				else
					t_rsp_data = {r_req[172:141], t_bswap_w32};
				t_rsp_fp_dst_valid = r_req[96] & t_hit_cache;
			end
			5'd15: begin
				t_rsp_data = t_bswap_w64;
				t_rsp_fp_dst_valid = r_req[96] & t_hit_cache;
			end
			5'd10: begin
				case (r_req[183:182])
					2'd0: t_rsp_data = {{32 {r_req[140]}}, r_req[140:117], t_bswap_w32[31:24]};
					2'd1: t_rsp_data = {{32 {r_req[140]}}, r_req[140:125], t_bswap_w32[31:16]};
					2'd2: t_rsp_data = {{32 {r_req[140]}}, r_req[140:133], t_bswap_w32[31:8]};
					2'd3: t_rsp_data = {{32 {t_bswap_w32[31]}}, t_bswap_w32};
				endcase
				t_rsp_dst_valid = r_req[97] & t_hit_cache;
			end
			5'd11: begin
				case (r_req[183:182])
					2'd0: t_rsp_data = {{32 {t_bswap_w32[31]}}, t_bswap_w32};
					2'd1: t_rsp_data = {{32 {t_bswap_w32[23]}}, t_bswap_w32[23:0], r_req[116:109]};
					2'd2: t_rsp_data = {{32 {t_bswap_w32[15]}}, t_bswap_w32[15:0], r_req[124:109]};
					2'd3: t_rsp_data = {{32 {t_bswap_w32[7]}}, t_bswap_w32[7:0], r_req[132:109]};
				endcase
				t_rsp_dst_valid = r_req[97] & t_hit_cache;
			end
			5'd5: begin
				case (r_req[183:182])
					2'd0: t_array_data = merge_cl32(t_data, {t_w32[31:8], r_req[116:109]}, r_req[185:184]);
					2'd1: t_array_data = merge_cl32(t_data, {t_w32[31:16], r_req[116:109], t_w32[7:0]}, r_req[185:184]);
					2'd2: t_array_data = merge_cl32(t_data, {t_w32[31:24], r_req[116:109], t_w32[15:0]}, r_req[185:184]);
					2'd3: t_array_data = merge_cl32(t_data, {r_req[116:109], t_w32[23:0]}, r_req[185:184]);
				endcase
				t_wr_array = t_hit_cache && (r_is_retry || r_did_reload);
			end
			5'd6: begin
				case (r_req[183])
					1'b0: t_array_data = merge_cl32(t_data, {t_w32[31:16], bswap16(r_req[124:109])}, r_req[185:184]);
					1'b1: t_array_data = merge_cl32(t_data, {bswap16(r_req[124:109]), t_w32[15:0]}, r_req[185:184]);
				endcase
				t_wr_array = t_hit_cache && (r_is_retry || r_did_reload);
			end
			5'd7: begin
				t_array_data = merge_cl32(t_data, bswap32(r_req[140:109]), r_req[185:184]);
				t_wr_array = t_hit_cache && (r_is_retry || r_did_reload);
			end
			5'd20: begin
				t_array_data = merge_cl32(t_data, bswap32((r_req[178] ? r_req[172:141] : r_req[140:109])), r_req[185:184]);
				t_wr_array = t_hit_cache && (r_is_retry || r_did_reload);
			end
			5'd14: begin
				t_array_data = merge_cl64(t_data, bswap64(r_req[172:109]), r_req[185]);
				t_wr_array = t_hit_cache && (r_is_retry || r_did_reload);
			end
			5'd13: begin
				t_array_data = merge_cl32(t_data, bswap32(r_req[140:109]), r_req[185:184]);
				t_rsp_data = 64'd1;
				t_rsp_dst_valid = r_req[97] & t_hit_cache;
				t_wr_array = t_hit_cache && (r_is_retry || r_did_reload);
			end
			5'd8: begin
				case (r_req[183:182])
					2'd0: t_array_data = merge_cl32(t_data, bswap32({r_req[116:109], t_bswap_w32[23:0]}), r_req[185:184]);
					2'd1: t_array_data = merge_cl32(t_data, bswap32({r_req[124:109], t_bswap_w32[15:0]}), r_req[185:184]);
					2'd2: t_array_data = merge_cl32(t_data, bswap32({r_req[132:109], t_bswap_w32[7:0]}), r_req[185:184]);
					2'd3: t_array_data = merge_cl32(t_data, bswap32(r_req[140:109]), r_req[185:184]);
				endcase
				t_wr_array = t_hit_cache && (r_is_retry || r_did_reload);
			end
			5'd9: begin
				case (r_req[183:182])
					2'd0: t_array_data = merge_cl32(t_data, t_bswap_w32, r_req[185:184]);
					2'd1: t_array_data = merge_cl32(t_data, bswap32({t_bswap_w32[31:24], r_req[140:117]}), r_req[185:184]);
					2'd2: t_array_data = merge_cl32(t_data, bswap32({t_bswap_w32[31:16], r_req[140:125]}), r_req[185:184]);
					2'd3: t_array_data = merge_cl32(t_data, bswap32({t_bswap_w32[31:8], r_req[140:133]}), r_req[185:184]);
				endcase
				t_wr_array = t_hit_cache && (r_is_retry || r_did_reload);
			end
			default:
				;
		endcase
	end
	reg t_incr_stuck;
	reg t_clr_stuck;
	reg [11:0] r_stuck_cnt;
	always @(posedge clk) begin
		if (reset || t_clr_stuck)
			r_stuck_cnt <= 'd0;
		else if (t_incr_stuck)
			r_stuck_cnt <= r_stuck_cnt + 'd1;
		if (r_stuck_cnt == 'd1024) begin
			$display("op with uuid %d, rob ptr %d stuck, pc = %x", t_mem_head[31-:32], t_mem_head[108-:5], t_mem_head[95-:64]);
			$stop;
		end
	end
	reg [31:0] r_fwd_cnt;
	always @(posedge clk) r_fwd_cnt <= (reset ? 'd0 : (r_got_req && r_must_forward ? r_fwd_cnt + 'd1 : r_fwd_cnt));
	always @(*) begin
		t_got_rd_retry = 1'b0;
		t_port2_hit_cache = r_valid_out2 && (r_tag_out2 == r_cache_tag2);
		n_state = r_state;
		t_miss_idx = r_miss_idx;
		t_miss_addr = r_miss_addr;
		t_cache_idx = 'd0;
		t_cache_tag = 'd0;
		t_cache_idx2 = 'd0;
		t_cache_tag2 = 'd0;
		t_got_req = 1'b0;
		t_got_req2 = 1'b0;
		t_got_non_mem = 1'b0;
		n_last_wr = 1'b0;
		n_last_rd = 1'b0;
		n_last_wr2 = 1'b0;
		n_last_rd2 = 1'b0;
		t_got_miss = 1'b0;
		t_push_miss = 1'b0;
		n_utlb_miss_req = 1'b0;
		n_utlb_miss_paddr = r_utlb_miss_paddr;
		n_req = r_req;
		n_req2 = r_req2;
		core_mem_req_ack = 1'b0;
		n_mem_req_valid = 1'b0;
		n_mem_req_addr = r_mem_req_addr;
		n_mem_req_store_data = r_mem_req_store_data;
		n_mem_req_opcode = r_mem_req_opcode;
		t_pop_mq = 1'b0;
		n_core_mem_rsp_valid = 1'b0;
		n_core_mem_rsp[151-:5] = r_req[177-:5];
		n_core_mem_rsp[146-:64] = r_req[245-:64];
		n_core_mem_rsp[82-:5] = r_req[108-:5];
		n_core_mem_rsp[77-:6] = r_req[103-:6];
		n_core_mem_rsp[71] = 1'b0;
		n_core_mem_rsp[70] = 1'b0;
		n_core_mem_rsp[68] = 1'b0;
		n_core_mem_rsp[67] = 1'b0;
		n_core_mem_rsp[66] = 1'b0;
		n_core_mem_rsp[69] = 1'b0;
		n_core_mem_rsp[64] = 1'b0;
		n_core_mem_rsp[65] = !non_mem_op(r_req[177-:5]);
		n_core_mem_rsp[63-:64] = r_req[95-:64];
		n_cache_accesses = r_cache_accesses;
		n_cache_hits = r_cache_hits;
		n_cache_hits_under_miss = r_cache_hits_under_miss;
		n_store_stalls = r_store_stalls;
		n_flush_req = r_flush_req | flush_req;
		n_flush_cl_req = r_flush_cl_req | flush_cl_req;
		n_flush_complete = 1'b0;
		t_addr = 'd0;
		n_inhibit_write = r_inhibit_write;
		t_mark_invalid = 1'b0;
		n_is_retry = 1'b0;
		t_reset_graduated = 1'b0;
		t_force_clear_busy = 1'b0;
		t_incr_busy = 1'b0;
		n_stall_store = 1'b0;
		n_q_priority = !r_q_priority;
		t_incr_stuck = 1'b0;
		t_clr_stuck = 1'b0;
		n_reload_issue = r_reload_issue;
		n_did_reload = 1'b0;
		n_lock_cache = r_lock_cache;
		t_mh_block = (r_got_req && r_last_wr) && (r_cache_idx == t_mem_head[197:186]);
		t_cm_block = ((r_got_req && r_last_wr) && (r_cache_idx == core_mem_req[197:186])) && (r_cache_tag == core_mem_req[245:198]);
		t_cm_block_stall = t_cm_block && !(r_did_reload || r_is_retry);
		case (r_state)
			4'd0: begin
				if (r_got_req2) begin
					n_core_mem_rsp[151-:5] = r_req2[177-:5];
					n_core_mem_rsp[146-:64] = r_req2[245-:64];
					n_core_mem_rsp[82-:5] = r_req2[108-:5];
					n_core_mem_rsp[77-:6] = r_req2[103-:6];
					n_core_mem_rsp[65] = !non_mem_op(r_req2[177-:5]);
					n_core_mem_rsp[63-:64] = r_req2[95-:64];
					if (drain_ds_complete) begin
						n_core_mem_rsp[71] = r_req2[97];
						n_core_mem_rsp[70] = r_req2[96];
						n_core_mem_rsp_valid = 1'b1;
					end
					else if (r_req2[177-:5] == 5'd21) begin
						n_core_mem_rsp[146-:64] = (r_req2[178] ? {r_req2[213:182], r_req2[140:109]} : {r_req2[172:141], r_req2[213:182]});
						n_core_mem_rsp[70] = r_req2[96];
						n_core_mem_rsp_valid = 1'b1;
					end
					else if (r_req2[177-:5] == 5'd22) begin
						n_core_mem_rsp[146-:64] = (r_req2[178] ? {32'd0, r_req2[172:141]} : {32'd0, r_req2[140:109]});
						n_core_mem_rsp[71] = r_req2[97];
						n_core_mem_rsp_valid = 1'b1;
					end
					else if (r_req2[180]) begin
						t_push_miss = 1'b1;
						t_incr_busy = 1'b1;
						n_stall_store = 1'b1;
						n_core_mem_rsp[71] = 1'b0;
						n_core_mem_rsp[70] = 1'b0;
						if (r_req2[181]) begin
							$display("hit store buf, was retry = %b", r_is_retry);
							$stop;
						end
						if (t_port2_hit_cache) begin
							n_cache_hits = r_cache_hits + 'd1;
							n_core_mem_rsp[64] = 1'b0;
						end
						else
							n_core_mem_rsp[64] = 1'b1;
						n_core_mem_rsp_valid = 1'b1;
					end
					else if (t_port2_hit_cache && !r_hit_busy_addr2) begin
						n_core_mem_rsp[146-:64] = t_rsp_data2;
						n_core_mem_rsp[71] = t_rsp_dst_valid2;
						n_core_mem_rsp[70] = t_rsp_fp_dst_valid2;
						n_core_mem_rsp[64] = 1'b0;
						n_cache_hits = r_cache_hits + 'd1;
						n_core_mem_rsp_valid = 1'b1;
					end
					else begin
						t_push_miss = 1'b1;
						if (t_port2_hit_cache)
							n_cache_hits = r_cache_hits + 'd1;
					end
				end
				if (r_got_req)
					if (r_valid_out && (r_tag_out == r_cache_tag)) begin
						if (!(r_is_retry || r_did_reload))
							$stop;
						if (r_req[180])
							t_reset_graduated = 1'b1;
						else begin
							n_core_mem_rsp[146-:64] = t_rsp_data;
							n_core_mem_rsp[71] = t_rsp_dst_valid;
							n_core_mem_rsp[70] = t_rsp_fp_dst_valid;
							n_core_mem_rsp[64] = r_is_retry;
							n_core_mem_rsp_valid = 1'b1;
						end
					end
					else if ((r_valid_out && r_dirty_out) && (r_tag_out != r_cache_tag)) begin
						n_reload_issue = 1'b1;
						t_got_miss = 1'b1;
						n_inhibit_write = 1'b1;
						if ((r_hit_busy_addr && r_is_retry) || !r_hit_busy_addr) begin
							n_reload_issue = 1'b1;
							n_mem_req_addr = {r_tag_out, r_cache_idx, {4 {1'b0}}};
							n_mem_req_opcode = 5'd7;
							n_mem_req_store_data = t_data;
							n_inhibit_write = 1'b1;
							t_miss_idx = r_cache_idx;
							t_miss_addr = r_req[245-:64];
							n_lock_cache = 1'b1;
							if ((rr_cache_idx == r_cache_idx) && rr_last_wr) begin
								t_cache_idx = r_cache_idx;
								n_state = 4'd2;
								n_mem_req_valid = 1'b0;
							end
							else begin
								n_state = 4'd1;
								n_mem_req_valid = 1'b1;
							end
						end
					end
					else begin
						t_got_miss = 1'b1;
						n_inhibit_write = 1'b0;
						if (((r_hit_busy_addr && r_is_retry) || !r_hit_busy_addr) || r_lock_cache) begin
							n_reload_issue = 1'b1;
							t_miss_idx = r_cache_idx;
							t_miss_addr = r_req[245-:64];
							t_cache_idx = r_cache_idx;
							if ((rr_cache_idx == r_cache_idx) && rr_last_wr) begin
								n_mem_req_addr = {r_tag_out, r_cache_idx, {4 {1'b0}}};
								n_lock_cache = 1'b1;
								n_mem_req_opcode = 5'd7;
								n_state = 4'd2;
								n_mem_req_valid = 1'b0;
							end
							else begin
								n_lock_cache = 1'b0;
								n_mem_req_addr = {r_req[245:186], {4 {1'b0}}};
								n_mem_req_opcode = 5'd4;
								n_state = 4'd1;
								n_mem_req_valid = 1'b1;
							end
						end
					end
				if ((!mem_q_empty && !t_got_miss) && !r_lock_cache)
					if (!t_mh_block)
						if (t_mem_head[180]) begin
							if (r_graduated[t_mem_head[108-:5]] == 2'b10) begin
								t_pop_mq = 1'b1;
								n_req = t_mem_head;
								t_cache_idx = t_mem_head[197:186];
								t_cache_tag = t_mem_head[245:198];
								t_addr = t_mem_head[245-:64];
								t_got_req = 1'b1;
								n_is_retry = 1'b1;
								n_last_wr = 1'b1;
								t_clr_stuck = 1'b1;
							end
							else if (drain_ds_complete && dead_rob_mask[t_mem_head[108-:5]]) begin
								t_pop_mq = 1'b1;
								t_force_clear_busy = 1'b1;
								t_clr_stuck = 1'b1;
								if (t_push_miss && memq_empty) begin
									$display("memq_empty = %b", memq_empty);
									$stop;
								end
							end
							else begin
								t_incr_stuck = 1'b1;
								if (mem_q_empty)
									$stop;
								if (r_graduated[t_mem_head[108-:5]] == 2'b00)
									$stop;
							end
						end
						else begin
							t_pop_mq = 1'b1;
							n_req = t_mem_head;
							t_cache_idx = t_mem_head[197:186];
							t_cache_tag = t_mem_head[245:198];
							t_addr = t_mem_head[245-:64];
							t_got_req = 1'b1;
							n_is_retry = 1'b1;
							n_last_rd = 1'b1;
							t_got_rd_retry = 1'b1;
						end
				if ((((((core_mem_req_valid && !t_got_miss) && !(mem_q_almost_full || mem_q_full)) && !t_got_rd_retry) && !((r_last_wr2 && (r_cache_idx2 == core_mem_req[197:186])) && !core_mem_req[180])) && !t_cm_block_stall) && (r_graduated[core_mem_req[108-:5]] == 2'b00)) begin
					t_cache_idx2 = core_mem_req[197:186];
					t_cache_tag2 = core_mem_req[245:198];
					n_req2 = core_mem_req;
					core_mem_req_ack = 1'b1;
					t_got_req2 = 1'b1;
					n_last_wr2 = core_mem_req[180];
					n_last_rd2 = !core_mem_req[180];
					n_cache_accesses = (non_mem_op(core_mem_req[177-:5]) ? r_cache_accesses : r_cache_accesses + 'd1);
				end
				else if ((r_flush_req && mem_q_empty) && !(r_got_req && r_last_wr)) begin
					n_state = 4'd3;
					if (!mem_q_empty)
						$stop;
					if (r_got_req && r_last_wr)
						$stop;
					t_cache_idx = 'd0;
					n_flush_req = 1'b0;
				end
				else if ((r_flush_cl_req && mem_q_empty) && !(r_got_req && r_last_wr)) begin
					if (!mem_q_empty)
						$stop;
					if (r_got_req && r_last_wr)
						$stop;
					t_cache_idx = flush_cl_addr[15:IDX_START];
					n_flush_cl_req = 1'b0;
					n_state = 4'd5;
				end
			end
			4'd2: begin
				n_mem_req_valid = 1'b1;
				n_state = 4'd1;
				n_mem_req_store_data = t_data;
			end
			4'd1:
				if (mem_rsp_valid) begin
					n_state = (r_reload_issue ? 4'd8 : 4'd0);
					n_inhibit_write = 1'b0;
					n_reload_issue = 1'b0;
				end
			4'd8: begin
				t_cache_idx = r_req[197:186];
				t_cache_tag = r_req[245:198];
				n_last_wr = n_req[180];
				t_got_req = 1'b1;
				t_addr = r_req[245-:64];
				n_did_reload = 1'b1;
				n_state = 4'd0;
			end
			4'd5:
				if (r_dirty_out) begin
					n_mem_req_addr = {r_tag_out, r_cache_idx, {4 {1'b0}}};
					n_mem_req_opcode = 5'd7;
					n_mem_req_store_data = t_data;
					n_state = 4'd6;
					n_inhibit_write = 1'b1;
					n_mem_req_valid = 1'b1;
				end
				else begin
					n_state = 4'd0;
					t_mark_invalid = 1'b1;
					n_flush_complete = 1'b1;
				end
			4'd6:
				if (mem_rsp_valid) begin
					n_state = 4'd0;
					n_inhibit_write = 1'b0;
					n_flush_complete = 1'b1;
				end
			4'd3: begin
				t_cache_idx = r_cache_idx + 'd1;
				if (r_cache_idx == 4095) begin
					n_state = 4'd0;
					n_flush_complete = 1'b1;
				end
				else if (!r_dirty_out) begin
					t_mark_invalid = 1'b1;
					t_cache_idx = r_cache_idx + 'd1;
				end
				else begin
					n_mem_req_addr = {r_tag_out, r_cache_idx, {4 {1'b0}}};
					n_mem_req_opcode = 5'd7;
					n_mem_req_store_data = t_data;
					n_state = 4'd4;
					n_inhibit_write = 1'b1;
					n_mem_req_valid = 1'b1;
				end
			end
			4'd4: begin
				t_cache_idx = r_cache_idx;
				if (mem_rsp_valid) begin
					n_state = 4'd3;
					n_inhibit_write = 1'b0;
				end
			end
			4'd7:
				if (tlb_rsp_valid)
					n_state = 4'd0;
			default:
				;
		endcase
	end
	always @(negedge clk) begin
		if (t_push_miss && mem_q_full) begin
			$display("attempting to push to a full memory queue");
			$stop;
		end
		if (t_pop_mq && mem_q_empty) begin
			$display("attempting to pop an empty memory queue");
			$stop;
		end
	end
endmodule

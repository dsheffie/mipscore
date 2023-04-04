`include "machine.vh"
`include "rob.vh"
`include "uop.vh"

module core_l1d_l1i(clk, 
		    reset,
		    extern_irq,
		    in_flush_mode,
		    resume,
		    resume_pc,
		    ready_for_resume,
		    
		    mem_req_valid, 
		    mem_req_addr, 
		    mem_req_store_data,
		    mem_req_opcode,
		    mem_rsp_valid,
		    mem_rsp_load_data,
		    
		    retire_reg_ptr,
		    retire_reg_data,
		    retire_reg_valid,
		    retire_reg_two_ptr,
		    retire_reg_two_data,
		    retire_reg_two_valid,
		    retire_valid,
		    retire_two_valid,
		    retire_pc,
		    retire_two_pc,
		    monitor_req_reason,
		    monitor_req_valid,
		    monitor_rsp_valid,
		    monitor_rsp_data,
		    branch_pc,
		    branch_pc_valid,		    
		    branch_fault,
		    l1i_cache_accesses,
		    l1i_cache_hits,
		    l1d_cache_accesses,
		    l1d_cache_hits,
		    got_break,
		    got_ud,
		    inflight);

   localparam L1D_CL_LEN = 1 << `LG_L1D_CL_LEN;
   localparam L1D_CL_LEN_BITS = 1 << (`LG_L1D_CL_LEN + 3);
   localparam LG_L1_MQ_ENTRIES = 2;
        
   input logic clk;
   input logic reset;
   input logic extern_irq;
   input logic resume;
   input logic [(`M_WIDTH-1):0] resume_pc;
   output logic 		in_flush_mode;
   output logic 		ready_for_resume;
   

   logic [(`M_WIDTH-1):0] 	restart_pc;
   logic [(`M_WIDTH-1):0] 	restart_src_pc;
   logic 			restart_src_is_indirect;
   logic 			restart_valid;
   logic 			restart_ack;
   logic [`LG_PHT_SZ-1:0] 	branch_pht_idx;
   logic 			took_branch;

   logic 			t_retire_delay_slot;
   logic [(`M_WIDTH-1):0] 	t_branch_pc;
   logic 			t_branch_pc_valid;
   logic 			t_branch_fault;

   output logic [(`M_WIDTH-1):0] branch_pc;
   output logic 		 branch_pc_valid;
   output logic 		 branch_fault;
   assign branch_pc = t_branch_pc;
   assign branch_pc_valid = t_branch_pc_valid;   
   assign branch_fault = t_branch_fault;

   output logic [63:0] 			l1i_cache_accesses;
   output logic [63:0] 			l1i_cache_hits;
   output logic [63:0] 			l1d_cache_accesses;
   output logic [63:0] 			l1d_cache_hits;

   
   /* mem port */
   output logic 		 mem_req_valid;
   output logic [`M_WIDTH-1:0] 	 mem_req_addr;
   output logic [L1D_CL_LEN_BITS-1:0] mem_req_store_data;
   output logic [3:0] 			  mem_req_opcode;
   
   input logic  			  mem_rsp_valid;
   input logic [L1D_CL_LEN_BITS-1:0] 	  mem_rsp_load_data;

   output logic [4:0] 			  retire_reg_ptr;
   output logic [31:0] 			  retire_reg_data;
   output logic 			  retire_reg_valid;

   output logic [4:0] 			  retire_reg_two_ptr;
   output logic [31:0] 			  retire_reg_two_data;
   output logic 			  retire_reg_two_valid;
   
   output logic 			  retire_valid;
   output logic 			  retire_two_valid;
   output logic [(`M_WIDTH-1):0] 	  retire_pc;
   output logic [(`M_WIDTH-1):0] 	  retire_two_pc;

   logic 				  retired_call;
   logic 				  retired_ret;

   logic 				  retired_rob_ptr_valid;
   logic 				  retired_rob_ptr_two_valid;
   logic [`LG_ROB_ENTRIES-1:0] 		  retired_rob_ptr;
   logic [`LG_ROB_ENTRIES-1:0] 		  retired_rob_ptr_two;

   
   output logic [15:0] 			  monitor_req_reason;
   output logic 			  monitor_req_valid;
   input logic 				  monitor_rsp_valid;
   input logic [(`M_WIDTH-1):0] 	  monitor_rsp_data;
   output logic 			  got_break;
   output logic 			  got_ud;
   output logic [`LG_ROB_ENTRIES:0] 	  inflight;
   
   logic [63:0] 			  t_l1d_cache_accesses;
   logic [63:0] 			  t_l1d_cache_hits;
   logic [63:0] 			  t_l1i_cache_accesses;
   logic [63:0] 			  t_l1i_cache_hits;


   logic 				  head_of_rob_ptr_valid;   
   logic [`LG_ROB_ENTRIES-1:0] 		  head_of_rob_ptr;

   logic 				  flush_req_l1i, flush_req_l1d;
   logic 				  flush_cl_req;
   logic [`M_WIDTH-1:0] 		  flush_cl_addr;
   logic 				  l1d_flush_complete;
   logic 				  l1i_flush_complete;

   mem_req_t core_mem_req;
   mem_rsp_t core_mem_rsp;
   mem_data_t core_store_data;
   
   logic 				  core_mem_req_valid;
   logic 				  core_mem_req_ack;
   logic 				  core_mem_rsp_valid;
   logic 				  core_store_data_valid;
   logic 				  core_store_data_ack;
   
   
   typedef enum logic [1:0] {
			     FLUSH_IDLE = 'd0,
			     WAIT_FOR_L1D_L1I = 'd1,
			     GOT_L1D = 'd2,
			     GOT_L1I = 'd3
   } flush_state_t;
   flush_state_t n_flush_state, r_flush_state;
   logic 	r_flush, n_flush;
   logic 	memq_empty;   
   assign in_flush_mode = r_flush;


 
   always_ff@(posedge clk)
     begin
	if(reset)
	  begin
	     r_flush_state <= FLUSH_IDLE;
	     r_flush <= 1'b0;
	  end
	else
	  begin
	     r_flush_state <= n_flush_state;
	     r_flush <= n_flush;
	  end
     end // always_ff@ (posedge clk)
   always_comb
     begin
	n_flush_state = r_flush_state;
	n_flush = r_flush;
	case(r_flush_state)
	  FLUSH_IDLE:
	    begin
	       if(flush_req_l1i && flush_req_l1d)
		 begin
		    n_flush_state = WAIT_FOR_L1D_L1I;
		    n_flush = 1'b1;
		 end
	       else if(flush_req_l1i && !flush_req_l1d)
		 begin
		    n_flush_state = GOT_L1D;
		    n_flush = 1'b1;
		 end
	       else if(!flush_req_l1i && flush_req_l1d)
		 begin
		    n_flush_state = GOT_L1I;
		    n_flush = 1'b1;
		 end
	    end
	  WAIT_FOR_L1D_L1I:
	    begin
	       if(l1d_flush_complete && !l1i_flush_complete)
		 begin
		    n_flush_state = GOT_L1D;		    
		 end
	       else if(!l1d_flush_complete && l1i_flush_complete)
		 begin
		    n_flush_state = GOT_L1I;
		 end
	       else if(l1d_flush_complete && l1i_flush_complete)
		 begin
		    n_flush_state = FLUSH_IDLE;
		    n_flush = 1'b0;
		    if(!mq_empty)
		      begin
			 $stop();
		      end
		 end
	    end
	  GOT_L1D:
	    begin
	       if(l1i_flush_complete)
		 begin
		    n_flush_state = FLUSH_IDLE;
		    n_flush = 1'b0;
		    if(!mq_empty)
		      begin
			 $stop();
		      end
		 end
	    end
	  GOT_L1I:
	    begin
	       if(l1d_flush_complete)
		 begin
		    n_flush_state = FLUSH_IDLE;
		    n_flush = 1'b0;
		    if(!mq_empty)
		      begin
			 $stop();
		      end
		 end
	    end
	endcase // case (r_flush_state)
     end // always_comb
   
   typedef enum logic [1:0] {
      IDLE = 'd0,
      GNT_L1D = 'd1,
      GNT_L1I = 'd2			    
   } state_t;

   assign l1d_cache_accesses = t_l1d_cache_accesses;
   assign l1d_cache_hits = t_l1d_cache_hits;
   assign l1i_cache_accesses = t_l1i_cache_accesses;
   assign l1i_cache_hits = t_l1i_cache_hits;
   
   logic 				  l1d_mem_req_ack;
   logic 				  l1d_mem_req_valid;
   logic [(`M_WIDTH-1):0] 		  l1d_mem_req_addr;
   logic [L1D_CL_LEN_BITS-1:0] 		  l1d_mem_req_store_data;
   logic [3:0] 				  l1d_mem_req_opcode;

   logic 				  l1i_mem_req_ack;   
   logic 				  l1i_mem_req_valid;
   logic [(`M_WIDTH-1):0] 		  l1i_mem_req_addr;
   logic [L1D_CL_LEN_BITS-1:0] 		  l1i_mem_req_store_data;
   logic [3:0] 				  l1i_mem_req_opcode;
   logic 				  l1d_mem_rsp_valid, l1i_mem_rsp_valid;
   
   state_t r_state, n_state;
   logic 				  n_req, r_req;

   logic 				  insn_valid,insn_valid2;
   logic 				  insn_ack, insn_ack2;
   insn_fetch_t insn, insn2;

   logic 				  mq_empty, mq_full;
   logic 				  t_pop_mq;
   
   l1_miss_req_t t_mq_head;

   logic [`M_WIDTH-1:0] 		  r_mem_req_addr, n_mem_req_addr;
   logic [L1D_CL_LEN_BITS-1:0] 		  r_mem_req_store_data, n_mem_req_store_data;;
   logic [3:0] 				  r_mem_req_opcode, n_mem_req_opcode;
   logic 				  n_is_flush, r_is_flush;
   logic 				  n_is_store, r_is_store;
   
   
   
   // always_ff@(negedge clk)
   //   begin
   // 	if(mem_rsp_valid)
   // 	  begin
   // 	     $display("return data %x,%x,%x,%x", 
   // 		      mem_rsp_load_data[127:96],
   // 		      mem_rsp_load_data[95:64],
   // 		      mem_rsp_load_data[63:32],
   // 		      mem_rsp_load_data[31:0]);
   // 	  end
   //   end
   
   always_comb
     begin
	t_pop_mq = 1'b0;
	n_state = r_state;
	n_req = r_req;
	
	mem_req_valid = n_req;	
	mem_req_addr = r_mem_req_addr;
	mem_req_opcode = r_mem_req_opcode;
	mem_req_store_data = r_mem_req_store_data;

	n_mem_req_addr = r_mem_req_addr;
	n_mem_req_opcode = r_mem_req_opcode;
	n_mem_req_store_data = r_mem_req_store_data;
	
	l1d_mem_rsp_valid = 1'b0;
	l1i_mem_rsp_valid = 1'b0;
	n_is_flush = r_is_flush;
	n_is_store = r_is_store;
	
	case(r_state)
	  IDLE:
	    begin
	       if(!mq_empty)
		 begin
		    n_mem_req_addr = {t_mq_head.addr, 4'd0};
		    n_mem_req_store_data = t_mq_head.data;
		    n_mem_req_opcode = t_mq_head.is_store ? MEM_SW : MEM_LW;
		    n_is_flush = t_mq_head.is_flush;
		    n_is_store = t_mq_head.is_store;
		    t_pop_mq = 1'b1;
		    n_req = 1'b1;
		    n_state = t_mq_head.iside ? GNT_L1I : GNT_L1D;
		 end
	    end
	  GNT_L1D:
	    begin
	       if(mem_rsp_valid)
		 begin
		    n_req = 1'b0;
		    n_state = IDLE;
		    l1d_mem_rsp_valid = !r_is_store;//1'b1;
		 end
	    end // case: GNT_L1D
         GNT_L1I:
           begin
              if(mem_rsp_valid)
                begin
                   n_req = 1'b0;                   
                   n_state = IDLE;
                   l1i_mem_rsp_valid = 1'b1;
                end
           end
	  default:
	    begin
	    end
	  endcase
     end // always_comb

   always_ff@(posedge clk)
     begin
	if(reset)
	  begin
	     r_state <= IDLE;
	     r_req <= 1'b0;
	     r_mem_req_addr <= 'd0;
	     r_mem_req_store_data <= 'd0;
	     r_mem_req_opcode <= 'd0;
	     r_is_flush <= 1'b0;
	     r_is_store <= 1'b0;
	  end
	else
	  begin
	     r_state <= n_state;
	     r_req <= n_req;
	     r_mem_req_addr <= n_mem_req_addr;
	     r_mem_req_store_data <= n_mem_req_store_data;
	     r_mem_req_opcode <= n_mem_req_opcode;	  
	     r_is_flush <= n_is_flush;
	     r_is_store <= n_is_store;
	  end
     end // always_ff@ (posedge clk)
   

   logic 			  drain_ds_complete;
   logic [(1<<`LG_ROB_ENTRIES)-1:0] dead_rob_mask;

   logic [LG_L1_MQ_ENTRIES:0] 	    r_l1_mq_rd_ptr, n_l1_mq_rd_ptr;
   logic [LG_L1_MQ_ENTRIES:0] 	    r_l1_mq_wr_ptr, n_l1_mq_wr_ptr;

   /* verilator lint_off UNOPTFLAT */     
   logic 			    t_mq_ack_l1d, t_mq_ack_l1i;

   l1_miss_req_t t_l1d_miss, t_l1i_miss;
   /* verilator lint_off UNOPTFLAT */  
   wire 			    w_l1d_miss_req, w_l1i_miss_req;
   
   

   
   
   l1d dcache (
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
	       .flush_req(flush_req_l1d),
	       .flush_cl_req(flush_cl_req),
	       .flush_cl_addr(flush_cl_addr),
	       .flush_complete(l1d_flush_complete),
	       .core_mem_req_valid(core_mem_req_valid),
	       .core_mem_req(core_mem_req),
	       .core_mem_req_ack(core_mem_req_ack),

	       .core_store_data_valid(core_store_data_valid),
	       .core_store_data(core_store_data),
	       .core_store_data_ack(core_store_data_ack),
	       
	       .core_mem_rsp_valid(core_mem_rsp_valid),
	       .core_mem_rsp(core_mem_rsp),

	       .mem_req_ack(l1d_mem_req_ack),
	       .mem_req_valid(l1d_mem_req_valid),
	       .mem_req_addr(l1d_mem_req_addr),
	       .mem_req_store_data(l1d_mem_req_store_data),
	       .mem_req_opcode(l1d_mem_req_opcode),
	       
	       .mem_rsp_valid(l1d_mem_rsp_valid),
	       .mem_rsp_load_data(mem_rsp_load_data),

	       .l1_miss(t_l1d_miss),
	       .l1_miss_req(w_l1d_miss_req),
	       .l1_miss_ack(t_mq_ack_l1d),
	       .l1_mq_empty(mq_empty),
	       
	       .cache_accesses(t_l1d_cache_accesses),
	       .cache_hits(t_l1d_cache_hits)
	       );

   l1i icache(
	      .clk(clk),
	      .reset(reset),
	      .flush_req(flush_req_l1i),
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
	      .branch_pc(t_branch_pc),
	      .took_branch(took_branch),
	      .branch_fault(t_branch_fault),
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
	      .mem_req_opcode(l1i_mem_req_opcode),
	      .mem_rsp_valid(l1i_mem_rsp_valid),
	      .mem_rsp_load_data(mem_rsp_load_data),
	      
	      .l1_miss(t_l1i_miss),
	      .l1_miss_req(w_l1i_miss_req),
	      .l1_miss_ack(t_mq_ack_l1i),
	      
	      .cache_accesses(t_l1i_cache_accesses),
	      .cache_hits(t_l1i_cache_hits)	      
	      );

   l1_miss_req_t r_l1_mq[(1<<LG_L1_MQ_ENTRIES) - 1:0];

   
   
   always_comb
     begin
	t_mq_ack_l1d = 1'b0;
	t_mq_ack_l1i = 1'b0;
	
	n_l1_mq_rd_ptr = r_l1_mq_rd_ptr;
	n_l1_mq_wr_ptr = r_l1_mq_wr_ptr;
	mq_empty = r_l1_mq_rd_ptr==r_l1_mq_wr_ptr;
	
	mq_full = (r_l1_mq_rd_ptr!=r_l1_mq_wr_ptr) &&
		  (r_l1_mq_rd_ptr[LG_L1_MQ_ENTRIES-1:0] == 
		   r_l1_mq_wr_ptr[LG_L1_MQ_ENTRIES-1:0]);

	t_mq_head = r_l1_mq[r_l1_mq_rd_ptr[LG_L1_MQ_ENTRIES-1:0]];
	
	if(!mq_full)
	  begin
	     if(w_l1i_miss_req)
	       begin
		  t_mq_ack_l1i = 1'b1;
	       end
	     else if(w_l1d_miss_req)
	       begin
		  t_mq_ack_l1d = 1'b1;
	       end

	     if(w_l1i_miss_req||w_l1d_miss_req)
	       begin
		  n_l1_mq_wr_ptr = r_l1_mq_wr_ptr + 'd1;
	       end
	  end // if (!mq_full)

	if(t_pop_mq)
	  begin
	     n_l1_mq_rd_ptr = r_l1_mq_rd_ptr + 'd1;
	  end
     end // always_comb

   always_ff@(posedge clk)
     begin
	if(t_mq_ack_l1d)
	  begin
	     r_l1_mq[r_l1_mq_wr_ptr[LG_L1_MQ_ENTRIES-1:0]] <= t_l1d_miss;
	  end
	else if(t_mq_ack_l1i)
	  begin
	     r_l1_mq[r_l1_mq_wr_ptr[LG_L1_MQ_ENTRIES-1:0]] <= t_l1i_miss;
	  end
     end

   always_ff@(posedge clk)
     begin
	r_l1_mq_rd_ptr <= reset ? 'd0 : n_l1_mq_rd_ptr;
	r_l1_mq_wr_ptr <= reset ? 'd0 : n_l1_mq_wr_ptr;
     end

   logic [31:0] r_cycle;
   always_ff@(posedge clk)
     begin
	r_cycle <= reset ? 'd0 : (r_cycle + 32'd1);
     end

   // always_ff@(negedge clk)
   //   begin
   // 	if(!mq_empty)
   // 	  begin
   // 	     $display("cycle %d : head of mq addr %x, is store %b, iside %b, flush %b",  
   // 		      r_cycle,
   // 		      {t_mq_head.addr,4'd0}, 
   // 		      t_mq_head.is_store,
   // 		      t_mq_head.iside,
   // 		      t_mq_head.is_flush);
   // 	  end
   //   end
   	      
   core cpu (
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
	     .flush_req_l1d(flush_req_l1d),
	     .flush_req_l1i(flush_req_l1i),	     
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
	     
	     .core_store_data_valid(core_store_data_valid),
	     .core_store_data(core_store_data),
	     .core_store_data_ack(core_store_data_ack),
	     
	     .core_mem_rsp_valid(core_mem_rsp_valid),
	     .core_mem_rsp(core_mem_rsp),
	     
	     .retire_reg_ptr(retire_reg_ptr),
	     .retire_reg_data(retire_reg_data),
	     .retire_reg_valid(retire_reg_valid),
	     .retire_reg_two_ptr(retire_reg_two_ptr),
	     .retire_reg_two_data(retire_reg_two_data),
	     .retire_reg_two_valid(retire_reg_two_valid),
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
	     .monitor_rsp_data(monitor_rsp_data),
	     .got_break(got_break),
	     .got_ud(got_ud),
	     .inflight(inflight)
	     );
   

endmodule // core_l1d_l1i




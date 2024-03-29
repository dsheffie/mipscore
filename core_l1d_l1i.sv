`include "machine.vh"
`include "rob.vh"
`include "uop.vh"

`define BRANCH_DEBUG 1
`define CACHE_STATS 1
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
		    mem_req_tag,
		    mem_req_opcode,
		    mem_rsp_valid,
		    mem_rsp_load_data,
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
		    monitor_rsp_data,
`ifdef BRANCH_DEBUG
		    branch_pc,
		    branch_pc_valid,		    
		    branch_fault,
`endif
`ifdef CACHE_STATS
		    l1i_cache_accesses,
		    l1i_cache_hits,
		    l1d_cache_accesses,
		    l1d_cache_hits,
		    l1d_cache_hits_under_miss,
`endif
		    got_break,
		    got_syscall,
		    got_ud,
		    inflight,
		    iside_tlb_miss,
		    dside_tlb_miss);

   localparam L1D_CL_LEN = 1 << `LG_L1D_CL_LEN;
   localparam L1D_CL_LEN_BITS = 1 << (`LG_L1D_CL_LEN + 3);
   
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

`ifdef BRANCH_DEBUG
   output logic [(`M_WIDTH-1):0] branch_pc;
   output logic 		 branch_pc_valid;
   output logic 		 branch_fault;
   assign branch_pc = t_branch_pc;
   assign branch_pc_valid = t_branch_pc_valid;   
   assign branch_fault = t_branch_fault;
`endif

`ifdef CACHE_STATS
   output logic [63:0] 			l1i_cache_accesses;
   output logic [63:0] 			l1i_cache_hits;
   output logic [63:0] 			l1d_cache_accesses;
   output logic [63:0] 			l1d_cache_hits;
   output logic [63:0] 			l1d_cache_hits_under_miss;
`endif
   
   /* mem port */
   output logic 		 mem_req_valid;
   output logic [`M_WIDTH-1:0] 	 mem_req_addr;
   output logic [L1D_CL_LEN_BITS-1:0] mem_req_store_data;
   output logic [`LG_MEM_TAG_ENTRIES-1:0] mem_req_tag;
   output logic [4:0] 			  mem_req_opcode;
   
   input logic  			  mem_rsp_valid;
   input logic [L1D_CL_LEN_BITS-1:0] 	  mem_rsp_load_data;


   output logic [4:0] 			  retire_reg_ptr;
   output logic [(`M_WIDTH-1):0] 	  retire_reg_data;
   output logic 			  retire_reg_valid;
   output logic 			  retire_reg_fp_valid;

   output logic [4:0] 			  retire_reg_two_ptr;
   output logic [(`M_WIDTH-1):0] 	  retire_reg_two_data;
   output logic 			  retire_reg_two_valid;
   output logic 			  retire_reg_fp_two_valid;
   
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
   output logic 			  got_syscall;
   output logic 			  got_ud;
   output logic [`LG_ROB_ENTRIES:0] 	  inflight;
   output logic 			  iside_tlb_miss;
   output logic 			  dside_tlb_miss;
   
   logic [63:0] 			  t_l1d_cache_accesses;
   logic [63:0] 			  t_l1d_cache_hits;
   logic [63:0] 			  t_l1d_cache_hits_under_miss;
   logic [63:0] 			  t_l1i_cache_accesses;
   logic [63:0] 			  t_l1i_cache_hits;


   logic 				  head_of_rob_ptr_valid;   
   logic [`LG_ROB_ENTRIES-1:0] 		  head_of_rob_ptr;

   logic 				  flush_req;
   logic 				  flush_cl_req;
   logic [`M_WIDTH-1:0] 		  flush_cl_addr;
   logic 				  l1d_flush_complete;
   logic 				  l1i_flush_complete;

   mem_req_t core_mem_req;
   mem_rsp_t core_mem_rsp;
      
   logic 				  core_mem_req_valid;
   logic 				  core_mem_req_ack;
   logic 				  core_mem_rsp_valid;

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


// `ifdef VERILATOR
//    initial 
//      begin
// 	$dumpfile("l1d.vcd");
// 	$dumpvars();
//      end
// `endif

 
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
	       if(flush_req)
		 begin
		    n_flush_state = WAIT_FOR_L1D_L1I;
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
		 end
	    end
	  GOT_L1D:
	    begin
	       if(l1i_flush_complete)
		 begin
		    n_flush_state = FLUSH_IDLE;
		    n_flush = 1'b0;
		 end
	    end
	  GOT_L1I:
	    begin
	       if(l1d_flush_complete)
		 begin
		    n_flush_state = FLUSH_IDLE;
		    n_flush = 1'b0;
		 end
	    end
	endcase // case (r_flush_state)
     end // always_comb
   
   typedef enum logic [1:0] {
      IDLE = 'd0,
      GNT_L1D = 'd1,
      GNT_L1I = 'd2			    
   } state_t;

`ifdef CACHE_STATS
   assign l1d_cache_accesses = t_l1d_cache_accesses;
   assign l1d_cache_hits = t_l1d_cache_hits;
   assign l1d_cache_hits_under_miss = t_l1d_cache_hits_under_miss;
   assign l1i_cache_accesses = t_l1i_cache_accesses;
   assign l1i_cache_hits = t_l1i_cache_hits;
`endif
   
   // always_ff@(posedge clk)
   //   begin
   // 	if(got_break || got_syscall || got_ud)
   // 	  begin
   // 	     $display("l1d accesses = %d, l1d misses = %d",
   // 		      l1d_cache_accesses, l1d_cache_hits);
   // 	  end
   //   end
   
   logic 				  l1d_mem_req_ack;
   logic 				  l1d_mem_req_valid;
   logic [(`M_WIDTH-1):0] 		  l1d_mem_req_addr;
   logic [L1D_CL_LEN_BITS-1:0] 		  l1d_mem_req_store_data;
   logic [`LG_MEM_TAG_ENTRIES-1:0] 	  l1d_mem_req_tag;
   logic [4:0] 				  l1d_mem_req_opcode;

   logic 				  l1i_mem_req_ack;   
   logic 				  l1i_mem_req_valid;
   logic [(`M_WIDTH-1):0] 		  l1i_mem_req_addr;
   logic [L1D_CL_LEN_BITS-1:0] 		  l1i_mem_req_store_data;
   logic [`LG_MEM_TAG_ENTRIES-1:0] 	  l1i_mem_req_tag;
   logic [4:0] 				  l1i_mem_req_opcode;
   logic 				  l1d_mem_rsp_valid, l1i_mem_rsp_valid;
   
   state_t r_state, n_state;
   logic 				  r_l1d_req, n_l1d_req;
   logic 				  r_l1i_req, n_l1i_req;
   logic 				  r_last_gnt, n_last_gnt;
   logic 				  n_req, r_req;

   logic 				  insn_valid,insn_valid2;
   logic 				  insn_ack, insn_ack2;
   insn_fetch_t insn, insn2;


   
   always_comb
     begin
	n_state = r_state;
	n_last_gnt = r_last_gnt;
	n_l1i_req = r_l1i_req || l1i_mem_req_valid;
	n_l1d_req = r_l1d_req || l1d_mem_req_valid;
	n_req = r_req;
	
	mem_req_valid = n_req;	
	mem_req_addr = (r_state == GNT_L1I) ? l1i_mem_req_addr: l1d_mem_req_addr;
	mem_req_store_data = l1d_mem_req_store_data;
	mem_req_tag = (r_state == GNT_L1I) ? l1i_mem_req_tag : l1d_mem_req_tag;
	mem_req_opcode = (r_state == GNT_L1I) ? l1i_mem_req_opcode : l1d_mem_req_opcode;
	l1d_mem_rsp_valid = 1'b0;
	l1i_mem_rsp_valid = 1'b0;
	
	case(r_state)
	  IDLE:
	    begin
	       if(n_l1d_req && !n_l1i_req)
		 begin
		    //$display("generating memory request for the l1d");
		    n_state = GNT_L1D;
		    n_req = 1'b1;
		 end
	       else if(!n_l1d_req && n_l1i_req)
		 begin
		    //$display("generating memory request for the l1i, address %x / %x", mem_req_addr, l1i_mem_req_addr);
		    n_state = GNT_L1I;
		    n_req = 1'b1;
		 end
	       else if(n_l1d_req && n_l1i_req)
		 begin
		    n_state = r_last_gnt ? GNT_L1D : GNT_L1I;
		    n_req = 1'b1;
		 end
	    end
	  GNT_L1D:
	    begin
	       n_last_gnt = 1'b0;
	       n_l1d_req = 1'b0;
	       if(mem_rsp_valid)
		 begin
		    n_req = 1'b0;
		    n_state = IDLE;
		    l1d_mem_rsp_valid = 1'b1;
		 end
	    end
	  GNT_L1I:
	    begin
	       n_last_gnt = 1'b1;
	       n_l1i_req = 1'b0;
	       //$display("waiting for cache line for i-cache returns, req addr %x", mem_req_addr);	       
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
	     r_last_gnt <= 1'b0;
	     r_l1d_req <= 1'b0;
	     r_l1i_req <= 1'b0;
	     r_req <= 1'b0;
	  end
	else
	  begin
	     r_state <= n_state;
	     r_last_gnt <= n_last_gnt;
	     r_l1d_req <= n_l1d_req;
	     r_l1i_req <= n_l1i_req;
	     r_req <= n_req;	     
	  end
     end

   logic 			 t_l1d_tlb_rsp_valid;
   logic 			 t_l1i_tlb_rsp_valid;   
   logic 			 t_l1d_utlb_miss_req;
   logic 			 t_l1i_utlb_miss_req;   
   logic [`M_WIDTH-`LG_PG_SZ-1:0] t_l1d_utlb_miss_paddr;
   logic [`M_WIDTH-`LG_PG_SZ-1:0] t_l1i_utlb_miss_paddr;
   logic 			  drain_ds_complete;
   logic [(1<<`LG_ROB_ENTRIES)-1:0] dead_rob_mask;
   utlb_entry_t t_tlb_rsp;
   
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
	      .utlb_miss_req(t_l1i_utlb_miss_req),
	      .utlb_miss_paddr(t_l1i_utlb_miss_paddr),
	      .tlb_rsp_valid(t_l1i_tlb_rsp_valid),
	      .tlb_rsp(t_tlb_rsp),	      
	      .cache_accesses(t_l1i_cache_accesses),
	      .cache_hits(t_l1i_cache_hits)	      
	      );
   	      

   tlb tlb0 (
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
	     .monitor_rsp_data(monitor_rsp_data),
	     .got_break(got_break),
	     .got_syscall(got_syscall),
	     .got_ud(got_ud),
	     .inflight(inflight)
	     );
   

endmodule // core_l1d_l1i




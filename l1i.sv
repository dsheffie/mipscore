`include "machine.vh"
`include "rob.vh"
`include "uop.vh"


module l1i(clk,
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
	   
	   //output to the memory system
	   mem_req_ack,
	   mem_req_valid, 
	   mem_req_addr, 
	   mem_req_tag,
	   mem_req_opcode,
	   //reply from memory system
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

   input logic clk;
   input logic reset;
   input logic 	      flush_req;
   output logic       flush_complete;
   //restart signals
   input logic [(`M_WIDTH-1):0] restart_pc;
   input logic [(`M_WIDTH-1):0] restart_src_pc;
   input logic 			restart_src_is_indirect;
   input logic 			restart_valid;
   output logic 		restart_ack;
   //return stack signals
   input logic 			retire_valid;
   input logic 			retired_call;
   input logic 			retired_ret;

   input logic [4:0] 		retire_reg_ptr;
   input logic [(`M_WIDTH-1):0] retire_reg_data;
   input logic 			retire_reg_valid;

   input logic 			branch_pc_valid;
   input logic 			took_branch;
   input logic [`LG_PHT_SZ-1:0] branch_pht_idx;

   output logic 		utlb_miss_req;
   output logic [`M_WIDTH-`LG_PG_SZ-1:0] utlb_miss_paddr;
   input logic 				 tlb_rsp_valid;
   input 				 utlb_entry_t tlb_rsp;
   
   output insn_fetch_t insn;
   output logic insn_valid;
   input logic 	insn_ack;

   input logic 	mem_req_ack;
   output logic mem_req_valid;
   
   localparam L1I_NUM_SETS = 1 << `LG_L1D_NUM_SETS;
   localparam L1I_CL_LEN = 1 << `LG_L1D_CL_LEN;
   localparam L1I_CL_LEN_BITS = 1 << (`LG_L1D_CL_LEN + 3);
   localparam LG_WORDS_PER_CL = `LG_L1D_CL_LEN - 2;
   localparam WORDS_PER_CL = 1<<LG_WORDS_PER_CL;
   localparam N_TAG_BITS = `M_WIDTH - `LG_L1D_NUM_SETS - `LG_L1D_CL_LEN;
   localparam IDX_START = `LG_L1D_CL_LEN;
   localparam IDX_STOP  = `LG_L1D_CL_LEN + `LG_L1D_NUM_SETS;
   localparam WORD_START = 2;
   localparam WORD_STOP = WORD_START+LG_WORDS_PER_CL;
   localparam N_FQ_ENTRIES = 1 << `LG_FQ_ENTRIES;
   localparam RETURN_STACK_ENTRIES = 1 << `LG_RET_STACK_ENTRIES;
   localparam PHT_ENTRIES = 1 << `LG_PHT_SZ;
   localparam BTB_ENTRIES = 1 << `LG_BTB_SZ;

   output logic [(`M_WIDTH-1):0] mem_req_addr;
   output logic [`LG_MEM_TAG_ENTRIES-1:0] mem_req_tag;
   output logic [4:0] 			  mem_req_opcode;
   input logic 				  mem_rsp_valid;
   input logic [L1I_CL_LEN_BITS-1:0] 	  mem_rsp_load_data;
   input logic [`LG_MEM_TAG_ENTRIES-1:0]  mem_rsp_tag;
   input logic [4:0] 			  mem_rsp_opcode;
   output logic [63:0] 			  cache_accesses;
   output logic [63:0] 			  cache_hits;
   
   typedef enum 			  logic [3:0] {
						       NOT_CFLOW = 'd0,
						       IS_COND_BR = 'd1,
						       IS_L_COND_BR = 'd2,
						       IS_J = 'd3,
						       IS_JR = 'd4,
						       IS_JAL = 'd5,
						       IS_JALR = 'd6,
						       IS_JR_R31 = 'd7,
						       IS_BR = 'd8,
						       IS_BR_AND_LINK = 'd9
						       } jump_t;
   
   logic [N_TAG_BITS-1:0] 		  t_cache_tag, r_cache_tag, r_tag_out;

   logic 				  r_pht_update;
   logic [1:0] 				  r_pht_out, r_pht_update_out;
   logic [1:0] 				  t_pht_val;
   logic 				  t_do_pht_wr;
   
   logic [`LG_PHT_SZ-1:0] 		  n_pht_idx,r_pht_idx;
   logic [`LG_PHT_SZ-1:0] 		  r_pht_update_idx;
   logic 				  r_take_br;
   
   logic [(`M_WIDTH-1):0] 		  r_btb[BTB_ENTRIES-1:0];
   
   
   logic [($bits(jump_t)*WORDS_PER_CL)-1:0] r_jump_out;
   
   logic [`LG_L1D_NUM_SETS-1:0] 	    t_cache_idx, r_cache_idx;   
   logic [L1I_CL_LEN_BITS-1:0] 		  r_array_out;   
   logic 				  r_mem_req_valid, n_mem_req_valid;
   logic [(`M_WIDTH-1):0] 		  r_mem_req_addr, n_mem_req_addr;
   

   insn_fetch_t r_fq[N_FQ_ENTRIES-1:0];
   insn_fetch_t n_fq[N_FQ_ENTRIES-1:0];
   
   logic [`LG_FQ_ENTRIES:0] r_fq_head_ptr, n_fq_head_ptr;
   logic [`LG_FQ_ENTRIES:0] r_fq_tail_ptr, n_fq_tail_ptr;
   
   insn_fetch_t t_fq_head;
   logic 		    fq_full, fq_empty;

   
   logic [(`M_WIDTH-1):0]   r_spec_return_stack [RETURN_STACK_ENTRIES-1:0];
   logic [(`M_WIDTH-1):0]   r_arch_return_stack [RETURN_STACK_ENTRIES-1:0];
   logic [`LG_RET_STACK_ENTRIES-1:0] n_arch_rs_tos, r_arch_rs_tos;
   logic [`LG_RET_STACK_ENTRIES-1:0] n_spec_rs_tos, r_spec_rs_tos;   
   
   logic [`GBL_HIST_LEN-1:0] 	     n_arch_gbl_hist, r_arch_gbl_hist;
   logic [`GBL_HIST_LEN-1:0] 	     n_spec_gbl_hist, r_spec_gbl_hist;
   logic [`GBL_HIST_LEN-1:0] 	     t_xor_pc_hist;
   
   logic 			     n_utlb_miss_req, r_utlb_miss_req;
   logic [`M_WIDTH-`LG_PG_SZ-1:0]    n_utlb_miss_paddr, r_utlb_miss_paddr;
   
   logic [63:0] 			 n_cache_accesses, r_cache_accesses;
   logic [63:0] 			 n_cache_hits, r_cache_hits;
   
function logic [31:0] select_cl32(logic [L1I_CL_LEN_BITS-1:0] cl, logic[LG_WORDS_PER_CL-1:0] pos);
   logic [31:0] 			 w32;
   case(pos)
     2'd0:
       w32 = cl[31:0];
     2'd1:
       w32 = cl[63:32];
     2'd2:
       w32 = cl[95:64];
     2'd3:
       w32 = cl[127:96];
   endcase // case (pos)
   return w32;
endfunction

function jump_t select_pd(jump_t [WORDS_PER_CL-1:0] cl, logic[LG_WORDS_PER_CL-1:0] pos);
   jump_t j;
   case(pos)
     2'd0:
       j = cl[0];
     2'd1:
       j = cl[1];
     2'd2:
       j = cl[2];
     2'd3:
       j = cl[3];
   endcase // case (pos)
   return j;
endfunction

   
function jump_t predecode(logic [31:0] insn);
   jump_t j = NOT_CFLOW;
   logic [5:0] 				 opcode = insn[31:26];
   logic [4:0] 				 rt = insn[20:16];
   logic [4:0] 				 rs = insn[25:21];
   
   case(opcode)
     6'd0: /* rtype */
       begin
	  if(insn[5:0] == 6'd8) /* jr */
	    begin
	       j = (rs == 5'd31) ? IS_JR_R31 : IS_JR;
	    end
	  else if(insn[5:0] == 6'd9)
	    begin
	       j = IS_JALR;
	    end
       end
     6'd1:
       begin
	  case(rt)
	    'd0:
	      begin
		 j = IS_COND_BR;
	      end
	    'd1:
	      begin
		 j = IS_COND_BR;
	      end
	    'd2:
	      begin
		 j = IS_L_COND_BR;
	      end
	    'd3:
	      begin
		 j = IS_L_COND_BR;
	      end
	    'd17:
	      begin
		 j = IS_BR_AND_LINK;
	      end
	    default:
	      begin
	      end
	  endcase // case (rt)	  
       end
     6'd2:
       begin
	  j = IS_J;
       end   
     6'd3:
       begin
	  j = IS_JAL;
       end
     6'd4:
       begin
	  j = ((rs == 'd0) && (rt == 'd0)) ? IS_BR : IS_COND_BR;
       end
     6'd5:
       begin
	  j = IS_COND_BR;
       end
     6'd6:
       begin
	  j = IS_COND_BR;
       end
     6'd7:
       begin
	  j = IS_COND_BR;
       end
     6'd17:
       begin
	  if(insn[25:21]==5'd8)
	    begin
	       case(insn[17:16])
		 2'b00: //bc1f
		   begin
		      j = IS_COND_BR;
		   end
		 2'b01: //bc1t
		   begin
		      j = IS_COND_BR;
		   end
		 2'b10: //bc1fl;
		   begin
		      j = IS_L_COND_BR;
		   end
		 2'b11: //bc1tl
		   begin
		      j = IS_L_COND_BR;
		   end	       
	       endcase // case (insn[17:16])
	    end // if (insn[25:21]==5'd8)
       end
     6'd20:
       begin
	  j = IS_L_COND_BR;
       end
     6'd21:
       begin
	  j = IS_L_COND_BR;
       end
     6'd22:
       begin
	  j = IS_L_COND_BR;
       end
     6'd23:
       begin
	  j = IS_L_COND_BR;
       end     
     default:
       begin
	  j = NOT_CFLOW;
       end
   endcase // case (opcode)   

   return j;
endfunction
   
   
   typedef enum logic [2:0] {IDLE = 'd0,
                             ACTIVE = 'd1,
                             INJECT_RELOAD = 'd2,
			     RELOAD_TURNAROUND = 'd3,
                             FLUSH_CACHE = 'd4,
			     WAIT_FOR_NOT_FULL = 'd5,
			     RELOAD_UTLB = 'd6
			    } state_t;
   
   logic [(`M_WIDTH-1):0] rr_pc, r_pc, n_pc, nn_pc, r_miss_pc, n_miss_pc;
   logic [(`M_WIDTH-1):0] r_cache_pc, n_cache_pc;
   logic [(`M_WIDTH-1):0] r_btb_pc;
   
   
   state_t n_state, r_state;
   logic 		  r_restart_req, n_restart_req;
   logic 		  r_restart_ack, n_restart_ack;
   logic 		  r_req, n_req;
   logic 		  r_valid_out;
   logic 		  t_miss, t_hit;
   logic 		  t_push_insn;
   logic 		  t_clear_fq;
   logic 		  r_flush_req, n_flush_req;
   logic 		  r_flush_complete, n_flush_complete;
   logic 		  n_delay_slot, r_delay_slot;
   logic 		  t_take_br, t_is_cflow;
   logic [31:0] 	  t_insn_data;
   logic [`M_WIDTH-1:0]   t_simm;
   logic 		  t_is_call, t_is_ret;
   logic 		  t_utlb_hit;
   utlb_entry_t t_utlb_hit_entry;
   
   
   localparam SEXT = `M_WIDTH-16;
   insn_fetch_t t_insn;
   jump_t t_pd;

   
   logic [31:0] 	  r_cycle;
   always_ff@(posedge clk)
     begin
	r_cycle <= reset ? 'd0 : r_cycle + 'd1;
     end

   assign flush_complete = r_flush_complete;
   
   assign insn_valid = !fq_empty;
   assign restart_ack = r_restart_ack;

   assign mem_req_valid = r_mem_req_valid;
   assign mem_req_addr = r_mem_req_addr;
   assign mem_req_tag = 'd0;
   assign mem_req_opcode = MEM_LW;
   assign cache_hits = r_cache_hits;
   assign cache_accesses = r_cache_accesses;
   
//`define DEBUG 1
`ifdef DEBUG
   
   always_ff@(posedge clk)
     begin
	
	// $display("now cycle %d, hit %b, miss %b, state %d : pushing valid %b, bits %x, ip %x, full %b monitor %b, popping %b, ip %x, monitor %b, fetching %x, tag %d, r_pc %x, rr_pc %x", 
	// 	 r_cycle, 
	// 	 t_hit,
	// 	 t_miss, 
	// 	 r_state,
	// 	 t_push_insn,
	// 	 t_insn.data,
	// 	 t_insn.pc,
	// 	 fq_full,		 
	// 	 t_insn.data[31:26] == 6'd5,
	// 	 insn_ack,
	// 	 insn.pc,
	// 	 insn.data[31:26] == 6'd5,
	// 	 r_cache_pc,
	// 	 r_cycle[15:0],
	// 	 r_pc,
	// 	 rr_pc);

	$display("now cycle %d, popping %b, ip %x, data %x, tag %d, monitor %b",
		 r_cycle, 
		 insn_ack,
		 insn.pc,
		 insn.data,
		 insn.pht_idx,
		 insn.data[31:26] == 6'd5);
     end // always_ff@ (posedge clk)
`endif //  `ifdef DEBUG

   
   always_ff@(negedge clk)
     begin
	if(fq_full && t_push_insn) $stop();
	if(fq_empty && insn_ack) $stop();
     end

   always_comb
     begin
	n_fq = r_fq;
	n_fq_tail_ptr = r_fq_tail_ptr;
	n_fq_head_ptr = r_fq_head_ptr;
	fq_empty = (r_fq_head_ptr == r_fq_tail_ptr);
	fq_full = (r_fq_head_ptr != r_fq_tail_ptr) &&
		  (r_fq_head_ptr[`LG_FQ_ENTRIES-1:0] == r_fq_tail_ptr[`LG_FQ_ENTRIES-1:0]);
	insn = r_fq[r_fq_head_ptr[`LG_FQ_ENTRIES-1:0]];
		
	if(t_push_insn)
	  begin
	     n_fq[r_fq_tail_ptr[`LG_FQ_ENTRIES-1:0]] = t_insn;
	     n_fq_tail_ptr = r_fq_tail_ptr + 'd1;
	  end
	if(insn_ack)
	  begin
	     n_fq_head_ptr = r_fq_head_ptr + 'd1;
	  end
	
     end


   utlb #(1) utlb0 (
		    .clk(clk),
		    .reset(reset),
		    .flush(n_flush_complete),
		    .req(n_req),
		    .addr({t_cache_tag,t_cache_idx,{IDX_START{1'b0}}}),
		    .tlb_rsp(tlb_rsp),
		    .tlb_rsp_valid(tlb_rsp_valid),
		    .hit(t_utlb_hit),
		    .hit_entry(t_utlb_hit_entry)
	       );

   assign utlb_miss_req = r_utlb_miss_req;
   assign utlb_miss_paddr = r_utlb_miss_paddr;

   always_ff@(posedge clk)
     begin
	if(restart_valid && restart_src_is_indirect)
	  begin
	     //$display("installing %x in location %d", 
	     //restart_pc, 
	     //restart_src_pc[(`LG_BTB_SZ+1):2]);
	     r_btb[restart_src_pc[(`LG_BTB_SZ+1):2]] <= restart_pc;
	  end	
     end // always_ff@ (posedge clk)

   always_ff@(posedge clk)
     begin
	r_btb_pc <= reset ? 'd0 : r_btb[n_cache_pc[(`LG_BTB_SZ+1):2]];;
     end
   
  
   always_comb
     begin
	n_utlb_miss_req = 1'b0;
	n_utlb_miss_paddr = r_utlb_miss_paddr;
	n_pc = r_pc;
	nn_pc = rr_pc;
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
	n_restart_req = restart_valid | r_restart_req;
	t_miss = r_req && !(r_valid_out && (r_tag_out == r_cache_tag));
	t_hit = r_req && (r_valid_out && (r_tag_out == r_cache_tag));
	t_pd = select_pd(r_jump_out, rr_pc[WORD_STOP-1:WORD_START]);
	t_insn_data = select_cl32(r_array_out, rr_pc[WORD_STOP-1:WORD_START]);
	t_simm = {{SEXT{t_insn_data[15]}},t_insn_data[15:0]};
	t_clear_fq = 1'b0;
	t_push_insn = 1'b0;
	t_take_br = 1'b0;
	t_is_cflow = 1'b0;	
	t_is_call = 1'b0;
	t_is_ret = 1'b0;
	
	case(r_state)
	  IDLE:
	    begin
	       if(n_restart_req)
		 begin
		    n_restart_ack = 1'b1;
		    n_restart_req = 1'b0;
		    n_pc = restart_pc;
		    n_state = ACTIVE;
		    t_clear_fq = 1'b1;
		 end
	    end	  
	  ACTIVE:
	    begin
	       t_cache_idx = r_pc[IDX_STOP-1:IDX_START];
	       t_cache_tag = r_pc[(`M_WIDTH-1):IDX_STOP];
	       /* accessed with this address */
	       n_cache_pc = r_pc;
	       n_req = 1'b1;
	       n_pc = r_pc + 'd4;
	       nn_pc = r_pc;
	       //$display("r_pc = %x, rr_pc = %x", r_pc, rr_pc);
	       
	       if(n_flush_req)
		 begin
		    //$display("REQ FLUSHING VALID BITS at %d", r_cycle);
		    n_flush_req = 1'b0;
		    //n_flush_complete = 1'b1;
		    t_clear_fq = 1'b1;
		    n_state = FLUSH_CACHE;
		    t_cache_idx = 0;
		 end
	       else if(n_restart_req)
		 begin
		    n_restart_ack = 1'b1;
		    n_restart_req = 1'b0;
		    n_delay_slot = 1'b0;
		    n_pc = restart_pc;
		    nn_pc = 'd0;
		    n_req = 1'b0;
		    //$display("restart to %x at %d", n_pc, r_cycle);
		    n_state = ACTIVE;
		    t_clear_fq = 1'b1;
		 end // if (n_restart_req)
	       else if(!t_utlb_hit && (t_miss || t_hit))
		 begin
		    //$display("cycle %d : i-side utlb miss for %x, t_miss = %b, t_hit = %b", 
		    //r_cycle, rr_pc, t_miss, t_hit);
		    n_miss_pc = rr_pc;
		    n_utlb_miss_req = 1'b1;
		    n_utlb_miss_paddr = rr_pc[`M_WIDTH-1:`LG_PG_SZ];
		    n_pc = r_pc;
		    nn_pc = rr_pc;
		    n_state = RELOAD_UTLB;
		 end
	       else if(t_miss)
		 begin
		    n_state = INJECT_RELOAD;
		    n_mem_req_addr = {rr_pc[`M_WIDTH-1:`LG_L1D_CL_LEN], {`LG_L1D_CL_LEN{1'b0}}};
		    n_mem_req_valid = 1'b1;
		    n_miss_pc = rr_pc;
		    n_pc = r_pc;
		    nn_pc = rr_pc;
		 end
	       else if(t_hit && !fq_full)
		 begin
		    if(t_pd == IS_JAL || t_pd == IS_J)
		      begin
			 t_is_cflow = 1'b1;
			 n_delay_slot = 1'b1;
			 t_take_br = 1'b1;
			 t_is_call = (t_pd == IS_JAL);
			 //if(t_is_call) $display("predict jal at %x will return to %x",
			 //r_cache_pc, r_cache_pc+'d8);
			 n_pc = {r_cache_pc[`M_WIDTH-1:28], t_insn_data[25:0], 2'd0};
		      end
		    else if(t_pd == IS_BR)
		      begin
			 t_is_cflow = 1'b1;			 
			 n_delay_slot = 1'b1;
			 t_take_br = 1'b1;
			 n_pc = ((r_cache_pc + 'd4) + {t_simm[`M_WIDTH-3:0], 2'd0});
		      end
		    else if(t_pd == IS_L_COND_BR)
		      begin
			 //$display("decoded likely branch @ %x", r_cache_pc);
			 //treat as always taken for simplicity
			 t_is_cflow = 1'b1;			 
			 n_delay_slot = 1'b1;
			 t_take_br = 1'b1;
			 n_pc = ((r_cache_pc + 'd4) + {t_simm[`M_WIDTH-3:0], 2'd0});
		      end
		    else if(t_pd == IS_BR_AND_LINK)
		      begin
			 //check if insn is bal or cond branch thinks its gonna be taken
			 if(r_pht_out[1] || t_insn_data[25:21] == 5'd0)
			   begin
			      t_is_cflow = 1'b1;
			      n_delay_slot = 1'b1;			      
			      n_pc = ((r_cache_pc + 'd4) + {t_simm[`M_WIDTH-3:0], 2'd0});
			      t_is_call = 1'b1;
			      t_take_br = 1'b1;
			      //$display("some flavor of branch and link, predicting target %x", n_pc);
			   end
		      end
		    else if(t_pd == IS_COND_BR && r_pht_out[1])
		      begin
			 t_is_cflow = 1'b1;			 
			 n_delay_slot = 1'b1;
			 t_take_br = 1'b1;
			 n_pc = ((r_cache_pc + 'd4) + {t_simm[`M_WIDTH-3:0], 2'd0});
		      end
		    else if(t_pd == IS_JR_R31)
		      begin
			 t_is_cflow = 1'b1;
			 t_is_ret = 1'b1;
			 n_delay_slot = 1'b1;
			 t_take_br = 1'b1;
			 n_pc = r_spec_return_stack[r_spec_rs_tos+'d1];
			 //$display("predict jr at %x will return to %x",
			 //r_cache_pc, n_pc);
			 //$stop();
		      end // if (t_pd == IS_JR_R31)
		    else if(t_pd == IS_JR || t_pd == IS_JALR)
		      begin
			 t_is_cflow = 1'b1;			 
			 n_delay_slot = 1'b1;
			 t_take_br = 1'b1;
			 t_is_call = (t_pd == IS_JALR);
			 n_pc = r_btb_pc;
			 //$display("predicted target for %x is %x", r_cache_pc, n_pc);			 
		      end
		    if(r_delay_slot)
		      begin
			 n_delay_slot = 1'b0;
		      end
		    t_push_insn = 1'b1;
		 end // if (t_hit && !fq_full)
	       else if(t_hit && fq_full)
		 begin
		    //$display("full insn queue at cycle %d", r_cycle);
		    n_pc = r_pc;
		    nn_pc = rr_pc;
		    n_miss_pc = r_cache_pc;
		    n_state = WAIT_FOR_NOT_FULL;
		 end
	    end
	  INJECT_RELOAD:
	    begin
	       if(mem_rsp_valid)
		 begin
		    //$stop();
		    n_state = RELOAD_TURNAROUND;
		 end
	    end
	  RELOAD_TURNAROUND:
	    begin
	       t_cache_idx = r_miss_pc[IDX_STOP-1:IDX_START];
	       t_cache_tag = r_miss_pc[(`M_WIDTH-1):IDX_STOP];
	       if(!fq_full)
		 begin
		    //$display("==> cycle %d : r_miss_pc = %x, r_pc = %x, rr_pc = %x, r_delay_slot = %b, full %b",
		    //	     r_cycle, r_miss_pc, r_pc, rr_pc, r_delay_slot, fq_full);
		    //if(r_miss_pc == 32'h0002a280) $stop();
		    /* accessed with this address */
		    n_cache_pc = r_miss_pc;
		    n_req = 1'b1;
		    n_state = ACTIVE;
		 end
	       //begin
	       //$display("stalled on full queue at cycle %d in reload for %x", 
		//	    r_cycle, r_miss_pc);
	       //end
	    end
	  FLUSH_CACHE:
	    begin
	       if(r_cache_idx == (L1I_NUM_SETS-1))
		 begin
		    //$display("REQ FLUSHING COMPLETE at %d", r_cycle);
		    n_flush_complete = 1'b1;
		    n_state = IDLE;
		 end
	       t_cache_idx = r_cache_idx + 'd1;
	    end
	  WAIT_FOR_NOT_FULL:
	    begin
	       t_cache_idx = r_miss_pc[IDX_STOP-1:IDX_START];
	       t_cache_tag = r_miss_pc[(`M_WIDTH-1):IDX_STOP];
	       n_cache_pc = r_miss_pc;
	       if(!fq_full)
		 begin
		    n_req = 1'b1;
		    n_state = ACTIVE;
		 end
	       else if(n_flush_req)
		 begin
		    n_flush_req = 1'b0;
		    //n_flush_complete = 1'b1;
		    t_clear_fq = 1'b1;
		    n_state = FLUSH_CACHE;
		    t_cache_idx = 0;		    
		 end
	    end
	  RELOAD_UTLB:
	    begin
	       t_cache_idx = r_miss_pc[IDX_STOP-1:IDX_START];
	       t_cache_tag = r_miss_pc[(`M_WIDTH-1):IDX_STOP];
	       //if(fq_full) $stop();
	       //if(n_flush_req) $stop();
	       if(tlb_rsp_valid)
		 begin
		    n_cache_pc = r_miss_pc;
		    n_req = 1'b1;
		    n_state = fq_full ? WAIT_FOR_NOT_FULL : ACTIVE;
		 end
	    end // case: RELOAD_TLB
	  default:
	    begin
	    end
	endcase // case (r_state)
     end // always_comb

   always_comb
     begin
	n_cache_accesses = r_cache_accesses;
	n_cache_hits = r_cache_hits;	
	if(t_hit)
	  begin
	     n_cache_hits = r_cache_hits + 'd1;
	  end
	if(r_req)
	  begin
	     n_cache_accesses = r_cache_accesses + 'd1;
	  end
     end
   
   always_comb
     begin
	t_insn.data = t_insn_data;
	t_insn.pc = r_cache_pc;
	t_insn.pred_target = n_pc;
	t_insn.pred = t_take_br;
	t_insn.pht_idx = r_pht_idx;
     end
   
   logic t_wr_valid_ram_en = mem_rsp_valid || r_state == FLUSH_CACHE;
   logic t_valid_ram_value = (r_state != FLUSH_CACHE);
   logic [`LG_L1D_NUM_SETS-1:0] t_valid_ram_idx = mem_rsp_valid ? r_mem_req_addr[IDX_STOP-1:IDX_START] : r_cache_idx;


   always_comb
     begin
	//t_xor_pc_hist = n_cache_pc[`GBL_HIST_LEN+1:2] ^ r_spec_gbl_hist;
	t_xor_pc_hist = n_cache_pc[`GBL_HIST_LEN+1:2] ^ r_arch_gbl_hist;	
	n_pht_idx = t_xor_pc_hist[`LG_PHT_SZ-1:0];
	
	t_pht_val = r_pht_update_out;
	t_do_pht_wr = r_pht_update;
	
	case(r_pht_update_out)
	  2'd0:
	    begin
	       if(r_take_br)
		 begin
		    t_pht_val =  2'd1;
		 end
	       else
		 begin
		    t_do_pht_wr = 1'b0;
		 end
	    end
	  2'd1:
	    begin
	       t_pht_val = r_take_br ? 2'd2 : 2'd0;
	    end
	  2'd2:
	    begin
	       t_pht_val = r_take_br ? 2'd3 : 2'd1;
	    end
	  2'd3:
	    begin
	       if(!r_take_br)
		 begin
		    t_pht_val = 2'd2;
		 end
	       else
		 begin
		    t_do_pht_wr = 1'b0;
		 end
	    end
	endcase // case (r_pht_update_out)
     end
   
   always_ff@(posedge clk)
     begin
	if(reset)
	  begin
	     r_pht_idx <= 'd0;
	     r_pht_update <= 1'b0;
	     r_pht_update_idx <= 'd0;
	     r_take_br <= 1'b0;
	  end
	else
	  begin
	     r_pht_idx <= n_pht_idx;
	     r_pht_update <= branch_pc_valid;
	     r_pht_update_idx <= branch_pht_idx;
	     r_take_br <= took_branch;
	  end
     end // always_ff@

   //always_ff@(negedge clk)
     //begin
     //if(r_cache_pc == 'h21e74)
	  //begin
	     //$display("%x : %b maps to %d", r_cache_pc, r_arch_gbl_hist, n_pht_idx);
	     //$display("%x : %b maps to %d", r_cache_pc, r_arch_gbl_hist, n_pht_idx);
	  //end
	//if(t_is_cflow)
	//begin
	//$display("%b -> %b (take br = %b)",n_spec_gbl_hist, r_spec_gbl_hist, t_take_br);
	// end
   //end
	  

   ram2r1w #(.WIDTH(2), .LG_DEPTH(`LG_PHT_SZ) ) pht
     (
      .clk(clk),
      .rd_addr0(n_pht_idx),
      .rd_addr1(branch_pht_idx),
      .wr_addr(r_pht_update_idx),
      .wr_data(t_pht_val),
      .wr_en(t_do_pht_wr),
      .rd_data0(r_pht_out),
      .rd_data1(r_pht_update_out)
      );
         
   ram1r1w #(.WIDTH(1), .LG_DEPTH(`LG_L1D_NUM_SETS))
   valid_array (
	   .clk(clk),
	   .rd_addr(t_cache_idx),
	   .wr_addr(t_valid_ram_idx),
	   .wr_data(t_valid_ram_value),
	   .wr_en(t_wr_valid_ram_en),
	   .rd_data(r_valid_out)
	   );

   
   ram1r1w #(.WIDTH(N_TAG_BITS), .LG_DEPTH(`LG_L1D_NUM_SETS))
   tag_array (
	   .clk(clk),
	   .rd_addr(t_cache_idx),
	   .wr_addr(r_mem_req_addr[IDX_STOP-1:IDX_START]),
	   .wr_data(r_mem_req_addr[`M_WIDTH-1:IDX_STOP]),
	   .wr_en(mem_rsp_valid),
	   .rd_data(r_tag_out)
	   );
   
   ram1r1w #(.WIDTH(L1I_CL_LEN_BITS), .LG_DEPTH(`LG_L1D_NUM_SETS)) 
   insn_array (
	   .clk(clk),
	   .rd_addr(t_cache_idx),
	   .wr_addr(r_mem_req_addr[IDX_STOP-1:IDX_START]),
	   .wr_data({bswap32(mem_rsp_load_data[127:96]),
		     bswap32(mem_rsp_load_data[95:64]),
		     bswap32(mem_rsp_load_data[63:32]), 
		     bswap32(mem_rsp_load_data[31:0])}),
	   .wr_en(mem_rsp_valid),
	   .rd_data(r_array_out)
	   );
   
   ram1r1w #(.WIDTH($bits(jump_t)*WORDS_PER_CL), .LG_DEPTH(`LG_L1D_NUM_SETS))
   pd_data (
	    .clk(clk),
	    .rd_addr(t_cache_idx),
	    .wr_addr(r_mem_req_addr[IDX_STOP-1:IDX_START]),
	    .wr_data({predecode(bswap32(mem_rsp_load_data[127:96])),
		      predecode(bswap32(mem_rsp_load_data[95:64])),
		      predecode(bswap32(mem_rsp_load_data[63:32])),
		      predecode(bswap32(mem_rsp_load_data[31:0]))}),
	    .wr_en(mem_rsp_valid),
	    .rd_data(r_jump_out)
	    );
	    
	     
   always_comb
     begin
	n_spec_rs_tos = r_spec_rs_tos;
	if(n_restart_ack)
	  begin
	     n_spec_rs_tos = r_arch_rs_tos;
	  end
	else if(t_is_call)
	  begin
	     n_spec_rs_tos = r_spec_rs_tos - 'd1;
	  end
	else if(t_is_ret)
	  begin
	     n_spec_rs_tos = r_spec_rs_tos + 'd1;
	  end
     end

   always_ff@(posedge clk)
     begin
	if(t_is_call)
	  begin
	     r_spec_return_stack[r_spec_rs_tos] <= r_cache_pc + 'd8;
	  end
	else if(n_restart_ack)
	  begin
	     r_spec_return_stack <= r_arch_return_stack;
	  end
     end // always_ff@ (posedge clk)
   
   always_ff@(posedge clk)
     begin
	if(retire_reg_valid && retire_valid && retired_call)
	  begin
	     r_arch_return_stack[r_arch_rs_tos] <= retire_reg_data;
	  end
     end
   always_comb
     begin
	n_arch_rs_tos = r_arch_rs_tos;
	if(retire_valid && retired_call)
	  begin
	     n_arch_rs_tos = r_arch_rs_tos - 'd1;
	  end
	else if(retire_valid && retired_ret)
	  begin
	     n_arch_rs_tos = r_arch_rs_tos + 'd1;
	  end
     end

   always_comb
     begin
	n_spec_gbl_hist = r_spec_gbl_hist;
	if(n_restart_ack)
	  begin
	     n_spec_gbl_hist = r_arch_gbl_hist;
	  end
	else if(t_is_cflow)
	  begin
	     n_spec_gbl_hist = {r_spec_gbl_hist[`GBL_HIST_LEN-2:0], t_take_br};
	  end
     end

   always_comb
     begin
	n_arch_gbl_hist = r_arch_gbl_hist;
	if(branch_pc_valid)
	  begin
	     n_arch_gbl_hist = {r_arch_gbl_hist[`GBL_HIST_LEN-2:0], took_branch};
	  end
     end
   
	      
   // always@(posedge clk)
   //   begin
   // 	r_tag_out <= r_tag[t_cache_idx];
   // 	if(mem_rsp_valid)
   // 	  begin
   // 	     r_tag[r_mem_req_addr[IDX_STOP-1:IDX_START]] <= r_mem_req_addr[`M_WIDTH-1:IDX_STOP]; 
   // 	  end
   //   end   

   always_ff@(posedge clk)
     begin
	r_fq <= n_fq;
     end
   
   always_ff@(posedge clk)
     begin
	if(reset)
	  begin
	     r_state <= IDLE;
	     r_pc <= 'd0;
	     rr_pc <= 'd0;
	     r_miss_pc <= 'd0;
	     r_cache_pc <= 'd0;
	     r_restart_ack <= 1'b0;
	     r_cache_idx <= 'd0;
	     r_cache_tag <= 'd0;
	     r_req <= 1'b0;
	     r_mem_req_valid <= 1'b0;
	     r_mem_req_addr <= 'd0;
	     r_fq_head_ptr <= 'd0;
	     r_fq_tail_ptr <= 'd0;
	     r_restart_req <= 1'b0;
	     r_flush_req <= 1'b0;
	     r_flush_complete <= 1'b0;
	     r_delay_slot <= 1'b0;
	     r_spec_rs_tos <= RETURN_STACK_ENTRIES-1;
	     r_arch_rs_tos <= RETURN_STACK_ENTRIES-1;
	     r_arch_gbl_hist <= 'd0;
	     r_spec_gbl_hist <= 'd0;
	     r_utlb_miss_req <= 1'b0;
	     r_utlb_miss_paddr <= 'd0;	     
	     r_cache_hits <= 'd0;
	     r_cache_accesses <= 'd0;	     
	  end
	else
	  begin
	     r_state <= n_state;
	     r_pc <= n_pc;
	     rr_pc <= nn_pc;
	     r_miss_pc <= n_miss_pc;
	     r_cache_pc <= n_cache_pc;
	     r_restart_ack <= n_restart_ack;
	     r_cache_idx <= t_cache_idx;
	     r_cache_tag <= t_cache_tag;	     
	     r_req <= n_req;
	     r_mem_req_valid <= n_mem_req_valid;
	     r_mem_req_addr <= n_mem_req_addr;
	     r_fq_head_ptr <= t_clear_fq ? 'd0 : n_fq_head_ptr;
	     r_fq_tail_ptr <= t_clear_fq ? 'd0 : n_fq_tail_ptr;
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
	  end
     end
   
endmodule

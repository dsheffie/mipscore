`ifndef __uop_hdr__
`define __uop_hdr__

`include "machine.vh"

typedef enum logic [7:0] 
  {
   SLL,
   SRL,
   SRA,
   SLLV,
   SRLV,
   SRAV,
   JR,
   JALR,
   SYSCALL,
   MFHI,
   MTHI,
   MULT,
   MULTU,
   DIV,
   DIVU,
   ADD,
   ADDU,
   SUB,
   SUBU,
   AND,
   OR,
   XOR,
   NOR,
   SLT,
   SLTU,
   MFLO,
   MTLO,
   BEQ,
   BNE,
   BLEZ,
   BGTZ,
   ADDI,
   ADDIU,
   SLTI,
   SLTIU,
   ANDI,
   ORI,
   XORI,
   LUI,
   J,
   JAL,
   MFC0,
   MTC0,
   MFC1,
   MTC1,
   LW,
   LB,
   LBU,
   LH,
   LHU,
   SB,
   SH,
   SW,
   BEQL,
   BNEL, 
   BLTZ, 
   BGEZ,
   BLTZL,
   BGEZL,
   BGTZL,
   BLEZL,
   MOVN,
   MOVZ,
   TEQ,
   EXT,
   INS,
   MADD,
   MADDU,
   MUL,
   MSUB,
   CLZ,
   LWL,
   LWR,
   SWL,
   SWR,
   SEB,
   SEH,
   DADDU,
   DADDIU,
   DSUBU,
   DSLL,
   DSRL,
   DSRA,
   DSLL32,
   DSRL32,
   DSRA32,
   DSLLV,
   DSRLV,
   DSRAV,
   LD,
   SD,
   LDL,
   LDR,
   SDL,
   SDR,
   BAL,
   BGEZAL,
   BGEZALL,
   RDHWR,
   SC,
   SYNC,
   BREAK,
   SDC1,
   LDC1,
   SWC1,
   LWC1,
   LWC1_MERGE,
   SWC1_MERGE,
   SP_ABS,
   DP_ABS,
   SP_NEG,
   DP_NEG,
   SP_SQRT,
   DP_SQRT,
   SP_RSQRT,
   DP_RSQRT,
   SP_RECIP,
   DP_RECIP,
   SP_ADD,
   DP_ADD,
   SP_SUB,
   DP_SUB,
   SP_MUL,
   DP_MUL,
   SP_DIV,
   DP_DIV,
   SP_MOV,
   DP_MOV,
   BC1TL,
   BC1T,
   BC1FL,
   BC1F,
   SP_CMP_LT,
   DP_CMP_LT,
   SP_CMP_EQ,
   DP_CMP_EQ,
   SP_CMP_LE,
   DP_CMP_LE,
   TRUNC_DP_W,
   TRUNC_SP_W,
   CVT_W_DP,
   CVT_W_SP,
   CVT_SP_DP,
   CVT_DP_SP,
   MOVF,
   MOVT,
   FP_MOVN,
   FP_MOVZ,
   FP_MOVF,
   FP_MOVT,
   ERET,
   MTC1_MERGE,
   MFC1_MERGE,
   MOVI,
   MOV,
   MONITOR,
   NOP,
   DI,
   EI,
   WAIT,
   II //illegal instruction
   } opcode_t;

function logic is_mult(opcode_t op);
   logic     x;
   case(op)
     MUL:
       x = 1'b1;
     MADD:
       x = 1'b1;
     MSUB:
       x = 1'b1;
     MULT:
       x = 1'b1;
     MULTU:
       x = 1'b1;
     default:
       x = 1'b0;
   endcase
   return x;
endfunction // is_mult

function logic is_div(opcode_t op);
   logic     x;
   case(op)
     DIV:
       x = 1'b1;
     DIVU:
       x = 1'b1;
     default:
       x = 1'b0;
   endcase
   return x;
endfunction // is_div

function logic is_store(opcode_t op);
   logic     x;
   case(op)
     SB:
       x = 1'b1;
     SH:
       x = 1'b1;
     SW:
       x = 1'b1;
     SDC1:
       x = 1'b1;
     SWC1_MERGE:
       x = 1'b1;
     SC:
       x = 1'b1;
     SWR:
       x = 1'b1;
     SWL:
       x = 1'b1;
     default:
       x = 1'b0;
   endcase // case (op)
   return x;
endfunction // is_store



typedef struct packed {
   opcode_t op;
   
   logic [`LG_PRF_ENTRIES-1:0] srcA;
   logic 		       srcA_valid;
   logic 		       fp_srcA_valid;
   logic [`LG_PRF_ENTRIES-1:0] srcB;
   logic 		       srcB_valid;
   logic 		       fp_srcB_valid;   
   logic [`LG_PRF_ENTRIES-1:0] srcC;
   logic 		       srcC_valid;
   logic 		       fp_srcC_valid;      
   logic [`LG_PRF_ENTRIES-1:0] dst;
   logic 		       dst_valid;
   logic 		       fp_dst_valid;

   logic 		       fcr_dst_valid;
   
   logic 		       hilo_dst_valid;
   logic [`LG_HILO_PRF_ENTRIES-1:0] hilo_dst;

   logic 			    fcr_src_valid;
   logic 			    hilo_src_valid;
   logic [`LG_HILO_PRF_ENTRIES-1:0] hilo_src;
     
   logic 		       has_delay_slot;
   logic 		       has_nullifying_delay_slot;
   logic [15:0] 	       imm;
   logic [`M_WIDTH-17:0]       jmp_imm;
   logic [`M_WIDTH-1:0]        pc;
   logic [`LG_ROB_ENTRIES-1:0] rob_ptr;
   logic 		       serializing_op;
   logic 		       must_restart;
   logic 		       br_pred;
   logic 		       is_int;
   logic 		       is_br;
   logic 		       is_mem;
   logic 		       is_fp;
   logic 		       is_store;
   logic [`LG_PHT_SZ-1:0]      pht_idx;
`ifdef VERILATOR
   logic [31:0] 	       clear_id;
`endif
`ifdef ENABLE_CYCLE_ACCOUNTING
   logic [63:0] 	    fetch_cycle;
`endif   
} uop_t;



`endif

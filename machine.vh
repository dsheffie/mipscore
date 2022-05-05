`ifndef __machine_hdr__
`define __machine_hdr__

`ifdef VERILATOR
 `define DEBUG_FPU 1
 `define ENABLE_CYCLE_ACCOUNTING 1
 `define ENABLE_FPU 1
 `define ENABLE_64BITS 1
// `define SINGLE_CYCLE_INT_DIVIDE 1
`endif

`define LG_M_WIDTH 5

//`define BIG_ENDIAN 1

//gshare branch predictor
`define LG_PHT_SZ 16

`define GBL_HIST_LEN 32

//page size
`define LG_PG_SZ 12

`define LG_UTLB_ENTRIES 3

`define LG_PRF_ENTRIES 6

`define LG_HILO_PRF_ENTRIES 2

`define LG_FCR_PRF_ENTRIES 2

//queue between decode and alloc
`define LG_DQ_ENTRIES 2

//queue between fetch and decode
`define LG_FQ_ENTRIES 3

//rob size
`define LG_ROB_ENTRIES 5

`define LG_RET_STACK_ENTRIES 2

/* non-uop queue */
`define LG_UQ_ENTRIES 3
/* mem uop queue */
`define LG_MEM_UQ_ENTRIES 3
/* fp uop queue */
`define LG_FP_UQ_ENTRIES 3
/* mem uop queue */
`define LG_MQ_ENTRIES 3

/* mem retry queue */
`define LG_MRQ_ENTRIES 3

`define MUL_LAT 2

`define DIV32_LAT 35

`define DIV64_LAT 67

`define MAX_LAT (`DIV64_LAT)

`define FP_MACC_LAT 8

`define FPU_LAT 4

`define FP_MAX_LAT (`FP_MACC_LAT)

//lg2 

// cacheline length (in bytes)
`define LG_L1D_CL_LEN 4

//number of sets in direct mapped cache
`define LG_L1D_NUM_SETS 8

`define LG_MEM_TAG_ENTRIES 2


`define M_WIDTH (1 << `LG_M_WIDTH)

`define LG_BTB_SZ 7

typedef enum logic [4:0] {
   MEM_LB  = 5'd0,
   MEM_LBU = 5'd1,
   MEM_LH  = 5'd2,
   MEM_LHU = 5'd3,
   MEM_LW  = 5'd4,
   MEM_SB  = 5'd5,
   MEM_SH  = 5'd6,
   MEM_SW  = 5'd7,
   MEM_SWR = 5'd8,
   MEM_SWL = 5'd9,
   MEM_LWR = 5'd10,
   MEM_LWL = 5'd11,
   MEM_LL  = 5'd12,
   MEM_SC  = 5'd13,
   MEM_SDC1 = 5'd14,
   MEM_LDC1 = 5'd15,
   MEM_SWC1 = 5'd16,
   MEM_LWC1 = 5'd17,
   MEM_MFC1 = 5'd18,			  
   MEM_LWC1_MERGE = 5'd19,
   MEM_SWC1_MERGE = 5'd20,			  
   MEM_MTC1_MERGE = 5'd21,
   MEM_MFC1_MERGE = 5'd22,			  			  
   MEM_DEAD_LD = 5'd23,
   MEM_DEAD_ST = 5'd24,
   MEM_DEAD_SC = 5'd25,
   MEM_LOAD_CL = 5'd26,
   MEM_STORE_CL = 5'd27,			  
   MEM_NOP = 5'd28			  
} mem_op_t;

typedef enum logic [5:0] {
      CPR0_INDEX = 6'd0,
      CPR0_RANDOM = 6'd1,
      CPR0_ENTRYL0 = 6'd2,
      CPR0_ENTRYL1 = 6'd3,
      CPR0_CONTEXT = 6'd4,
      CPR0_PAGEMASK = 6'd5,
      CPR0_WIRED = 6'd6,
      CPR0_BADVADDR = 6'd8,
      CPR0_COUNT = 6'd9,
      CPR0_ENTRYHI = 6'd10,
      CPR0_COMPARE = 6'd11,
      CPR0_STATUS = 6'd12,
      CPR0_CAUSE = 6'd13,
      CPR0_EPC = 6'd14,
      CPR0_PRID = 6'd15,
      CPR0_CONFIG = 6'd16,
      CPR0_LLADDR = 6'd17,
      CPR0_WATCHLO = 6'd18,
      CPR0_WATCHHI = 6'd19,
      CPR0_XCONTEXT = 6'd20,
      CPR0_FRAMEMASK = 6'd21,
      CPR0_BRDIAG = 6'd22,
      CPR0_PC = 6'd25,
      CPR0_ECC = 6'd26,
      CPR0_CACHEERR = 6'd27,
      CPR0_TAGLO = 6'd28,
      CPR0_TAGHI = 6'd29,
      CPR0_ERROREPC = 6'd30,
      CPR0_INTCTL = 6'd32,
      CPR0_EBASE = 6'd33,
      CPR0_BOGUS = 6'd63			    
} mips_cpr0_t;

typedef enum logic [4:0] {
   SR_IE = 5'd0,
   SR_EXL = 5'd1,
   SR_ERL = 5'd2,
   SR_SM = 5'd3,   			  
   SR_UM = 5'd4,
   SR_UX = 5'd5,
   SR_SX = 5'd6,
   SR_KX = 5'd7,
   SR_IM0 = 5'd8,
   SR_IM1 = 5'd9,
   SR_IM2 = 5'd10,
   SR_IM3 = 5'd11,
   SR_IM4 = 5'd12,
   SR_IM5 = 5'd13,
   SR_IM6 = 5'd14,
   SR_IM7 = 5'd15,			  
   SR_NMI = 5'd19,
   SR_SR  = 5'd20,
   SR_TS  = 5'd21,
   SR_BEV  = 5'd22,
   SR_PX  = 5'd23,
   SR_MX  = 5'd24,
   SR_RE  = 5'd25,
   SR_FR  = 5'd26,
   SR_RP  = 5'd27,
   SR_CU0 = 5'd28,
   SR_CU1 = 5'd29,			  
   SR_CU2 = 5'd30,			  
   SR_CU3 = 5'd31			  			  
 } mips_sr_t;

function mips_cpr0_t decode_cpr0(logic [4:0] pri, logic [2:0] sel);
   //MTC0 : reg 15 : srcB =  1, value 9d00176c
   //MTC0 : reg 12 : srcB =  1, value 9d00176c
   if(sel == 'd0)
     begin
	case(pri)
	  5'd0: return CPR0_INDEX;
	  5'd1: return CPR0_RANDOM;
	  5'd2: return CPR0_ENTRYL0;
	  5'd3: return CPR0_ENTRYL1;
	  5'd4: return CPR0_CONTEXT;
	  5'd5: return CPR0_PAGEMASK;
	  5'd6: return CPR0_WIRED;
	  5'd8: return CPR0_BADVADDR;
	  5'd9: return CPR0_COUNT;
	  5'd10: return CPR0_ENTRYHI;
	  5'd11: return CPR0_COMPARE;
	  5'd12: return CPR0_STATUS;
	  5'd13: return CPR0_CAUSE;
	  5'd14: return CPR0_EPC;
	  5'd15: return CPR0_PRID;
	  5'd16: return CPR0_CONFIG;
	  5'd17: return CPR0_LLADDR;
	  5'd18: return CPR0_WATCHLO;
	  5'd19: return CPR0_WATCHHI;
	  5'd20: return CPR0_XCONTEXT;
	  5'd21: return CPR0_FRAMEMASK;
	  5'd22: return CPR0_BRDIAG;
	  5'd25: return CPR0_PC;
	  5'd26: return CPR0_ECC;	  
	  5'd27: return CPR0_CACHEERR;
	  5'd28: return CPR0_TAGLO;
	  5'd29: return CPR0_TAGHI;	  
	  5'd30: return CPR0_ERROREPC;
	  default: return CPR0_BOGUS;	  
	endcase
     end
   else if(sel == 'd1)
     begin
	if(pri == 'd12)
	  return CPR0_INTCTL;
	else if(pri == 'd15)
	  return CPR0_EBASE;
	else 
	  return CPR0_BOGUS;
     end
   else
     return CPR0_BOGUS;
endfunction


typedef enum logic [4:0] {
  EXCCODE_INT = 5'd0,
  EXCCODE_MOD = 5'd1,
  EXCCODE_TLBL = 5'd2,
  EXCCODE_TLBS = 5'd3,
  EXCCODE_ADEL = 5'd4,
  EXCCODE_ADEH = 5'd5,
  EXCCODE_IDE = 5'd6,			  			  
  EXCCODE_DBE = 5'd7,			  			  			  
  EXCCODE_SYS = 5'd8,
  EXCCODE_BP = 5'd9,
  EXCCODE_RI = 5'd10,
  EXCCODE_CPU = 5'd11,
  EXCCODE_OV = 5'd12,
  EXCCODE_TR = 5'd13,
  EXCCODE_FPE = 5'd15,
  EXCCODE_WATCH = 5'd23			   
} mips_exccode_t;

typedef enum logic [2:0] {
  MIPS32_USEG = 3'b000,
  MIPS32_KSEG0 = 3'b100, /* mapped cached */
  MIPS32_KSEG1 = 3'b101, /* kernel umapped uncachable */
  MIPS32_KSSEG = 3'b110, /* supervisor mapped, uncached */
  MIPS32_KSEG3 = 3'b111  /* kernel mapped */
} mips32_seg_t;
 	
function mips32_seg_t va2seg(logic [31:0] va);
   case(va[31:29])
     3'b000:
       return MIPS32_USEG;
     3'b001:
       return MIPS32_USEG;
     3'b010:
       return MIPS32_USEG;
     3'b011:
       return MIPS32_USEG;
     3'b100:
       return MIPS32_KSEG0;
     3'b101:
       return MIPS32_KSEG1;
     3'b110:
       return MIPS32_KSSEG;          
     3'b111:
       return MIPS32_KSEG3;
   endcase // case (va[31:29])
endfunction // va2seg

function logic is_uncached_va(logic [31:0] va);
   mips32_seg_t seg;
   seg = va2seg(va);
   return (seg == MIPS32_KSEG1) || (seg == MIPS32_KSSEG);
endfunction

function logic is_unmapped_va(logic [31:0] va);
   return va2seg(va)==MIPS32_KSEG1;
endfunction

/* MIPS R10000 exception ordering 
* Cold Reset (highest priority)
* Soft Reset
* Nonmaskable Interrupt (NMI)‡
* Cache error –– Instruction cache*
* Cache error –– Data cache*
* Cache error –– Secondary cache*
* Cache error –– System interface*
* Address error –– Instruction fetch
* TLB refill –– Instruction fetch
* TLB invalid –– Instruction fetch
* Bus error –– Instruction fetch
* Integer overflow, 
* Trap, 
* System Call,
* Breakpoint, 
* Reserved Instruction, 
* Coprocessor Unusable
* Floating-Point Exception
* Address error –– Data access
* TLB refill –– Data access
* TLB invalid –– Data access
* TLB modified –– Data write
* Watch
* Bus error –– Data access
* Interrupt (lowest priority)
*/

typedef enum logic [4:0] {
 NO_ERROR = 5'd0,			   
 IC_ERROR = 5'd1,
 DC_ERROR = 5'd2,
 IA_ERROR = 5'd3, /* instruction address error */
 ITLB_REFILL_ERROR = 5'd4,
 ITLB_INVALID_ERROR = 5'd5,
 INSN_BUS_ERROR = 5'd6,
 INT_OVERFLOW = 5'd7,
 RESERVED_INSN = 5'd8,
 COPROC_UNUSABLE = 5'd9,
 FP_EXCEPTION = 5'd10,
 DA_ERROR = 5'd11, /* data address error */
 DTLB_REFILL_ERROR = 5'd12,
 DTLB_INVALID_ERROR = 5'd13,
 DTLB_MODIFIED_ERROR = 5'd14,
 DATA_BUS_ERROR	= 5'd15,
 BR_MISPREDICT = 5'd16			  
} exception_t;


function logic [63:0] bswap64(logic [63:0] in);
`ifdef BIG_ENDIAN
   return {in[7:0], in[15:8], in[23:16], in[31:24], in[39:32], in[47:40], in[55:48], in[63:56]};
`else
   return in;
`endif
endfunction

function logic [31:0] bswap32(logic [31:0] in);
`ifdef BIG_ENDIAN
   return {in[7:0], in[15:8], in[23:16], in[31:24]};
`else
   return in;
`endif
endfunction

function logic [15:0] bswap16(logic [15:0] in);
`ifdef BIG_ENDIAN
   return {in[7:0], in[15:8]};
`else
   return in;
`endif
endfunction

function logic sext16(logic [15:0] in);
`ifdef BIG_ENDIAN
   return in[7];
`else
   return in[15];
`endif
endfunction

`endif

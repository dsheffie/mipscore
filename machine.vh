`ifndef __machine_hdr__
`define __machine_hdr__

`ifdef VERILATOR
 `define DEBUG_FPU 1
 `define ENABLE_CYCLE_ACCOUNTING 1
 `define ENABLE_FPU 1
 `define ENABLE_64BITS 1
// `define SINGLE_CYCLE_INT_DIVIDE 1
`endif

`define LG_M_WIDTH 6

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
`define LG_L1D_NUM_SETS 10

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
   MEM_NOP = 5'd26			  
} mem_op_t;


typedef enum logic [4:0] {
      CPR0_INDEX = 5'd0,
      CPR0_RANDOM = 5'd1,
      CPR0_ENTRYL0 = 5'd2,
      CPR0_ENTRYL1 = 5'd3,
      CPR0_CONTEXT = 5'd4,
      CPR0_PAGEMASK = 5'd5,
      CPR0_WIRED = 5'd6,
      CPR0_BADVADDR = 5'd8,
      CPR0_COUNT = 5'd9,
      CPR0_ENTRYHI = 5'd10,
      CPR0_COMPARE = 5'd11,
      CPR0_STATUS = 5'd12,
      CPR0_CAUSE = 5'd13,
      CPR0_EPC = 5'd14,
      CPR0_PRID = 5'd15,
      CPR0_CONFIG = 5'd16,
      CPR0_LLADDR = 5'd17,
      CPR0_WATCHLO = 5'd18,
      CPR0_WATCHHI = 5'd19,
      CPR0_XCONTEXT = 5'd20,
      CPR0_FRAMEMASK = 5'd21,
      CPR0_BRDIAG = 5'd22,
      CPR0_PC = 5'd25,
      CPR0_ECC = 5'd26,
      CPR0_CACHEERR = 5'd27,
      CPR0_TAGLO = 5'd28,
      CPR0_TAGHI = 5'd29,
      CPR0_ERROREPC = 5'd30
} mips_cpr0_t;

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

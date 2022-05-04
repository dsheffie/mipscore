#ifndef __tophh__
#define __tophh__

#include <cstdint>
#include <cstdlib>
#include <cstdint>
#include <vector>
#include <cmath>
#include <tuple>
#include <map>
#include <cfenv>

#include <sys/time.h>
#include <boost/program_options.hpp>
#include <boost/dynamic_bitset.hpp>

#include <sys/mman.h>
#include <unistd.h>
#include <fstream>
#include <sys/stat.h>
#include <fcntl.h>
#include <fenv.h>
#include <verilated.h>
#include "Vcore_l1d_l1i.h"
#include "loadelf.hh"
#include "helper.hh"
#include "interpret.hh"
#include "globals.hh"
#include "disassemble.hh"
#include "saveState.hh"
#include "pipeline_record.hh"

#include "Vcore_l1d_l1i__Dpi.h"
#include "svdpi.h"

static const int MEM_LB  = 0;
static const int MEM_LBU = 1;
static const int MEM_LH  = 2;
static const int MEM_LHU = 3;
static const int MEM_LW  = 4;
static const int MEM_SB  = 5;
static const int MEM_SH  = 6;
static const int MEM_SW  = 7;
static const int MEM_SWR = 8;
static const int MEM_SWL = 9;
static const int MEM_LWR = 10;
static const int MEM_LWL = 11;
static const int MEM_LL  = 12;
static const int MEM_SC  = 13;
static const int MEM_SDC1 = 14;
static const int MEM_LDC1 = 15;
static const int MEM_SWC1 = 16;
static const int MEM_LWC1 = 17;
static const int MEM_MFC1 = 18;
static const int MEM_LWC1_MERGE = 19;
static const int MEM_SWC1_MERGE = 20;
static const int MEM_MTC1_MERGE = 21;
static const int MEM_MFC1_MERGE = 22;
static const int MEM_DEAD_LD = 23;
static const int MEM_DEAD_ST = 24;
static const int MEM_DEAD_SC = 25;
static const int MEM_LOAD_CL = 26;
static const int MEM_STORE_CL = 27;
static const int MEM_NOP = 28;



/* begin -copied from virtualmips */

#define PIC32_R(a)              (0x1F800000 + (a))

/* pic32 stuff */

#define PIC32_OSCCON    PIC32_R (0xf000)
#define PIC32_OSCTUN    PIC32_R (0xf010)
#define PIC32_DDPCON    PIC32_R (0xf200)  /* Debug Data Port Control */
#define PIC32_DEVID     PIC32_R (0xf220)
#define PIC32_SYSKEY    PIC32_R (0xf230)
#define PIC32_RCON      PIC32_R (0xf600)
#define PIC32_RSWRST    PIC32_R (0xf610)

/* interrupt controller */

#define PIC32_INTCON    PIC32_R (0x81000)           /* Interrupt Control */
#define PIC32_INTCONCLR PIC32_R (0x81004)
#define PIC32_INTCONSET PIC32_R (0x81008)
#define PIC32_INTCONINV PIC32_R (0x8100C)
#define PIC32_INTSTAT   PIC32_R (0x81010)           /* Interrupt Status */
#define PIC32_IPTMR             PIC32_R (0x81020)           /* Temporal Proximity Timer */
#define PIC32_IPTMRCLR  PIC32_R (0x81024)
#define PIC32_IPTMRSET  PIC32_R (0x81028)
#define PIC32_IPTMRINV  PIC32_R (0x8102C)
#define PIC32_IFS(n)    PIC32_R (0x81030+((n)<<4))  /* IFS(0..2) - Interrupt Flag Status */
#define PIC32_IFSCLR(n) PIC32_R (0x81034+((n)<<4))
#define PIC32_IFSSET(n) PIC32_R (0x81038+((n)<<4))
#define PIC32_IFSINV(n) PIC32_R (0x8103C+((n)<<4))
#define PIC32_IEC(n)    PIC32_R (0x81060+((n)<<4))  /* IEC(0..2) - Interrupt Enable Control */
#define PIC32_IECCLR(n) PIC32_R (0x81064+((n)<<4))
#define PIC32_IECSET(n) PIC32_R (0x81068+((n)<<4))
#define PIC32_IECINV(n) PIC32_R (0x8106C+((n)<<4))
#define PIC32_IPC(n)    PIC32_R (0x81090+((n)<<4))  /* IPC(0..12) - Interrupt Priority Control */
#define PIC32_IPCCLR(n) PIC32_R (0x81094+((n)<<4))
#define PIC32_IPCSET(n) PIC32_R (0x81098+((n)<<4))
#define PIC32_IPCINV(n) PIC32_R (0x8109C+((n)<<4))

/* prefetch */
#define PIC32_CHECON	PIC32_R (0x84000)   /* Prefetch cache control */

/* memory configuration */

#define PIC32_BMXCON    PIC32_R (0x82000) /* Memory configuration */
#define PIC32_BMXDKPBA  PIC32_R (0x82010) /* Data RAM kernel program base address */
#define PIC32_BMXDUDBA  PIC32_R (0x82020) /* Data RAM user data base address */
#define PIC32_BMXDUPBA  PIC32_R (0x82030) /* Data RAM user program base address */
#define PIC32_BMXDRMSZ  PIC32_R (0x82040) /* Data RAM size */
#define PIC32_BMXPUPBA  PIC32_R (0x82050) /* Program Flash user program base address */
#define PIC32_BMXPFMSZ  PIC32_R (0x82060) /* Program Flash size */
#define PIC32_BMXBOOTSZ PIC32_R (0x82070) /* Boot Flash size */

/* uart */

#define PIC32_U1MODE            PIC32_R (0x6000) /* Mode */
#define PIC32_U1MODECLR         PIC32_R (0x6004)
#define PIC32_U1MODESET         PIC32_R (0x6008)
#define PIC32_U1MODEINV         PIC32_R (0x600C)
#define PIC32_U1STA             PIC32_R (0x6010) /* Status and control */
#define PIC32_U1STACLR          PIC32_R (0x6014)
#define PIC32_U1STASET          PIC32_R (0x6018)
#define PIC32_U1STAINV          PIC32_R (0x601C)
#define PIC32_U1TXREG           PIC32_R (0x6020) /* Transmit */
#define PIC32_U1RXREG           PIC32_R (0x6030) /* Receive */
#define PIC32_U1BRG             PIC32_R (0x6040) /* Baud rate */
#define PIC32_U1BRGCLR          PIC32_R (0x6044)
#define PIC32_U1BRGSET          PIC32_R (0x6048)
#define PIC32_U1BRGINV          PIC32_R (0x604C)

#define PIC32_TRISA             PIC32_R (0x86000)       /* Port A: mask of inputs */
#define PIC32_TRISACLR          PIC32_R (0x86004)
#define PIC32_TRISASET          PIC32_R (0x86008)
#define PIC32_TRISAINV          PIC32_R (0x8600C)
#define PIC32_PORTA             PIC32_R (0x86010)       /* Port A: read inputs, write outputs */
#define PIC32_PORTACLR          PIC32_R (0x86014)
#define PIC32_PORTASET          PIC32_R (0x86018)
#define PIC32_PORTAINV          PIC32_R (0x8601C)
#define PIC32_LATA              PIC32_R (0x86020)       /* Port A: read/write outputs */
#define PIC32_LATACLR           PIC32_R (0x86024)
#define PIC32_LATASET           PIC32_R (0x86028)
#define PIC32_LATAINV           PIC32_R (0x8602C)
#define PIC32_ODCA              PIC32_R (0x86030)       /* Port A: open drain configuration */
#define PIC32_ODCACLR           PIC32_R (0x86034)
#define PIC32_ODCASET           PIC32_R (0x86038)
#define PIC32_ODCAINV           PIC32_R (0x8603C)

#define PIC32_SPI1CON           PIC32_R (0x5800) /* Control */
#define PIC32_SPI1CONCLR            PIC32_R (0x5804)
#define PIC32_SPI1CONSET            PIC32_R (0x5808)
#define PIC32_SPI1CONINV            PIC32_R (0x580C)
#define PIC32_SPI1STAT          PIC32_R (0x5810) /* Status */
#define PIC32_SPI1STATCLR           PIC32_R (0x5814)
#define PIC32_SPI1STATSET           PIC32_R (0x5818)
#define PIC32_SPI1STATINV           PIC32_R (0x581C)
#define PIC32_SPI1BUF               PIC32_R (0x5820) /* Transmit and receive buffer */
#define PIC32_SPI1BRG               PIC32_R (0x5830) /* Baud rate generator */
#define PIC32_SPI1BRGCLR            PIC32_R (0x5834)
#define PIC32_SPI1BRGSET            PIC32_R (0x5838)
#define PIC32_SPI1BRGINV            PIC32_R (0x583C)

#define PIC32_SPI2CON           PIC32_R (0x5A00) /* Control */
#define PIC32_SPI2CONCLR        PIC32_R (0x5A04)
#define PIC32_SPI2CONSET        PIC32_R (0x5A08)
#define PIC32_SPI2CONINV        PIC32_R (0x5A0C)
#define PIC32_SPI2STAT          PIC32_R (0x5A10) /* Status */
#define PIC32_SPI2STATCLR       PIC32_R (0x5A14)
#define PIC32_SPI2STATSET       PIC32_R (0x5A18)
#define PIC32_SPI2STATINV       PIC32_R (0x5A1C)
#define PIC32_SPI2BUF           PIC32_R (0x5A20) /* Transmit and receive buffer */
#define PIC32_SPI2BRG           PIC32_R (0x5A30) /* Baud rate generator */
#define PIC32_SPI2BRGCLR        PIC32_R (0x5A34)
#define PIC32_SPI2BRGSET        PIC32_R (0x5A38)
#define PIC32_SPI2BRGINV        PIC32_R (0x5A3C)


/*                                                                                                                                                
 * SPI Control register.                                                                                                                          
 */
#define PIC32_SPICON_MSTEN      0x00000020      /* Master mode */
#define PIC32_SPICON_CKP        0x00000040      /* Idle clock is high level */
#define PIC32_SPICON_SSEN       0x00000080      /* Slave mode: SSx pin enable */
#define PIC32_SPICON_CKE        0x00000100      /* Output data changes on                                                                         
                                                 * transition from active clock                                                                   
                                                 * state to Idle clock state */
#define PIC32_SPICON_SMP        0x00000200      /* Master mode: input data sampled                                                                
                                                 * at end of data output time. */
#define PIC32_SPICON_MODE16     0x00000400      /* 16-bit data width */
#define PIC32_SPICON_MODE32     0x00000800      /* 32-bit data width */
#define PIC32_SPICON_DISSDO     0x00001000      /* SDOx pin is not used */
#define PIC32_SPICON_SIDL       0x00002000      /* Stop in Idle mode */
#define PIC32_SPICON_FRZ        0x00004000      /* Freeze in Debug mode */
#define PIC32_SPICON_ON         0x00008000      /* SPI Peripheral is enabled */
#define PIC32_SPICON_ENHBUF     0x00010000      /* Enhanced buffer enable */
#define PIC32_SPICON_SPIFE      0x00020000      /* Frame synchronization pulse                                                                    
                                                 * coincides with the first bit clock */
#define PIC32_SPICON_FRMPOL     0x20000000      /* Frame pulse is active-high */
#define PIC32_SPICON_FRMSYNC    0x40000000      /* Frame sync pulse input (Slave mode) */
#define PIC32_SPICON_FRMEN      0x80000000      /* Framed SPI support */

/*                                                                                        * SPI Status register.                                                                   */
#define PIC32_SPISTAT_SPIRBF    0x00000001      /* Receive buffer is full */
#define PIC32_SPISTAT_SPITBE    0x00000008      /* Transmit buffer is empty */
#define PIC32_SPISTAT_SPIROV    0x00000040      /* Receive overflow flag */
#define PIC32_SPISTAT_SPIBUSY   0x00000800      /* SPI is busy */



#define PIC32_USTA_URXDA        0x00000001      /* Receive Data Available (read-only) */
#define PIC32_USTA_OERR         0x00000002      /* Receive Buffer Overrun */
#define PIC32_USTA_FERR         0x00000004      /* Framing error detected (read-only) */
#define PIC32_USTA_PERR         0x00000008      /* Parity error detected (read-only) */
#define PIC32_USTA_RIDLE        0x00000010      /* Receiver is idle (read-only) */
#define PIC32_USTA_ADDEN        0x00000020      /* Address Detect mode */
#define PIC32_USTA_URXISEL      0x000000C0      /* Bitmask: receive interrupt is set when... */
#define PIC32_USTA_URXISEL_NEMP 0x00000000      /* ...receive buffer is not empty */
#define PIC32_USTA_URXISEL_HALF 0x00000040      /* ...receive buffer becomes 1/2 full */
#define PIC32_USTA_URXISEL_3_4  0x00000080      /* ...receive buffer becomes 3/4 full */
#define PIC32_USTA_TRMT         0x00000100      /* Transmit shift register is empty (read-only) */
#define PIC32_USTA_UTXBF        0x00000200      /* Transmit buffer is full (read-only) */
#define PIC32_USTA_UTXEN        0x00000400      /* Transmit Enable */
#define PIC32_USTA_UTXBRK       0x00000800      /* Transmit Break */
#define PIC32_USTA_URXEN        0x00001000      /* Receiver Enable */
#define PIC32_USTA_UTXINV       0x00002000      /* Transmit Polarity Inversion */
#define PIC32_USTA_UTXISEL      0x0000C000      /* Bitmask: TX interrupt is generated when... */
#define PIC32_USTA_UTXISEL_1    0x00000000      /* ...the transmit buffer contains at least one empty space */
#define PIC32_USTA_UTXISEL_ALL  0x00004000      /* ...all characters have been transmitted */
#define PIC32_USTA_UTXISEL_EMP  0x00008000      /* ...the transmit buffer becomes empty */
#define PIC32_USTA_ADDR         0x00FF0000      /* Automatic Address Mask */
#define PIC32_USTA_ADM_EN       0x01000000      /* Automatic Address Detect */


/* end - copied from virtualmips */

static const std::unordered_map<uint32_t, std::string> pic32_mmio_reg_names = {
  {PIC32_OSCCON, "PIC32_OSCCON"},
  {PIC32_OSCTUN, "PIC32_OSCTUN"},
  {PIC32_DDPCON, "PIC32_DDPCON"},
  {PIC32_DEVID, "PIC32_DEVID"},
  {PIC32_SYSKEY, "PIC32_SYSKEY"},
  {PIC32_RCON, "PIC32_RCON"},
  {PIC32_RSWRST, "PIC32_RSWRST"},
  {PIC32_BMXCON, "PIC32_BMXCON"},
  {PIC32_BMXDKPBA, "PIC32_BMXDKPBA"},
  {PIC32_BMXDUDBA, "PIC32_BMXDUDBA"},
  {PIC32_BMXDUPBA, "PIC32_BMXDUPBA"},
  {PIC32_BMXDRMSZ, "PIC32_BMXDRMSZ"},
  {PIC32_BMXPUPBA, "PIC32_BMXPUPBA"},
  {PIC32_BMXPFMSZ, "PIC32_BMXPFMSZ"},
  {PIC32_BMXBOOTSZ, "PIC32_BMXBOOTSZ"},
  {PIC32_U1MODE, "PIC32_U1MODE"},
  {PIC32_U1MODECLR, "PIC32_U1MODECLR"},
  {PIC32_U1MODESET, "PIC32_U1MODESET"},
  {PIC32_U1MODEINV, "PIC32_U1MODEINV"},
  {PIC32_U1STA, "PIC32_U1STA"},
  {PIC32_U1STACLR, "PIC32_U1STACLR"},
  {PIC32_U1STASET, "PIC32_U1STASET"},
  {PIC32_U1STAINV, "PIC32_U1STAINV"},
  {PIC32_U1TXREG, "PIC32_U1TXREG"},
  {PIC32_U1RXREG, "PIC32_U1RXREG"},
  {PIC32_U1BRG, "PIC32_U1BRG"},
  {PIC32_U1BRGCLR, "PIC32_U1BRGCLR"},
  {PIC32_U1BRGSET, "PIC32_U1BRGSET"},
  {PIC32_U1BRGINV, "PIC32_U1BRGINV"},
  {PIC32_TRISA, "PIC32_TRISA"},
  {PIC32_TRISACLR, "PIC32_TRISACLR"},
  {PIC32_TRISASET, "PIC32_TRISASET"},
  {PIC32_TRISAINV, "PIC32_TRISAINV"},
  {PIC32_PORTA, "PIC32_PORTA"},
  {PIC32_PORTACLR, "PIC32_PORTACLR"},
  {PIC32_PORTASET, "PIC32_PORTASET"},
  {PIC32_PORTAINV, "PIC32_PORTAINV"},
  {PIC32_LATA, "PIC32_LATA"},
  {PIC32_LATACLR, "PIC32_LATACLR"},
  {PIC32_LATASET, "PIC32_LATASET"},
  {PIC32_LATAINV, "PIC32_LATAINV"},
  {PIC32_ODCA, "PIC32_ODCA"},
  {PIC32_ODCACLR, "PIC32_ODCACLR"},
  {PIC32_ODCASET, "PIC32_ODCASET"},
  {PIC32_ODCAINV, "PIC32_ODCAINV"},
  {PIC32_INTCON, "PIC32_INTCON"},
  {PIC32_INTSTAT, "PIC32_INTSTAT"},
  {PIC32_IPTMR, "PIC32_IPTMR"},
  {PIC32_IFS(0), "PIC32_IFS(0)"},
  {PIC32_IFS(1), "PIC32_IFS(1)"},
  {PIC32_IFS(2), "PIC32_IFS(2)"},
  {PIC32_IEC(0), "PIC32_IEC(0)"},
  {PIC32_IEC(1), "PIC32_IEC(1)"},
  {PIC32_IEC(2), "PIC32_IEC(2)"},
  {PIC32_IECCLR(0), "PIC32_IECCLR(0)"},
  {PIC32_IECCLR(1), "PIC32_IECCLR(1)"},
  {PIC32_IECCLR(2), "PIC32_IECCLR(2)"},
  {PIC32_IECSET(0), "PIC32_IECSET(0)"},
  {PIC32_IECSET(1), "PIC32_IECSET(1)"},
  {PIC32_IECSET(2), "PIC32_IECSET(2)"},
  {PIC32_IPC(0), "PIC32_IPC(0)"},
  {PIC32_IPC(1), "PIC32_IPC(1)"},
  {PIC32_IPC(2), "PIC32_IPC(2)"},
  {PIC32_IPC(4), "PIC32_IPC(3)"},
  {PIC32_IPC(4), "PIC32_IPC(4)"},
  {PIC32_IPC(5), "PIC32_IPC(5)"},    
  {PIC32_IPC(6), "PIC32_IPC(6)"},
  {PIC32_IPC(7), "PIC32_IPC(7)"},
  {PIC32_IPC(8), "PIC32_IPC(8)"},
  {PIC32_IPC(9), "PIC32_IPC(9)"},
  {PIC32_IPC(10), "PIC32_IPC(10)"},
  {PIC32_IPC(11), "PIC32_IPC(11)"},
  {PIC32_CHECON, "PIC32_CHECON"},
  {PIC32_SPI1CON, "PIC32_SPI1CON"},
  {PIC32_SPI1CONCLR, "PIC32_SPI1CONCLR"},
  {PIC32_SPI1CONSET, "PIC32_SPI1CONSET"},
  {PIC32_SPI1CONINV, "PIC32_SPI1CONINV"},
  {PIC32_SPI1STAT, "PIC32_SPI1STAT"},
  {PIC32_SPI1STATCLR, "PIC32_SPI1STATCLR"},
  {PIC32_SPI1STATSET, "PIC32_SPI1STATSET"},
  {PIC32_SPI1STATINV, "PIC32_SPI1STATINV"},
  {PIC32_SPI1BUF, "PIC32_SPI1BUF"},
  {PIC32_SPI1BRG, "PIC32_SPI1BRG"},    
  {PIC32_SPI1BRGCLR, "PIC32_SPI1BRGCLR"},
  {PIC32_SPI1BRGSET, "PIC32_SPI1BRGSET"},
  {PIC32_SPI1BRGINV, "PIC32_SPI1BRGINV"},
  {PIC32_SPI2CON, "PIC32_SPI2CON"},
  {PIC32_SPI2CONCLR, "PIC32_SPI2CONCLR"},
  {PIC32_SPI2CONSET, "PIC32_SPI2CONSET"},
  {PIC32_SPI2CONINV, "PIC32_SPI2CONINV"},
  {PIC32_SPI2STAT, "PIC32_SPI2STAT"},
  {PIC32_SPI2STATCLR, "PIC32_SPI2STATCLR"},
  {PIC32_SPI2STATSET, "PIC32_SPI2STATSET"},
  {PIC32_SPI2STATINV, "PIC32_SPI2STATINV"},
  {PIC32_SPI2BUF, "PIC32_SPI2BUF"},
  {PIC32_SPI2BRG, "PIC32_SPI2BRG"},    
  {PIC32_SPI2BRGCLR, "PIC32_SPI2BRGCLR"},
  {PIC32_SPI2BRGSET, "PIC32_SPI2BRGSET"},
  {PIC32_SPI2BRGINV, "PIC32_SPI2BRGINV"}
};


template <typename A, typename B>
inline double histo_mean_median(const std::map<A,B> &histo, A &median) {
  double acc = 0.0;
  B count = 0, x = 0;
  if(histo.size() == 0) {
    median = 0;
    return 0.0;
  }
  
  for(const auto &p : histo) {
    acc += (p.first * p.second);
    count += p.second;
  }

  acc /= count;
  for(const auto &p : histo) {
    x += p.second;
    if(x >= (count/2)) {
      median = p.first;
      break;
    }
  }
  return acc;
}


int fp32_add(int a_, int b_) {
  float a = *reinterpret_cast<float*>(&a_);
  float b = *reinterpret_cast<float*>(&b_);
  float y = a+b;
  return *reinterpret_cast<int*>(&y);
}

long long fp64_add(long long a_, long long b_) {
  static_assert(sizeof(long long) == sizeof(double), "long long must be 64b");
  double a = *reinterpret_cast<double*>(&a_);
  double b = *reinterpret_cast<double*>(&b_);
  double y = a+b;
  return *reinterpret_cast<long long*>(&y);
}

int fp32_mul(int a_, int b_) {
  float a = *reinterpret_cast<float*>(&a_);
  float b = *reinterpret_cast<float*>(&b_);
  float y = a*b;
  return *reinterpret_cast<int*>(&y);
}

long long fp64_mul(long long a_, long long b_) {
  static_assert(sizeof(long long) == sizeof(double), "long long must be 64b");
  double a = *reinterpret_cast<double*>(&a_);
  double b = *reinterpret_cast<double*>(&b_);
  double y = a*b;
  return *reinterpret_cast<long long*>(&y);
}


int fp32_div(int a_, int b_) {
  float a = *reinterpret_cast<float*>(&a_);
  float b = *reinterpret_cast<float*>(&b_);
  float y = a/b;
  return *reinterpret_cast<int*>(&y);
}

long long fp64_div(long long a_, long long b_) {
  static_assert(sizeof(long long) == sizeof(double), "long long must be 64b");
  double a = *reinterpret_cast<double*>(&a_);
  double b = *reinterpret_cast<double*>(&b_);
  double y = a/b;
  return *reinterpret_cast<long long*>(&y);
}


int fp32_sqrt(int a_) {
  float a = *reinterpret_cast<float*>(&a_);
  float y = std::sqrt(a);
  return *reinterpret_cast<int*>(&y);
}

long long fp64_sqrt(long long a_) {
  static_assert(sizeof(long long) == sizeof(double), "long long must be 64b");
  double a = *reinterpret_cast<double*>(&a_);
  double y = std::sqrt(a);
  return *reinterpret_cast<long long*>(&y);
}


int int32_to_fp32(int a_) {
  float y = (float)a_;
  return *reinterpret_cast<int*>(&y);
}

long long int32_to_fp64(int a_) {
  static_assert(sizeof(long long) == sizeof(double), "long long must be 64b");
  double y = static_cast<double>(a_);
  return *reinterpret_cast<long long*>(&y);
}

int fp64_to_fp32(long long a_) {
  double a = *reinterpret_cast<double*>(&a_);
  float y = static_cast<float>(a);
  return *reinterpret_cast<int*>(&y);
}

long long fp32_to_fp64(int a_) {
  float a = *reinterpret_cast<float*>(&a_); 
  double y = static_cast<double>(a);
  return *reinterpret_cast<long long*>(&y); 
}

long long fp64_to_int32(long long a_) {
  double a = *reinterpret_cast<double*>(&a_);
  long long t = static_cast<long long>(a);
  t &= ((1L<<32) - 1);
  return t;
}

int fp32_to_int32(int a_) {
  float a = *reinterpret_cast<float*>(&a_); 
  return static_cast<int>(a);
}


int fp32_compare_lt(int a_, int b_) {
  float a = *reinterpret_cast<float*>(&a_);
  float b = *reinterpret_cast<float*>(&b_);
  //assert(!std::isnan(a));
  //assert(!std::isnan(b));
  
  return (a<b);
}

int fp64_compare_lt(long long a_, long long b_) {
  double a = *reinterpret_cast<double*>(&a_);
  double b = *reinterpret_cast<double*>(&b_);
  return (a<b);
}

int fp32_compare_le(int a_, int b_) {
  float a = *reinterpret_cast<float*>(&a_);
  float b = *reinterpret_cast<float*>(&b_);
  //assert(!std::isnan(a));
  //assert(!std::isnan(b));
  
  return (a<=b);
}

int fp64_compare_le(long long a_, long long b_) {
  double a = *reinterpret_cast<double*>(&a_);
  double b = *reinterpret_cast<double*>(&b_);
  //assert(std::isnormal(a));
  //assert(std::isnormal(b));
  return (a<=b);
}

union itype {
  struct {
    uint32_t imm : 16;
    uint32_t rs : 5;
    uint32_t rt : 5;
    uint32_t op : 6;
  } uu;
  uint32_t u;
};

union rtype {
  struct {
    uint32_t subop : 6;
    uint32_t z : 5;
    uint32_t rd : 5;
    uint32_t rt : 5;
    uint32_t rs : 5;
    uint32_t op : 6;
  } uu;
  uint32_t u;
};

union ceqs {
  struct {
    uint32_t fpop : 6;
    uint32_t zeros : 2;
    uint32_t cc : 3;
    uint32_t fs : 5;
    uint32_t ft : 5;
    uint32_t fmt : 5;
    uint32_t opcode : 6;
  } uu;
  uint32_t u;
  ceqs(uint32_t fs, uint32_t ft, uint32_t cc) {
    uu.fpop = 50;
    uu.zeros = 0;
    uu.cc = cc;
    uu.fs = fs;
    uu.ft = ft;
    uu.fmt = 16;
    uu.opcode = 17;
  }  
};

union mtc1 {
  struct {
    uint32_t zeros : 11;
    uint32_t fs : 5;
    uint32_t rt : 5;
    uint32_t mt : 5;
    uint32_t opcode : 6;
  } uu;
  uint32_t u;
  mtc1(uint32_t fs, uint32_t rt) {
    uu.opcode = 17;
    uu.mt = 4;
    uu.zeros = 0;
    uu.fs = fs;
    uu.rt = rt;
  }
};


union mthi {
  struct {
    uint32_t secondary_opcode : 6;
    uint32_t zeros : 15;
    uint32_t rs : 5;
    uint32_t primary_opcode : 6;
  } uu;
  uint32_t u;
  mthi(uint32_t rs) {
    uu.primary_opcode = 0;
    uu.rs = rs;
    uu.zeros = 0;
    uu.secondary_opcode = 17;
  }
};

union mtlo {
  struct {
    uint32_t secondary_opcode : 6;
    uint32_t zeros : 15;
    uint32_t rs : 5;
    uint32_t primary_opcode : 6;
  } uu;
  uint32_t u;
  mtlo(uint32_t rs) {
    uu.primary_opcode = 0;
    uu.rs = rs;
    uu.zeros = 0;
    uu.secondary_opcode = 19;
  }
};



struct dbl {
  uint64_t f : 52;
  uint64_t e : 11;
  uint64_t s : 1;
} __attribute__((packed));

union double_ {
  static const uint32_t bias = 1023;
  dbl dd;
  double d;
  double_(double x) : d(x) {
    static_assert(sizeof(dbl)==sizeof(uint64_t), "bad size");
  };
};

template <typename T>
static inline T round_to_alignment(T x, T m) {
  return ((x+m-1) / m) * m;
}

static inline uint32_t get_insn(uint32_t pc, const state_t *s) {
  return bswap<IS_LITTLE_ENDIAN>(s->mem.get<uint32_t>(VA2PA(pc)));
}

static inline uint32_t to_uint32(float f) {
  return *reinterpret_cast<uint32_t*>(&f);
}

static inline uint64_t to_uint64(double d) {
  return *reinterpret_cast<uint64_t*>(&d);
}

static inline float to_float(uint32_t u) {
  return *reinterpret_cast<float*>(&u);
}

static inline double to_double(uint64_t u) {
  return *reinterpret_cast<double*>(&u);
}


template<typename T>
static inline T compute_fp_insn(uint32_t r_inst, fpOperation op, state_t *s) {
  T x = static_cast<T>(0);
  uint32_t ft = (r_inst>>16)&31;
  uint32_t fs = (r_inst>>11)&31;
  uint32_t fmt=(r_inst >> 21) & 31;	    
  T _fs = *reinterpret_cast<T*>(s->cpr1+fs);
  T _ft = *reinterpret_cast<T*>(s->cpr1+ft);  
  switch(op)
    {
    case fpOperation::abs:
      x = std::abs(_fs);
      break;
    case fpOperation::neg:
      x = -_fs;
      break;
    case fpOperation::mov:
      x = _fs;
      break;
    case fpOperation::add:
      x = _fs + _ft;
      break;
    case fpOperation::sub:
      x = _fs - _ft;
      break;
    case fpOperation::mul:
      x = _fs * _ft;
      break;
    case fpOperation::div:
      if(_ft==0.0) {
	x = std::numeric_limits<T>::max();
      }
      else {
	x = _fs / _ft;
      }
      break;
    case fpOperation::sqrt:
      x = std::sqrt(_fs);
      break;
    case fpOperation::rsqrt:
      x = static_cast<T>(1.0) / std::sqrt(_fs);
      break;
    case fpOperation::recip:
      x = static_cast<T>(1.0) / _fs;
      break;
      //case fpOperation::cvtd:
      //assert(fmt == FMT_W);
      //x = (double)(*((int32_t*)(s->cpr1 + fs)));
      //break;
      //case fpOperation::truncw: {
      //assert(fmt == FMT_D);
      //int32_t t = (int32_t)_fs;
      //*reinterpret_cast<int32_t*>(&x) = t;
      //break;
      //}
    default:
      break;
    }
  return x;
}



#endif

UNAME_S = $(shell uname -s)

OBJ = top.o verilated.o verilated_vcd_c.o loadelf.o interpret.o disassemble.o helper.o saveState.o sparse_mem.o interpret64.o linux_o32_syscall.o

SV_SRC = core_l1d_l1i.sv core.sv exec.sv decode_mips32.sv ext_mask.sv shiftregbit.sv shift_right.sv mul.sv find_first_set.sv divider.sv l1d.sv l1i.sv machine.vh rob.vh uop.vh fpu.sv utlb.sv tlb.sv fp_compare.sv fp_mul.sv fp_add.sv ram1r1w.sv ram2r1w.sv count_leading_zeros.sv fp_trunc.sv fp_div.sv unsigned_divider.sv

ifeq ($(UNAME_S),Linux)
	CXX = clang++-12 -flto
	MAKE = make
	VERILATOR_SRC = /home/dsheffie/local/share/verilator/include/verilated.cpp
	VERILATOR_VCD = /home/dsheffie/local/share/verilator/include/verilated_vcd_c.cpp
	VERILATOR_INC = /home/dsheffie/local/share/verilator/include
	VERILATOR = /home/dsheffie/local/bin/verilator
	EXTRA_LD = -lcapstone -lboost_program_options
endif

ifeq ($(UNAME_S),FreeBSD)
	CXX = CC -march=native
	VERILATOR_SRC = /opt/local/share/verilator/include/verilated.cpp
	VERILATOR_INC = /opt/local/share/verilator/include
	VERILATOR_VCD = /opt/local/share/verilator/include/verilated_vcd_c.cpp
        EXTRA_LD = -L/usr/local/lib -lcapstone -lboost_program_options
	MAKE = gmake
endif

ifeq ($(UNAME_S),Darwin)
	CXX = clang++ -I/opt/homebrew/include -flto
	VERILATOR_SRC = /opt/homebrew/Cellar/verilator/4.200_1/share/verilator/include/verilated.cpp
	VERILATOR_INC = /opt/homebrew/Cellar/verilator/4.200_1/share/verilator/include
	VERILATOR_VCD = /opt/homebrew/Cellar/verilator/4.200_1/share/verilator/include/verilated_vcd_c.cpp
	VERILATOR = /opt/homebrew/bin/verilator
	EXTRA_LD = -L/opt/homebrew/lib -lboost_program_options-mt -lcapstone
endif

OPT = -O3 -g -std=c++11 #-fomit-frame-pointer
CXXFLAGS = -std=c++11 -g  $(OPT) -I$(VERILATOR_INC) #-DLINUX_SYSCALL_EMULATION=1
LIBS =  $(EXTRA_LD) -lpthread

DEP = $(OBJ:.o=.d)

EXE = ooo_core

.PHONY : all clean

all: $(EXE)

$(EXE) : $(OBJ) obj_dir/Vcore_l1d_l1i__ALL.a
	$(CXX) $(CXXFLAGS) $(OBJ) obj_dir/*.o $(LIBS) -o $(EXE)

top.o: top.cc obj_dir/Vcore_l1d_l1i__ALL.a
	$(CXX) -MMD $(CXXFLAGS) -Iobj_dir -c $< 

verilated.o: $(VERILATOR_SRC)
	$(CXX) -MMD $(CXXFLAGS) -c $< 

verilated_vcd_c.o: $(VERILATOR_VCD)
	$(CXX) -MMD $(CXXFLAGS) -c $< 

%.o: %.cc
	$(CXX) -MMD $(CXXFLAGS) -c $< 

obj_dir/Vcore_l1d_l1i__ALL.a : $(SV_SRC)
	$(VERILATOR) -cc core_l1d_l1i.sv
	$(MAKE) OPT_FAST="-O3 -flto" -C obj_dir -f Vcore_l1d_l1i.mk

-include $(DEP)

clean:
	rm -rf $(EXE) $(OBJ) $(DEP) obj_dir

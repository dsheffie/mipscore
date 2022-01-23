#include "top.hh"

#define BRANCH_DEBUG 1
#define CACHE_STATS 1

char **globals::sysArgv = nullptr;
int globals::sysArgc = 0;
bool globals::enClockFuncts = false;
bool globals::isMipsEL = false;
uint64_t globals::icountMIPS = 0;
uint64_t globals::cycle = 0;
bool globals::trace_retirement = false;
bool globals::trace_fp = false;
static state_t *s = nullptr;
static state_t *ss = nullptr;

static boost::dynamic_bitset<> touched_lines(1UL<<28);

static pipeline_logger *pl = nullptr;

static uint64_t l1d_misses = 0, l1d_insns = 0;

static uint64_t last_retire_cycle = 0, last_retire_pc  = 0;

static std::map<uint64_t, uint64_t> retire_map;

static uint64_t n_fetch[5] = {0};
static uint64_t n_uq_full[3] = {0};
static uint64_t n_rdy[3] = {0};
void record_alloc(int a1, int a2, int r1, int r2) {
  if(a2)
    ++n_uq_full[2];
  else if(a1)
    ++n_uq_full[1];
  else
    ++n_uq_full[0];

  if(r2)
    ++n_rdy[2];
  else if(r1)
    ++n_rdy[1];
  else
    ++n_rdy[0];
  
}
void record_fetch(int p1, int p2, int p3, int p4) {
  if(p1)
    ++n_fetch[1];
  else if(p2)
    ++n_fetch[2];
  else if(p3)
    ++n_fetch[3];
  else if(p4)
    ++n_fetch[4];
  else
    ++n_fetch[0];
}
  

void record_retirement(long long pc, long long fetch_cycle, long long alloc_cycle, long long complete_cycle, long long retire_cycle,
		       int faulted , int is_mem, int missed_l1d) {

  //if(pc == 0x2046c || pc == 0x20464) {
  //std::cout << std::hex << pc << std::dec << " : " << alloc_cycle << "," << complete_cycle << "," << retire_cycle << "," << faulted << "\n";
  //}
  uint64_t delta = retire_cycle - last_retire_cycle;

  //if(delta == 3) {
  //std::cout << "curr = " << std::hex << pc << std::dec << " : " << getAsmString(get_insn(pc, s), pc) << "\n";
  //std::cout << "last = " << std::hex << last_retire_pc << std::dec << " : " << getAsmString(get_insn(last_retire_pc, s), last_retire_pc) << "\n";
  //}
  //std::cout << "delta = " << delta << "\n";
  retire_map[delta]++;
  
  last_retire_cycle = retire_cycle;
  last_retire_pc = pc;
  
  if(missed_l1d) {
    //std::cout << "pc = " << std::hex << pc << " missed cache " << std::dec
    //<< " : " << getAsmString(get_insn(pc, s), pc)
    //<< "\n";
    ++l1d_misses;
  }
  l1d_insns += is_mem;
  
  if(pl == nullptr) {
    return;
  }
  pl->append(pc, fetch_cycle, alloc_cycle, complete_cycle, retire_cycle, faulted);
}


static int buildArgcArgv(const char *filename, const char *sysArgs, char ***argv) {
  int cnt = 0;
  std::vector<std::string> args;
  char **largs = 0;
  args.push_back(std::string(filename));

  char *ptr = nullptr, *sa = nullptr;
  if(sysArgs) {
    sa = strdup(sysArgs);
    ptr = strtok(sa, " ");
  }

  while(ptr && (cnt<MARGS)) {
    args.push_back(std::string(ptr));
    ptr = strtok(nullptr, " ");
    cnt++;
  }
  largs = new char*[args.size()];
  for(size_t i = 0; i < args.size(); i++) {
    std::string s = args[i];
    size_t l = strlen(s.c_str());
    largs[i] = new char[l+1];
    memset(largs[i],0,sizeof(char)*(l+1));
    memcpy(largs[i],s.c_str(),sizeof(char)*l);
  }
  *argv = largs;
  if(sysArgs) {
    free(sa);
  }
  return (int)args.size();
}


int main(int argc, char **argv) {
  static_assert(sizeof(itype) == 4, "itype must be 4 bytes");
  //std::fesetround(FE_TOWARDZERO);
  namespace po = boost::program_options; 
  // Initialize Verilators variables
  bool enable_checker = true;
  std::string sysArgs, pipelog;
  std::string mips_binary = "dhrystone3";
  bool use_checkpoint = false, use_checker_only = false;
  uint64_t heartbeat = 1UL<<36;
  uint64_t max_cycle = 0, max_icnt = 0, mem_lat = 2;
  uint64_t last_store_addr = 0, last_load_addr = 0, last_addr = 0;
  int misses_inflight = 0;
  std::map<uint64_t, uint64_t> pushout_histo;
  int64_t mem_reply_cycle = -1L;
  try {
    po::options_description desc("Options");
    desc.add_options() 
      ("help", "Print help messages")
      ("args,a", po::value<std::string>(&sysArgs), "arguments to mips binary")
      ("checker,c", po::value<bool>(&enable_checker)->default_value(true), "use checker")
      ("isdump,d", po::value<bool>(&use_checkpoint)->default_value(false), "is a dump")
      ("file,f", po::value<std::string>(&mips_binary), "mips binary")
      ("heartbeat,h", po::value<uint64_t>(&heartbeat)->default_value(1<<24), "heartbeat for stats")
      ("memlat,m", po::value<uint64_t>(&mem_lat)->default_value(4), "memory latency")
      ("pipelog,p", po::value<std::string>(&pipelog), "log for pipeline tracing")
      ("maxcycle", po::value<uint64_t>(&max_cycle)->default_value(1UL<<34), "maximum cycles")
      ("maxicnt", po::value<uint64_t>(&max_icnt)->default_value(1UL<<50), "maximum icnt")
      ("tracefp", po::value<bool>(&globals::trace_fp)->default_value(false), "trace fp instructions")
      ("trace,t", po::value<bool>(&globals::trace_retirement)->default_value(false), "trace retired instruction stream")
      ("checkeronly,o", po::value<bool>(&use_checker_only)->default_value(false), "no RTL simulation, just run checker")
      ; 
    po::variables_map vm;
    po::store(po::parse_command_line(argc, argv, desc), vm);
    po::notify(vm); 
  }
  catch(po::error &e) {
    std::cerr <<"command-line error : " << e.what() << "\n";
    return -1;
  }
  uint32_t max_insns_per_cycle = 4;
  uint32_t max_insns_per_cycle_hist_sz = 2*max_insns_per_cycle;

  std::map<uint32_t, uint64_t> mispredicts;

  uint64_t hist = 0, spec_hist = 0;
  static const int TBL_SIZE = (1<<24);
  static const int BTB_SIZE = (1<<6);
  
  
  uint64_t inflight[32] = {0};
  uint64_t *insns_delivered = new uint64_t[max_insns_per_cycle_hist_sz];
  memset(insns_delivered, 0, sizeof(uint64_t)*max_insns_per_cycle_hist_sz);
  
  uint32_t max_inflight = 0;

  Verilated::commandArgs(argc, argv);
  
  const std::unique_ptr<VerilatedContext> contextp{new VerilatedContext};

  sparse_mem *sm0 = new sparse_mem();
  sparse_mem *sm1 = new sparse_mem();
  s = new state_t(*sm0);
  ss = new state_t(*sm1);
  initState(s);
  initState(ss);
  globals::sysArgc = buildArgcArgv(mips_binary.c_str(),sysArgs.c_str(),&globals::sysArgv);
  initCapstone();


  if(use_checkpoint) {
    loadState(*s, mips_binary.c_str());
  }
  else {
    load_elf(mips_binary.c_str(), s);
    mkMonitorVectors(s);
  }

  //debug interpreter functionality
  if(use_checker_only) {
    while((s->icnt < max_icnt) and (s->brk == 0)) {
      execMips(s);
    }
    //std::cout << *s << "\n";
    delete s;
    stopCapstone();
    exit(EXIT_SUCCESS);    
  }
  
   
   if(use_checkpoint) {
     loadState(*ss, mips_binary.c_str());
   }
   else {
     load_elf(mips_binary.c_str(), ss);
     mkMonitorVectors(ss);
   }

   switch (fegetround())
     {
     case FE_DOWNWARD:
       printf ("FPU round to downward\n");
       break;
     case FE_TONEAREST:
       printf ("FPU round to to-nearest\n");
       break;
     case FE_TOWARDZERO:
       printf ("FPU round to toward-zero\n");
       break;
     case FE_UPWARD:
       printf ("FPU round to upward\n");
       break;
     default:
       printf ("FPU round to unknown\n");
  }
  
  // Create an instance of our module under test
   //Vcore_l1d_l1i *tb = new Vcore_l1d_l1i;
  std::unique_ptr<Vcore_l1d_l1i> tb(new Vcore_l1d_l1i);
  uint32_t last_match_pc = 0;
  uint64_t last_retire = 0, last_check = 0, last_restart = 0;
  uint64_t last_retired_pc = 0, last_retired_fp_pc = 0;
  uint64_t mismatches = 0, n_stores = 0, n_loads = 0;
  uint64_t stores_not_hor = 0;
  uint64_t insns_retired = 0, n_branches = 0, n_mispredicts = 0, n_checks = 0, n_flush_cycles = 0;
  uint64_t n_iside_tlb_misses = 0, n_dside_tlb_misses = 0;
  bool got_mem_req = false, got_mem_rsp = false, got_monitor = false;
  //assert reset
  for(globals::cycle = 0; (globals::cycle < 4) && !Verilated::gotFinish(); ++globals::cycle) {
    contextp->timeInc(1);  // 1 timeprecision period passes...
    tb->mem_rsp_valid = 0;
    tb->mem_rsp_opcode = 0;
    tb->mem_req_ack = 0;
    tb->monitor_rsp_valid = 0;
    tb->monitor_rsp_data_valid = 0;
    tb->monitor_rsp_data = 0;    
    tb->reset = 1;
    tb->clk = 1;
    tb->eval();
    tb->clk = 0;
    tb->eval();
    ++globals::cycle;
  }
  s->pc = 0x000d0000;
  //deassert reset
  contextp->timeInc(1);  // 1 timeprecision period passes...  
  tb->reset = 0;
  tb->clk = 1;
  tb->eval();
  tb->clk = 0;
  tb->eval();
  ++globals::cycle;
  tb->resume = 1;
  tb->resume_pc = s->pc;
  tb->clk = 1;
  tb->eval();
  tb->clk = 0;
  tb->eval();
  
  ++globals::cycle;  
  tb->resume = 0;
  tb->clk = 1;
  tb->eval();
  tb->clk = 0;
  tb->eval();



  uint32_t pos = s->pc;
  //write out initialization instructions for the FP regisers  
  for(int i = 0; i < 32; i++) {
    uint32_t r = *reinterpret_cast<uint32_t*>(&s->cpr1[i]);
    itype z,y;
    mtc1 m(i, 1);
    z.uu.op = 15;
    z.uu.rt = 1;
    z.uu.rs = 1;
    z.uu.imm = (r >> 16);    
    y.uu.op = 13;
    y.uu.rt = 1;
    y.uu.rs = 1;
    y.uu.imm = r & 0xffff;
    *reinterpret_cast<uint32_t*>(s->mem[pos]) = bswap<false>(z.u);
    *reinterpret_cast<uint32_t*>(s->mem[pos+4]) = bswap<false>(y.u);
    *reinterpret_cast<uint32_t*>(s->mem[pos+8]) = bswap<false>(m.u);
    pos += 12;    
  }
  
  //write out initialization instructions for the GPRs
  for(int i = 1; i < 32; i++) {
    uint32_t r = *reinterpret_cast<uint32_t*>(&s->gpr[i]);
    itype z,y;
    z.uu.op = 15;
    z.uu.rt = i;
    z.uu.rs = i;
    z.uu.imm = (r >> 16);    
    y.uu.op = 13;
    y.uu.rt = i;
    y.uu.rs = i;
    y.uu.imm = r & 0xffff;
    *reinterpret_cast<uint32_t*>(s->mem[pos]) = bswap<false>(z.u);
    *reinterpret_cast<uint32_t*>(s->mem[pos+4]) = bswap<false>(y.u);
    pos += 8;
  }
  rtype b;
  b.u = 0;
  b.uu.subop = 13;
  *reinterpret_cast<uint32_t*>(s->mem[pos]) = bswap<false>(b.u);
  pos += 4;

  
  while(true) {
    bool should_break = false;
    if(tb->got_break) {
      should_break = true;
    }
    
    tb->mem_rsp_valid = 0;
    
    if(tb->mem_req_valid) {
      for(int i = 0; i < 4; i++) {
	tb->mem_rsp_load_data[i] = *reinterpret_cast<uint32_t*>(s->mem[tb->mem_req_addr + 4*i]);
      }
      tb->mem_rsp_valid = 1;
    }
    tb->clk = 0;
    tb->eval();
    tb->clk = 1;
    tb->eval();
    if(should_break)
      break;
    
    if(tb->retire_reg_valid) {
      s->gpr[tb->retire_reg_ptr] = tb->retire_reg_data;
      //if(tb->retire_reg_ptr == R_a0) {
      //std::cout << std::hex << "insn with pc " << tb->retire_pc << " updates a0 \n"
      //<< std::dec;
      //}
    }
    if(tb->retire_valid) {
      last_retire = 0;
      last_retired_pc = tb->retire_pc;
    }
    last_retire++;
    
    //if(last_retire > (20*mem_lat)) {
    //std::cerr << "DEAD = " << static_cast<int>(tb->got_ud) << "\n";
    // exit(-1);
    //}
  }

  for(int c = 0; c < 128; c++) {
    tb->mem_rsp_valid = 0;
    if(tb->mem_req_valid) {
      for(int i = 0; i < 4; i++) {
	tb->mem_rsp_load_data[i] = *reinterpret_cast<uint32_t*>(s->mem[tb->mem_req_addr + 4*i]);
      }
      tb->mem_rsp_valid = 1;
    }
    tb->clk = 0;
    tb->eval();
    tb->clk = 1;
    tb->eval();
  }
  //std::cout << "made it through init\n";
  //exit(-1);

  if(use_checkpoint) {
    loadState(*s, mips_binary.c_str());
  }
  else {
    load_elf(mips_binary.c_str(), s);
    mkMonitorVectors(s);
  }

  if(not(pipelog.empty())) {
    pl = new pipeline_logger(pipelog);
  }
  
  s->pc = ss->pc;
  while(!tb->ready_for_resume) {
    ++globals::cycle;  
      tb->clk = 1;
      tb->eval();
      tb->clk = 0;
      tb->eval();
  }
  ++globals::cycle;
  tb->resume = 1;
  tb->resume_pc = s->pc;
  tb->clk = 1;
  tb->eval();
  tb->clk = 0;
  tb->eval();
  ++globals::cycle;  
  tb->resume = 0;
  tb->clk = 1;
  tb->eval();
  tb->clk = 0;
  tb->eval();
  //done with initialize
  globals::cycle = 0;  

  double t0 = timestamp();
  while(!Verilated::gotFinish() && (globals::cycle < max_cycle) && (insns_retired < max_icnt)) {
    contextp->timeInc(1);  // 1 timeprecision periodd passes...    

    tb->clk = 1;
    tb->eval();

#ifdef LINUX_SYSCALL_EMULATION
    got_monitor = emulate_linux_syscall(tb, s);
    if(s->brk) {
      break;
    }
#else
    
    if(tb->monitor_req_valid) {
      bool handled = false;
      
      //std::cerr << "got monitor reason "
      //<< static_cast<int>(tb->monitor_req_reason)
      //<< " with "
      //<< touched_lines.count()
      //<< " touched cachelines in the machine\n";

      
      switch(tb->monitor_req_reason)
	{
	case 6: {
	  char *path = (char*)(s->mem + (uint32_t)s->gpr[R_a0]);
	  int32_t flags = remapIOFlags(s->gpr[R_a1]);
	  tb->monitor_rsp_data = open(path, flags, S_IRUSR|S_IWUSR);	  
	  tb->monitor_rsp_data_valid = 1;
	  handled = true;
#ifdef PRINT_SYSCALL
	  std::cout << insns_retired << " open " << path << " " << tb->monitor_rsp_data << "\n";
#endif
	  break;
	}
	case 7: {
	  int32_t fd = s->gpr[R_a0];
	  int32_t nr = s->gpr[R_a2];
	  tb->monitor_rsp_data = read(fd, (char*)(s->mem + (uint32_t)s->gpr[R_a1]), nr);
#ifdef PRINT_SYSCALL	  
	  std::cout << insns_retired << " read " << fd << ","
		    << std::hex << s->gpr[R_a1] << std::dec
		    << "," << nr
		    << " = "
		    << tb->monitor_rsp_data
		    << "\n";
#endif
	  tb->monitor_rsp_data_valid = 1;
	  handled = true;
	  break;

	}
	case 8: { /* int write(int file, char *ptr, int len) */
	  int32_t fd = s->gpr[R_a0];
	  int32_t nr = s->gpr[R_a2];
	  
	  tb->monitor_rsp_data = write(fd, (void*)(s->mem + (uint32_t)s->gpr[R_a1]), nr);
#ifdef PRINT_SYSCALL
	  std::cout << insns_retired << " write " << fd << ","
		    << std::hex << s->gpr[R_a1] << std::dec << "," << nr << "\n";
#endif
	  if(fd==1)
	    fflush(stdout);
	  else if(fd==2)
	    fflush(stderr);

	  tb->monitor_rsp_data_valid = 1;
	  handled = true;
	  break;
	}
	case 9: { /* lseek */
	  handled = true;
	  tb->monitor_rsp_data  = lseek(s->gpr[R_a0], s->gpr[R_a1], s->gpr[R_a2]);
	  tb->monitor_rsp_data_valid = 1;
	  break;
	}
	case 10: { /* close */
	  int32_t fd = s->gpr[R_a0];
	  handled = true;
	  tb->monitor_rsp_data = 0;
	  if(fd>2)
	    tb->monitor_rsp_data = (int32_t)close(fd);
#ifdef PRINT_SYSCALL
	  std::cout << insns_retired << " close " << fd << "\n";
#endif
	  tb->monitor_rsp_data_valid = 1;
	  break;
	}
	case 33: {
	  handled = true;	  
	  uint32_t uptr = *(uint32_t*)(s->gpr + R_a0);
	  timeval32_t tp32;	  
	  *((timeval32_t*)(s->mem + uptr)) = tp32;
	  tb->monitor_rsp_data_valid = 1;
	  tb->monitor_rsp_data = 0;
	  break;
	}
	case 34: {
	  handled = true;	  
	  uint32_t uptr = *(uint32_t*)(s->gpr + R_a0);
	  *((uint32_t*)(s->mem + uptr + 0)) = 0;
	  *((uint32_t*)(s->mem + uptr + 1)) = 0;
	  *((uint32_t*)(s->mem + uptr + 2)) = 0;
	  *((uint32_t*)(s->mem + uptr + 3)) = 0;
	  tb->monitor_rsp_data_valid = 1;
	  tb->monitor_rsp_data = 0;
	  break;
	}
	case 35: {
	  /* int getargs(char **argv) */
	  handled = true;
	  for(int i = 0; i < std::min(MARGS, globals::sysArgc); i++) {
	    uint32_t arrayAddr = ((uint32_t)s->gpr[R_a0])+4*i;
	    uint32_t ptr = bswap<false>(*((uint32_t*)(s->mem + arrayAddr)));
	    strcpy((char*)(s->mem + ptr), globals::sysArgv[i]);
	  }
	  tb->monitor_rsp_data_valid = 1;
	  tb->monitor_rsp_data = globals::sysArgc;
	  break;
	}
	case 50: /* get cycle */
	  handled = true;
	  tb->monitor_rsp_data = globals::cycle;
	  tb->monitor_rsp_data_valid = 1;
	  break;
	case 51: /* nuke caches */
	  handled = true;
	  break;
	case 52: {/* flush cacheline */
	  handled = true;
	  break;
	}
	case 53:
	  handled = true;
	  tb->monitor_rsp_data = insns_retired;
	  tb->monitor_rsp_data_valid = 1;
	  break;	  
	case 55:
	  handled = true;
	  *((uint32_t*)(s->mem + (uint32_t)s->gpr[R_a0] + 0)) = bswap<false>(K1SIZE);
	  /* No Icache */
	  *((uint32_t*)(s->mem + (uint32_t)s->gpr[R_a0] + 4)) = 0;
	  /* No Dcache */
	  *((uint32_t*)(s->mem + (uint32_t)s->gpr[R_a0] + 8)) = 0;
	  break;
	default:
	  break;
	}

      touched_lines.reset();
      if(!handled) {
	std::cout << "didn't handled monitor reason " << tb->monitor_req_reason << "\n";
	exit(-1);
	break;
      }
      tb->monitor_rsp_valid = 1;
      got_monitor = true;
      // std::cout << "handled = "
      // 		<< handled
      // 		<< " retire valid = "
      // 		<< static_cast<int>(tb->retire_valid)
      // 		<< "\n";
    }
#endif
    
    if(tb->retire_reg_valid) {
      s->gpr[tb->retire_reg_ptr] = tb->retire_reg_data;
      //if(tb->retire_reg_ptr == R_a0) {
      //std::cout << std::hex << "insn with pc " << tb->retire_pc << " updates a0 \n"
      //<< std::dec;
      //}      
    }

    // if(tb->retire_valid) {
    //   std::cout << std::hex
    // 		<< tb->retire_pc
    // 		<< std::dec
    // 		<< "\n";
    // }
    
    if(tb->retire_reg_fp_valid) {

      if((tb->retire_reg_ptr & 1)) {
	std::cout << "FP WTF "
		  << std::hex
		  << tb->retire_pc
		  << " " << std::dec
		  << getAsmString(get_insn(tb->retire_pc, s), tb->retire_pc)
		  << " retire valid = "
		  << static_cast<int>(tb->retire_valid)
		  << "\n";

      }

      *reinterpret_cast<uint64_t*>(s->cpr1+tb->retire_reg_ptr) = tb->retire_reg_data;
      //std::cerr << std::hex << tb->retire_pc << std::dec << " writing fp reg " << static_cast<int>(tb->retire_reg_ptr)
      //<< std::hex << " with data " << tb->retire_reg_data << std::dec << "\n";
      last_retired_fp_pc = tb->retire_pc;
    }
    
#ifdef BRANCH_DEBUG
    if(tb->branch_pc_valid) {
      ++n_branches;
    }
    if(tb->branch_fault) {
      mispredicts[tb->branch_pc]++; 
    }
    if(tb->branch_fault) {
      ++n_mispredicts;
    }
#endif
    if(tb->store_not_hor) {
      ++stores_not_hor;
    }
    if(tb->in_flush_mode) {
      ++n_flush_cycles;
    }
    
    if(tb->retire_valid) {
      ++insns_retired;
      if(last_retire > 1) {
	pushout_histo[tb->retire_pc]++;
      }
      last_retire = 0;

      bool retired_same_pc = last_retired_pc == tb->retire_pc;

      last_retired_pc = tb->retire_pc;

      //if(insns_retired > 13631488)
      //globals::trace_retirement = true;
      
      if(((insns_retired % heartbeat) == 0) or globals::trace_retirement ) {
	uint32_t r_inst = *reinterpret_cast<uint32_t*>(s->mem[tb->retire_pc]);
	r_inst = bswap<false>(r_inst);	
	std::cout << "retiring "
		  << std::hex
		  << tb->retire_pc
		  << "("
		  << r_inst
		  << ")"
		  << std::dec
		  << " : " << getAsmString(r_inst, tb->retire_pc);
	if(tb->retire_reg_valid) {
	  std::cout << " : "
		    << getGPRName(tb->retire_reg_ptr)
		    << " = "
		    << std::hex
		    << tb->retire_reg_data
		    << std::dec;
	}
	std::cout << " cycle " << globals::cycle
		  << ", " << static_cast<double>(insns_retired) / globals::cycle << " IPC "
		  << ", insns_retired "
		  << insns_retired
		  << ", mispredict rate "
		  << ((static_cast<double>(n_mispredicts)/n_branches)*100.0)
		  << ", mispredict pki "
		  << (static_cast<double>(n_mispredicts) / insns_retired) * 1000.0
		  <<" \n";
      }
      if(tb->retire_two_valid) {
	++insns_retired;
	if(((insns_retired % heartbeat) == 0) or globals::trace_retirement ) {
	  uint32_t r_inst = *reinterpret_cast<uint32_t*>(s->mem[tb->retire_two_pc]);
	  r_inst = bswap<false>(r_inst);	
	  std::cout << "retiring 2nd "
		    << std::hex
		    << tb->retire_two_pc
		    << "("
		    << r_inst
		    << ")"
		    << std::dec
		    << " : " << getAsmString(r_inst, tb->retire_pc)
		    << " cycle " << globals::cycle
		    << ", " << static_cast<double>(insns_retired) / globals::cycle << " IPC "	    
		    << ", insns_retired "
		    << insns_retired
		    << ", n_restarts "
		    << n_mispredicts
		    << ", mispredict pki "
		    << (static_cast<double>(n_mispredicts) / insns_retired) * 1000.0
		    <<" \n";
	}
      }
      assert(!retired_same_pc);
      
      if( enable_checker) {
	//std::cout << std::hex << tb->retire_pc << "," << ss->pc << std::dec << "\n";	  	
	if(tb->retire_pc == ss->pc) {
	  //std::cout << std::hex << tb->retire_pc << "," << ss->pc << std::dec << "\n";	  	
	  execMips(ss);
	  // if(static_cast<uint32_t>(ss->mem.at(0x4cadc)) == 3) {
	  //   std::cout << "changed memory at " << std::hex << ss->pc << std::dec << "\n";
	  //   exit(-1);
	  // }
	  
	  bool diverged = false;
	  if(ss->pc == (tb->retire_pc + 4)) {
	    for(int i = 0; i < 32; i++) {
	      if((ss->gpr[i] != s->gpr[i])) {
		int wrong_bits = __builtin_popcount(ss->gpr[i] ^ s->gpr[i]);
		++mismatches;
		std::cout << "register " << getGPRName(i)
			  << " does not match : rtl "
			  << std::hex
			  << s->gpr[i]
			  << " simulator "
			  << ss->gpr[i]
			  << std::dec
			  << " bits in difference "
			  << wrong_bits
			  << "\n";
		//globals::trace_retirement |= (wrong_bits != 0);
		diverged = true;//(wrong_bits > 16);
	      }
	    }
	    for(int i = 0; i < 32; i+=2) {
	      uint64_t rtl = *reinterpret_cast<uint64_t*>(&s->cpr1[i]);
	      uint64_t sim = *reinterpret_cast<uint64_t*>(&ss->cpr1[i]);
	      if(rtl != sim) {
		diverged = true;
		std::cout << "fp reg " << i <<" : rtl = " << std::hex << rtl << ", sim = " << sim << std::dec << "\n";
	      }
	    }
	    
	  }
	  
	  if(diverged) {
	    uint32_t r_inst = *reinterpret_cast<uint32_t*>(s->mem[tb->retire_pc]);
	    r_inst = bswap<false>(r_inst);
	    std::cout << "incorrect "
		      << std::hex
		      << tb->retire_pc
		      << std::dec
		      << " : " << getAsmString(r_inst, tb->retire_pc)
		      << "\n";
	    for(int i = 0; i < 32; i+=4) {
	      std::cout << "reg "
			<< getGPRName(i)
			<< " = "
			<< std::hex
			<< s->gpr[i]
			<< " reg "
			<< getGPRName(i+1)
			<< " = "
			<< s->gpr[i+1]
			<< " reg "
			<< getGPRName(i+2)
			<< " = "
			<< s->gpr[i+2]
			<< " reg "
			<< getGPRName(i+3)
			<< " = "
			<< s->gpr[i+3]
			<< std::dec <<"\n";
	    }
   
	    break;
	  }


	  
	  ++n_checks;
	  last_check = 0;
	  last_match_pc =  tb->retire_pc; 
	}
	else {
	  ++last_check;
	  if(last_check > 2) {
	    uint32_t linsn = bswap<false>(*reinterpret_cast<uint32_t*>(s->mem[last_match_pc]));
	    std::cerr << "no match in a while, last match : "
		      << std::hex
		      << last_match_pc
		      << " "
		      << getAsmString(linsn, last_match_pc)
		      << ", rtl pc =" << tb->retire_pc
		      << ", sim pc =" << ss->pc
		      << std::dec
		      <<"\n";
	    break;
	  }
	}
      }
      //do       
    }
    
    if(tb->retire_reg_two_valid) {
      s->gpr[tb->retire_reg_two_ptr] = tb->retire_reg_two_data;
      //if(tb->retire_reg_two_ptr == R_a0) {
      //std::cout << std::hex << "insn two with pc " << tb->retire_two_pc << " updates a0 \n"
      //<< std::dec;
      //}
    }

    if(enable_checker && tb->retire_two_valid) {
      if(tb->retire_two_pc == ss->pc) {
	execMips(ss);
	++n_checks;
	last_check = 0;
	last_match_pc =  tb->retire_two_pc; 
      }
    }

    
    ++last_retire;
    // if(last_retire > (100*mem_lat)) {
    //   std::cerr << "no retire in 20 cycle, last retired "
    // 		<< std::hex
    // 		<< last_retired_pc + 0
    // 		<< std::dec
    // 		<< " "
    // 		<< getAsmString(get_insn(last_retired_pc+0, s), last_retired_pc+0)
    // 		<< "\n";

    //   break;
    // }
    if(tb->got_break) {
      break;
    }
#ifndef LINUX_SYSCALL_EMULATION    
    if(tb->got_syscall) {
      std::cerr << "GOT SYSCALL\n";
      break;
    }
#endif
    if(tb->got_ud) {
      std::cerr << "GOT UD for "
		<< std::hex
		<< tb->retire_pc
		<< std::dec
		<< " "
		<< getAsmString(get_insn(tb->retire_pc, s), tb->retire_pc)
		<< "\n";
      break;
    }
    inflight[tb->inflight & 31]++;
    max_inflight = std::max(max_inflight, static_cast<uint32_t>(tb->inflight));

    if(tb->iside_tlb_miss)
      ++n_iside_tlb_misses;
    if(tb->dside_tlb_miss)
      ++n_dside_tlb_misses;      
    //negedge
    tb->mem_rsp_valid = 0;

    if(tb->mem_req_valid && (mem_reply_cycle == -1)) {

      mem_reply_cycle = globals::cycle + (tb->mem_req_insn ? 0 : mem_lat);
      
    }
    
    if(/*tb->mem_req_valid*/mem_reply_cycle ==globals::cycle) {
      //std::cout << "got memory request for address "
      //<< std::hex << tb->mem_req_addr << std::dec <<"\n";
      last_retire = 0;
      mem_reply_cycle = -1;
      assert(tb->mem_req_valid);
      
      if(tb->mem_req_opcode == 4) {/*load word */
	for(int i = 0; i < 4; i++) {
	  tb->mem_rsp_load_data[i] = *reinterpret_cast<uint32_t*>(s->mem[tb->mem_req_addr + 4*i]);
	}
	last_load_addr = tb->mem_req_addr;
	assert((tb->mem_req_addr & 0xf) == 0);
	touched_lines[(tb->mem_req_addr & ((1UL<<32) - 1))>>4] = 1;
	++n_loads;
      }
      else if(tb->mem_req_opcode == 7) { /* store word */
	for(int i = 0; i < 4; i++) {
	  *reinterpret_cast<uint32_t*>(s->mem[tb->mem_req_addr + 4*i]) = tb->mem_req_store_data[i];
	}
	last_store_addr = tb->mem_req_addr;
	++n_stores;
      }
      last_addr = tb->mem_req_addr;
      tb->mem_rsp_valid = 1;
    }

    
    tb->clk = 0;
    tb->eval();
    if(got_mem_req) {
      tb->mem_req_ack = 0;
      got_mem_req = false;
    }
    if(got_mem_rsp) {
      tb->mem_rsp_valid = 0;
      got_mem_rsp = false;
    }
    
    if(got_monitor) {
      tb->monitor_rsp_valid = 0;
      tb->monitor_rsp_data_valid = 0;
      tb->monitor_rsp_data = 0;
      got_monitor = false;
    }
    ++globals::cycle;
  }
  tb->final();
  t0 = timestamp() - t0;
  
  
  std::cout << "n_mispredicts = " << n_mispredicts
	    <<  ", cycles = " << globals::cycle
	    << ", insns = " << insns_retired
	    << ", n_checks = " << n_checks
	    << "\n";
  std::cout << static_cast<double>(insns_retired) / globals::cycle << " insn per cycle\n";
  double avg_inflight = 0, sum = 0;
  for(int i = 0; i < 32; i++) {
    if(inflight[i] == 0) continue;
    avg_inflight += i * inflight[i];
    sum += inflight[i];
    //printf("inflight[%d] = %lu\n", i, inflight[i]);
  }
  avg_inflight /= sum;
  std::cout << insns_retired << " insns retired\n";

  
  std::cout << "avg insns in ROB = " << avg_inflight
	    << ", max inflight = " << max_inflight << "\n";
  
#ifdef CACHE_STATS
  std::cout << "l1d cache hits = " << tb->l1d_cache_hits << "\n";
  std::cout << "l1d cache accesses = " << tb->l1d_cache_accesses << "\n";
  std::cout << "l1d cache hit under miss = " << tb->l1d_cache_hits_under_miss << "\n";
  std::cout << "l1d hit rate = "
	    << 100.0 *(static_cast<double>(tb->l1d_cache_hits) / tb->l1d_cache_accesses)
	    << "\n";
  std::cout << "l1i cache hits = " << tb->l1i_cache_hits << "\n";
  std::cout << "l1i cache accesses = " << tb->l1i_cache_accesses << "\n";
  std::cout << "l1i hit rate = "
	    << 100.0 *(static_cast<double>(tb->l1i_cache_hits) / tb->l1i_cache_accesses)
	    << "\n";
#endif
  std::cout << "iside tlb misses = " << n_iside_tlb_misses << "\n";
  std::cout << "dside tlb misses = " << n_dside_tlb_misses << "\n";

  std::cout << "branch mispredict rate = "
	    << (static_cast<double>(n_mispredicts)/n_branches)*100.0
	    << "\n";

  std::cout << "mispredicts per kiloinsn = "
	    << (static_cast<double>(n_mispredicts) / insns_retired) * 1000.0
	    << "\n";
  std::cout << n_flush_cycles << " cycles spent flushing caches\n";
  std::cout << n_loads << " cache line loads\n";
  std::cout << n_stores << " cache line stores\n";
  std::cout << l1d_misses << " l1d misses\n";
  std::cout << l1d_insns << " insns access the l1d\n";

  uint64_t total_fetch = 0, total_fetch_cycles = 0;
  for(int i = 0; i < 5; i++) {
    std::cout << "n_fetch[" << i << "] = " << n_fetch[i] << "\n";
    total_fetch_cycles += n_fetch[i];
    total_fetch += n_fetch[i] * i;
  }
  std::cout << "avg fetch = " << static_cast<double>(total_fetch) / total_fetch_cycles << "\n";
  
  for(int i = 0; i < 3; i++) {
    std::cout << "uq_full[" << i << "] = " << n_uq_full[i] << "\n";
  }

  for(int i = 0; i < 3; i++) {
    std::cout << "insn ready " << i
	      << " "
	      << n_rdy[i] << "\n";
  }
  
  dump_histo("branch_info.txt", mispredicts, s);
  dump_histo("pushout.txt", pushout_histo, s);

  std::ofstream branch_info("retire_info.csv");
  uint64_t total_retire = 0, total_cycle = 0;
  for(auto &p : retire_map) {
    total_retire += p.second;
  }
  for(auto &p : retire_map) {
    branch_info << p.first << "," << p.second << "," << static_cast<double>(p.second) / total_retire << "\n";
    total_cycle += (p.first * p.second);
  }
  branch_info.close();
  std::cout << "total_retire = " << total_retire << "\n";
  std::cout << "total_cycle  = " << total_cycle << "\n";
  std::cout << "total ipc    = " << static_cast<double>(total_retire) / total_cycle << "\n";

  std::cout << "simulation took " << t0 << " seconds, " << (insns_retired/t0) << " insns per second\n";
  delete s;
  delete ss;
  delete [] insns_delivered;
  if(pl) {
    delete pl;
  }
  //delete tb;
  stopCapstone();
  exit(EXIT_SUCCESS);
}

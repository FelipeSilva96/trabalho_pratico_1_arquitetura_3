#include "Vcache_def.h"
#include "Vdm_cache_data.h"
#include "Vdm_cache_fsm.h"
#include "Vdm_cache_tag.h"
#include "Vtb_dm_cache.h"
#include "verilated.h"

int main(int argc, char** argv) {
  VerilatedContext* contextp = new VerilatedContext;
  contextp->commandArgs(argc, argv);
  Vtb_dm_cache* top = new Vtb_dm_cache{contextp};
  while (!contextp->gotFinish()) {
    top->eval();
    contextp->timeInc(1);
  }
  delete top;
  delete contextp;
  return 0;
}
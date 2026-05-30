#include "Vcache_def.h"
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
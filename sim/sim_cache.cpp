#include "Vtb_dm_cache.h"   // Apenas o header do Top Module é necessário
#include "verilated.h"
#include "verilated_vcd_c.h" // Biblioteca para gerar os waveforms (.vcd)

int main(int argc, char** argv) {
    // Inicializa o contexto do Verilator
    VerilatedContext* contextp = new VerilatedContext;
    contextp->commandArgs(argc, argv);
    
    // Habilita a gravação de trace no C++
    Verilated::traceEverOn(true);
    
    // Instancia o Top Module
    Vtb_dm_cache* top = new Vtb_dm_cache{contextp};
    
    // Configura o dumper do VCD
    VerilatedVcdC* tfp = new VerilatedVcdC;
    top->trace(tfp, 99);  // Nível de profundidade do trace
    tfp->open("sim/wave.vcd"); // Nome do arquivo de saída
    
    // Loop principal da simulação
    while (!contextp->gotFinish() && contextp->time() < 500000000) { // Adicionado um limite de tempo seguro
        top->eval();
        tfp->dump(contextp->time()); // Grava os sinais no tempo atual
        contextp->timeInc(1);        // Avança 1 tick
    }
    
    // Finalização e limpeza da memória
    top->final();
    tfp->close();
    delete tfp;
    delete top;
    delete contextp;
    
    return 0;
}
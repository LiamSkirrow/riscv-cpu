#include <stdlib.h>
#include <iostream>
#include <verilated.h>
#include <verilated_fst_c.h>
#include "../obj_dir/VTop_CPU.h"
#include "../obj_dir/VTop_CPU___024root.h"
#include "../obj_dir/VTop_CPU__Syms.h"

#define MAX_SIM_TIME 20
vluint64_t sim_time = 0;

int main(int argc, char** argv, char** env) {
    VTop_CPU *dut = new VTop_CPU;

    Verilated::traceEverOn(true);
    VerilatedFstC *m_trace = new VerilatedFstC;
    dut->trace(m_trace, 5);
    m_trace->open("Top_CPU_waves.fst");

    while (sim_time < MAX_SIM_TIME) {
        dut->CK_REF ^= 1;
        dut->eval();
        m_trace->dump(sim_time);
        sim_time++;
    }

    m_trace->close();
    delete dut;
    exit(EXIT_SUCCESS);
}

#include <stdlib.h>
#include <iostream>
#include <verilated.h>
#include <verilated_fst_c.h>
#include "../obj_dir/Vinstructiondecoder.h"
#include "../obj_dir/Vinstructiondecoder___024root.h"
#include "../obj_dir/Vinstructiondecoder__Syms.h"

#define MAX_SIM_TIME 20
vluint64_t sim_time = 0;

int main(int argc, char** argv, char** env) {
    Vinstructiondecoder *dut = new Vinstructiondecoder;

    Verilated::traceEverOn(true);
    VerilatedFstC *m_trace = new VerilatedFstC;
    dut->trace(m_trace, 5);
    m_trace->open("instructiondecoder_waves.fst");

    while (sim_time < MAX_SIM_TIME) {
        // release dut out of reset
        // dut->CK_REF ^= 1;
        dut->eval();

        m_trace->dump(sim_time);
        sim_time++;
    }

    m_trace->close();
    delete dut;
    exit(EXIT_SUCCESS);
}

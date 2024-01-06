#include <stdlib.h>
#include <iostream>
#include <verilated.h>
#include <verilated_fst_c.h>
#include "../obj_dir/Valu.h"
#include "../obj_dir/Valu___024root.h"
#include "../obj_dir/Valu__Syms.h"

#define MAX_SIM_TIME 20
vluint64_t sim_time = 0;

int main(int argc, char** argv, char** env) {
    Valu *dut = new Valu;

    Verilated::traceEverOn(true);
    VerilatedFstC *m_trace = new VerilatedFstC;
    dut->trace(m_trace, 5);
    m_trace->open("alu_waves.fst");

    while (sim_time < MAX_SIM_TIME) {

        if(sim_time == 0 && dut->CK_REF == 0)
            dut->RST_N = 0;
        else{
            dut->RST_N = 1;
            dut->OP_VAL = 1;
            dut->A = 5;
            dut->B = 7;
            dut->ALU_EN = 1;
        }
        
        if(sim_time == 2 && dut->CK_REF == 0){
            // addition of 5 and 7
            dut->OP_VAL = 1;
            dut->A = 5;
            dut->B = 7;
            dut->ALU_EN = 1;
        }

        dut->CK_REF ^= 1;
        dut->eval();
        m_trace->dump(sim_time);
        sim_time++;
    }

    m_trace->close();
    delete dut;
    exit(EXIT_SUCCESS);
}

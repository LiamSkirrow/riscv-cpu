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

        if(sim_time == 0 && dut->clk == 0)
            dut->rst_n = 0;
        else{
            dut->rst_n = 1;
            dut->op_val = 1;
            dut->operand_a = 5;
            dut->operand_b = 7;
        }
        
        if(sim_time == 2 && dut->clk == 0){
            // addition of 5 and 7
            dut->op_val = 1;
            dut->operand_a = 5;
            dut->operand_b = 7;
        }

        dut->clk ^= 1;
        dut->eval();
        m_trace->dump(sim_time);
        sim_time++;
    }

    m_trace->close();
    delete dut;
    exit(EXIT_SUCCESS);
}

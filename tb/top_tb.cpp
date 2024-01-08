#include <stdlib.h>
#include <iostream>
#include <verilated.h>
#include <verilated_fst_c.h>
#include "../obj_dir/Vtop.h"
#include "../obj_dir/Vtop___024root.h"
#include "../obj_dir/Vtop__Syms.h"

#define MAX_SIM_TIME 20
vluint64_t sim_time = 0;

int main(int argc, char** argv, char** env) {
    Vtop *dut = new Vtop;

    Verilated::traceEverOn(true);
    VerilatedFstC *m_trace = new VerilatedFstC;
    dut->trace(m_trace, 5);
    m_trace->open("top_waves.fst");

    int check = 0;

    while (sim_time < MAX_SIM_TIME) {
        
        // release dut out of reset
        if(sim_time == 0 && dut->CK_REF == 0){
            dut->RST_N = 0;
        } else{
            dut->RST_N = 1;
            dut->MEM_ACCESS_DATA_IN_BUS = 0xCAFEBEED;
        }

        // first lb instruction down below
        dut->INST_MEM_DATA_BUS = 0b00000000000000000010000010000011;

        if(dut->MEM_ACCESS_READ_WRN){
            check = 1;
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

/*
    // lb
    assign instruction_memory[0]  = 32'b000000000000_00000_010_00001_0000011;

    assign instruction_memory[1]  = 32'b000000000000_00000_000_00000_0000000;
    assign instruction_memory[2]  = 32'b000000000000_00000_000_00000_0000000;
    assign instruction_memory[3]  = 32'b000000000000_00000_000_00000_0000000;
    // sb
    assign instruction_memory[4]  = 32'b0000000_00001_00000_010_00001_0100011;
    assign instruction_memory[5]  = 32'b000000000000_00000_000_00000_0000000;
    assign instruction_memory[6]  = 32'b000000000000_00000_000_00000_0000000;
    assign instruction_memory[7]  = 32'b000000000000_00000_000_00000_0000000;
    // lb
    assign instruction_memory[8]  = 32'b000000000000_00000_010_00010_0000011;   
    assign instruction_memory[9]  = 32'b000000000000_00000_000_00000_0000000;
    assign instruction_memory[10] = 32'b000000000000_00000_000_00000_0000000;
    assign instruction_memory[11] = 32'b000000000000_00000_000_00000_0000000;
    // sb
    assign instruction_memory[12] = 32'b0000000_00010_00000_010_00010_0100011;
    assign instruction_memory[13] = 32'b000000000000_00000_000_00000_0000000;
    assign instruction_memory[14] = 32'b000000000000_00000_000_00000_0000000;
    assign instruction_memory[15] = 32'b000000000000_00000_000_00000_0000000;
    assign instruction_memory[16] = 32'b000000000000_00000_000_00000_0000000;
    assign instruction_memory[17] = 32'b000000000000_00000_000_00000_0000000;
    assign instruction_memory[18] = 32'b000000000000_00000_000_00000_0000000;
    assign instruction_memory[19] = 32'b000000000000_00000_000_00000_0000000;
    assign instruction_memory[20] = 32'b000000000000_00000_000_00000_0000000;
*/
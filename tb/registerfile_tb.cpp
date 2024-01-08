#include <stdlib.h>
#include <iostream>
#include <verilated.h>
#include <verilated_fst_c.h>
#include "../obj_dir/Vregisterfile.h"
#include "../obj_dir/Vregisterfile___024root.h"
#include "../obj_dir/Vregisterfile__Syms.h"

#define MAX_SIM_TIME 20
vluint64_t sim_time = 0;

int main(int argc, char** argv, char** env) {
    Vregisterfile *dut = new Vregisterfile;

    Verilated::traceEverOn(true);
    VerilatedFstC *m_trace = new VerilatedFstC;
    dut->trace(m_trace, 5);
    m_trace->open("registerfile_waves.fst");

    while (sim_time < MAX_SIM_TIME) {
        // release dut out of reset
        if(sim_time == 0 && dut->CK_REF == 0){
            dut->RST_N = 0;
        } else{
            dut->RST_N = 1;
            dut->REG_DATA_IN = 0xDEADBEEF;
            // dut->RD_REG_OFFSET = 0x01;
        }

        dut->CK_REF ^= 1;
        dut->eval();
        
        if(sim_time == 1 && dut->CK_REF == 0){
            dut->REG_DATA_IN = 0xDEADBEEF;
            dut->RD_REG_OFFSET = 0x01;
        } 
        if(sim_time == 2 && dut->CK_REF == 0){
            dut->REG_DATA_IN = 0xDEADBEEF;
            dut->RD_REG_OFFSET = 0x02;
        }
        if(sim_time == 3 && dut->CK_REF == 0){
            dut->REG_DATA_IN = 0xDEADBEEF;
            dut->RD_REG_OFFSET = 0x03;
        }
        if(sim_time == 4 && dut->CK_REF == 0){
            dut->REG_DATA_IN = 0xDEADBEEF;
            dut->RD_REG_OFFSET = 0x04;
        }
        if(sim_time == 5 && dut->CK_REF == 0){
            dut->REG_DATA_IN = 0xDEADBEEF;
            dut->RD_REG_OFFSET = 0x05;
        }
        if(sim_time == 6 && dut->CK_REF == 0){
            dut->REG_DATA_IN = 0xDEADBEEF;
            dut->RD_REG_OFFSET = 0x06;
        }

        m_trace->dump(sim_time);
        sim_time++;
    }

    m_trace->close();
    delete dut;
    exit(EXIT_SUCCESS);
}

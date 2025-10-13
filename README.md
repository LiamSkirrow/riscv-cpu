# riscv-cpu
A 5-stage pipelined CPU implemented in Verilog.

## Compiling and Simulating
The intention is to compile and simulate the Verilog using Verilator.
- The plan is to have one Makefile that can be used to compile and/or simulate individual blocks or the entire design. For example, going `make alu` should compile the _alu.v_ file along with the ALU C++ testbench.
- Similarly, going `make` should compile the whole project from the top level (equivalent to running `make top`).
- Can dump waveform output when setting `WAVES=1` for any module in the design. The waveform dump is of FST format.

- NOTE: running GTKWave on WSL
  - cmd$> xming
  - cmd$> export DISPLAY=:0

## TODO:
- Self-checking autotests? Should be invoked from the Makefile
- include draw.io diagram in the README, showing the structure of the CPU including the actual RTL signal names
- include a parameterisable branch prediction unit, implementing some simplistic branch prediction techniques
    - implement some hint instructions to indicate to the CPU whether a branch will be taken or not in the actual ASM.

## Dev Plan
- Complete enough of the ISA and test with some programs, run the CPU through and make sure the pipeline is at least minimally functional. This step should be done using register files as both imem and dmem
- Implement a cache controller that does all the DMA on behalf of the CPU, and thus reduces the overall number of stalled clock cycles dramatically. 

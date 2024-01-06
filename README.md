# riscv-cpu
A 5-stage pipelined CPU implemented in Verilog.

## Compiling and Simulating
The intention is to compile and simulate the Verilog using Verilator. The plan is to:
- The plan is to have one Makefile that can be used to compile and/or simulate individual blocks or the entire design. For example, going `make alu` should compile the _alu.v_ file along with the ALU C++ testbench, or for example going `make alu SIM=1` should do both the compilation *and* simulation.
- Similarly, going `make all` should compile the whole project from the top level, setting `SIM=1` should have the same expected behaviour.
- Waveform dump output when setting `SIM=1` should be of FST format for use with GTKWave.

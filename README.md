# riscv-cpu
A 5-stage pipelined CPU implemented in Verilog.

## Compiling and Simulating
The intention is to compile and simulate the Verilog using Verilator.
- The plan is to have one Makefile that can be used to compile and/or simulate individual blocks or the entire design. For example, going `make alu` should compile the _alu.v_ file along with the ALU C++ testbench.
- Similarly, going `make` should compile the whole project from the top level (equivalent to running `make top`).
- Can dump waveform output when setting `WAVES=1` for any module in the design. The waveform dump is of FST format.

## TODO:
- Self-checking autotests? Should be invoked from the Makefile.
- CocoTB investigation to make the testbenches a little better? This is an enhancement and not strictly required but might be good to look into.

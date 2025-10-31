# riscv-cpu
A 5-stage pipelined CPU implemented in Verilog.

## Compiling and Simulating
Note that only block-level tests are really supported in this repo, the top-level tests that run instructions through this CPU are run my [cpu debug environment project](https://github.com/LiamSkirrow/cpu-run-env), using this CPU as the default processor.
The intention is to compile and simulate the Verilog using Verilator.
- The plan is to have one Makefile that can be used to compile and/or simulate individual blocks or the entire design. For example, going `make alu` should compile the _alu.v_ file along with the ALU C++ testbench.
- Similarly, going `make` should compile the whole project from the top level (equivalent to running `make top`).
- Can dump waveform output when setting `WAVES=1` for any module in the design. The waveform dump is of FST format.

- NOTE: running GTKWave on WSL
  - cmd$> xming (open in windows start menu)
  - cmd$> export DISPLAY=:0

## TODO:
- include draw.io diagram in the README, showing the structure of the CPU including the actual RTL signal names
- include a parameterisable branch prediction unit, implementing some simplistic branch prediction techniques
    - implement some hint instructions to configure feature-set of CPU at runtime

# riscv-cpu
A purely Verilog implementation of the RV32I instruction set

### TODO:
- Figure out verilator. It'd be useful to set this up so I can syntax check the Verilog without needing Xcelium
- Get code compiling and a basic proof-of-simulation in Xcelium
- Consider setting up a basic synthesis flow using Yosys, just to see the level of optimisation that's done... ie how many gates are actually getting optimised away. Would probably need to setup an example PDK (Skywater130nm/GF180nm) and just parse the netlists as sanity checks. This would also indicate how optimal the RTL is in terms of flop count (which atm I think is pretty bad with all the pipelining registers I've inferred...)
  - Consider setting up a new repo focusing on synthesising this repo, with 'riscv-cpu' hooked up as a submodule.

### Bugs:
- Currently, the Vivado synthesis tool does away with basically the entire design, may need to pass the data/address buses out of the top-level and into some makeshift RAM+ROM modules at the top level, rather than including the RAM+ROM at the Top_Cpu.v level.

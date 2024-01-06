# main project Makefile, run compilation/simulation of entire design or individual submodules from here

# TODO: maybe run verilogtree at the end just for fun lol
#       would have to first check that it's installed on the system

SRC=src/
TB=tb/
CC=verilator

alu_syntax:
	@echo ">>> Compiling module: alu"
	@echo
	$(CC) -Wno-fatal --cc $(SRC)alu.v --lint-only
	@echo "DONE"

alu:
	@echo ">>> Verilating alu..."
	@echo
	$(CC) -Wno-fatal --trace-fst --cc $(SRC)$@.v --exe $(TB)$@_tb.cpp
	make -C obj_dir -f V$@.mk V$@
ifeq ($(SIM),1)
	@echo ">>> Simulating alu..."
	@echo
	./obj_dir/V$@
endif
	@echo "DONE"

.PHONY: clean
clean:
	rm -rf obj_dir/ *.fst

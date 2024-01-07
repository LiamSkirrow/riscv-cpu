# main project Makefile, run compilation/simulation of entire design or individual submodules from here

# TODO: maybe run verilogtree at the end just for fun lol
#       would have to first check that it's installed on the system

SRC=src/
TB=tb/
CONF=config-files/
CC=verilator

top:
ifeq ($(SYNTAX), 1)
	@echo ">>> Syntax checking module: Top"
	@echo
	$(CC) -Wno-fatal --cc $(SRC)top.v $(SRC)alu.v $(SRC)registerfile.v --lint-only
else
ifeq ($(WAVES), 1)
	gtkwave top_waves.fst -a $(CONF)top.gtkw
else
	@echo ">>> Verilating Top..."
	@echo
	$(CC) -Wno-fatal --trace-fst --cc $(SRC)top.v $(SRC)alu.v $(SRC)registerfile.v --exe $(TB)$@_tb.cpp
	make -C obj_dir -f Vtop.mk Vtop
	@echo ">>> Simulating Top..."
	@echo
	./obj_dir/Vtop
endif
endif
	@echo "DONE"

alu:
ifeq ($(SYNTAX), 1)
	@echo ">>> Syntax checking module: ALU"
	@echo
	$(CC) -Wno-fatal --cc $(SRC)alu.v --lint-only
else
ifeq ($(WAVES), 1)
	gtkwave alu_waves.fst -a $(CONF)alu.gtkw
else
	@echo ">>> Verilating ALU..."
	@echo
	$(CC) -Wno-fatal --trace-fst --cc $(SRC)alu.v --exe $(TB)alu_tb.cpp
	make -C obj_dir -f Valu.mk Valu
	@echo ">>> Simulating ALU..."
	@echo
	./obj_dir/Valu
endif
endif
	@echo "DONE"


registerfile:
ifeq ($(SYNTAX), 1)
	@echo ">>> Syntax checking module: RegisterFile"
	@echo
	$(CC) -Wno-fatal --cc $(SRC)registerfile.v --lint-only
else
ifeq ($(WAVES), 1)
	gtkwave $@_waves.fst -a $(CONF)$@.gtkw
else
	@echo ">>> Verilating RegisterFile..."
	@echo
	$(CC) -Wno-fatal --trace-fst --cc $(SRC)registerfile.v --exe $(TB)registerfile_tb.cpp
	make -C obj_dir -f Vregisterfile.mk Vregisterfile
	@echo ">>> Simulating RegisterFile..."
	@echo
	./obj_dir/Vregisterfile
endif
endif
	@echo "DONE"


# run a sequence of self-checking autotests
test:


.PHONY: clean
clean:
	rm -rf obj_dir/ *.fst

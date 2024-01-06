# main project Makefile, run compilation/simulation of entire design or individual submodules from here

# TODO: maybe run verilogtree at the end just for fun lol
#       would have to first check that it's installed on the system

SRC=src/
TB=tb/
CONF=config-files/
CC=verilator

top:
ifeq ($(SYNTAX), 1)
	@echo ">>> Syntax checking module: top"
	@echo
	$(CC) -Wno-fatal --cc $(SRC)top.v $(SRC)alu.v $(SRC)Register_File.v --lint-only
else
ifeq ($(WAVES), 1)
	gtkwave $@_waves.fst -a $(CONF)$@.gtkw
else
	@echo ">>> Verilating top..."
	@echo
	$(CC) -Wno-fatal --trace-fst --cc $(SRC)top.v $(SRC)alu.v $(SRC)Register_File.v --exe $(TB)$@_tb.cpp
	make -C obj_dir -f V$@.mk V$@
	@echo ">>> Simulating top..."
	@echo
	./obj_dir/V$@
endif
endif
	@echo "DONE"

alu:
ifeq ($(SYNTAX), 1)
	@echo ">>> Syntax checking module: alu"
	@echo
	$(CC) -Wno-fatal --cc $(SRC)alu.v --lint-only
else
ifeq ($(WAVES), 1)
	gtkwave $@_waves.fst -a $(CONF)$@.gtkw
else
	@echo ">>> Verilating alu..."
	@echo
	$(CC) -Wno-fatal --trace-fst --cc $(SRC)$@.v --exe $(TB)$@_tb.cpp
	make -C obj_dir -f V$@.mk V$@
	@echo ">>> Simulating alu..."
	@echo
	./obj_dir/V$@
endif
endif
	@echo "DONE"


Register_File:
ifeq ($(SYNTAX), 1)
	@echo ">>> Syntax checking module: Register_File"
	@echo
	$(CC) -Wno-fatal --cc $(SRC)Register_File.v --lint-only
else
ifeq ($(WAVES), 1)
	gtkwave $@_waves.fst -a $(CONF)$@.gtkw
else
	@echo ">>> Verilating Register_File..."
	@echo
	$(CC) -Wno-fatal --trace-fst --cc $(SRC)$@.v --exe $(TB)$@_tb.cpp
	make -C obj_dir -f V$@.mk V$@
	@echo ">>> Simulating Register_File..."
	@echo
	./obj_dir/V$@
endif
endif
	@echo "DONE"


# run a sequence of self-checking autotests
test:


.PHONY: clean
clean:
	rm -rf obj_dir/ *.fst

`timescale 1ns / 1ps

/* Build time parameters */

// TODO: currently only supports operand forwarding, must not disable for now
// if not defined, then cause pipeline stalls (slow but might be easier for synthesis due to shorter combinational paths)
`define OPERAND_FORWARDING

// enable  dynamic branch prediction and branch target prediction... comment out for default static branch 
// prediction, where the CPU assumes all branches are *never* taken
// `define DYNAMIC_BRANCH_PREDICTION


/* Design parameters */

// Register File 
`define REG_FILE_PC_OFFSET 5'd32;

// ALU operations
`define ALU_NOP_OP  4'b0000
`define ALU_ADD_OP  4'b0001
`define ALU_SUB_OP  4'b0010
`define ALU_SLT_OP  4'b0011
`define ALU_SLTU_OP 4'b1011
`define ALU_AND_OP  4'b0100
`define ALU_OR_OP   4'b0101
`define ALU_XOR_OP  4'b0110
`define ALU_SLL_OP  4'b0111
`define ALU_SRL_OP  4'b1000
`define ALU_SRA_OP  4'b1001

// Register write-back data types (data size, data signedness)
`define REG_WB_WORD           3'b000
`define REG_WB_HALF_UNSIGNED  3'b001
`define REG_WB_HALF_SIGNED    3'b010
`define REG_WB_BYTE_UNSIGNED  3'b011
`define REG_WB_BYTE_SIGNED    3'b100

// Memory access operations
`define MEM_ADDRESS_WIDTH 4'd16
`define MEM_LOAD  2'b00
`define MEM_STORE 2'b01
`define MEM_NOP   2'b10

`timescale 1ns / 1ps

// *** NOTES
// - pretty sure riscv is little endian? Needs clarification...
// - should memory be byte addressable rather than word (32 bit) addressable?
// ***

// ***** Pipeline hazard notes
// - when implementing pipeline hazard detection, do some research on operand forwarding...
// - need to gate the IR to all zeros, to force the instruction decoder to insert bubbles into the pipeline for x many cycles
// - also need to pause the program counter so that it doesn't count past the next instructions

// Top Level CPU
//  - instantiate the register files to serve as code memory and general purpose memory repsectively
//  - hook up the register files to the CPU control unit
//  - (optional) include a clock divider circuit to divide down the system clock to feed into the CPU itself 
//    so the behaviour of the CPU is clearly observable on the FPGA


module Top_CPU(
    input wire CK_REF,
    input wire RST_N,

    output MEM_ACCESS_READ_WRN,
    output MEM_ACCESS_ADDRESS_BUS,
    output MEM_ACCESS_DATA_OUT_BUS
    );
    
    // local signals
    integer i;
    wire [31:0] instruction_memory [20:0];
    reg  [31:0] memory [4:0];
    wire [31:0] inst_mem_data_bus, inst_mem_address_bus, mem_access_data_out_bus;
    reg  [31:0] mem_access_data_in_bus;
    wire [15:0] mem_access_address_bus;
    wire mem_access_read_wrn;
   
    // F D E Me Wb

    // lb
    assign instruction_memory[0]  = 32'b000000000000_00000_010_00001_0000011;

    assign instruction_memory[1]  = 32'b000000000000_00000_000_00000_0000000;
    assign instruction_memory[2]  = 32'b000000000000_00000_000_00000_0000000;
    assign instruction_memory[3]  = 32'b000000000000_00000_000_00000_0000000;
    // sb
    assign instruction_memory[4]  = 32'b0000000_00001_00000_010_00001_0100011;
    assign instruction_memory[5]  = 32'b000000000000_00000_000_00000_0000000;
    assign instruction_memory[6]  = 32'b000000000000_00000_000_00000_0000000;
    assign instruction_memory[7]  = 32'b000000000000_00000_000_00000_0000000;
    // lb
    assign instruction_memory[8]  = 32'b000000000000_00000_010_00010_0000011;   
    assign instruction_memory[9]  = 32'b000000000000_00000_000_00000_0000000;
    assign instruction_memory[10] = 32'b000000000000_00000_000_00000_0000000;
    assign instruction_memory[11] = 32'b000000000000_00000_000_00000_0000000;
    // sb
    assign instruction_memory[12] = 32'b0000000_00010_00000_010_00010_0100011;
    assign instruction_memory[13] = 32'b000000000000_00000_000_00000_0000000;
    assign instruction_memory[14] = 32'b000000000000_00000_000_00000_0000000;
    assign instruction_memory[15] = 32'b000000000000_00000_000_00000_0000000;
    assign instruction_memory[16] = 32'b000000000000_00000_000_00000_0000000;
    assign instruction_memory[17] = 32'b000000000000_00000_000_00000_0000000;
    assign instruction_memory[18] = 32'b000000000000_00000_000_00000_0000000;
    assign instruction_memory[19] = 32'b000000000000_00000_000_00000_0000000;
    assign instruction_memory[20] = 32'b000000000000_00000_000_00000_0000000;


    
    // instantiate sub-modules
    Control_Unit inst_cont_unit (
        .CK_REF(CK_REF), .RST_N(RST_N), .INST_MEM_DATA_BUS(inst_mem_data_bus), .MEM_ACCESS_DATA_IN_BUS(mem_access_data_in_bus), 
        .INST_MEM_ADDRESS_BUS(inst_mem_address_bus), .MEM_ACCESS_READ_WRN(mem_access_read_wrn), .MEM_ACCESS_ADDRESS_BUS(mem_access_address_bus),
        .MEM_ACCESS_DATA_OUT_BUS(mem_access_data_out_bus)
    );

    // code memory read procedure
    assign inst_mem_data_bus = instruction_memory[inst_mem_address_bus];


    // general purpose memory
    // *** READ
    always @(*) begin
        if(mem_access_read_wrn) begin
            //access the register at the address offset
            mem_access_data_in_bus <= memory[mem_access_address_bus];
        end
        else begin
            mem_access_data_in_bus = 32'd0;
        end
    end

    // *** WRITE
    always @(posedge CK_REF, negedge RST_N) begin
        if(!RST_N) begin
            // reset all registers to zero, for loop gets unrolled during synthesis
            for (i = 0; i < 5; i=i+1) begin
                memory[i] = (i == 0) ? 32'hBEEF_8080 : 32'd0;
                // memory[i] = 32'd0;
            end
        end
        else begin
            if(!mem_access_read_wrn) begin
                memory[mem_access_address_bus] = mem_access_data_out_bus;
            end
        end
    end


    // these assigns are here so that the Xilinx PnR tool doesn't optimise away the whole design...
    assign MEM_ACCESS_READ_WRN = mem_access_read_wrn;    
    assign MEM_ACCESS_ADDRESS_BUS = mem_access_address_bus;
    assign MEM_ACCESS_DATA_OUT_BUS = mem_access_data_out_bus;

endmodule 
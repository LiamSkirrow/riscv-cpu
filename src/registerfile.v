`timescale 1ns / 1ps

// REGISTER FILE:
//  create the 31 32-bit general purpose registers (x1-x31) and 32 bit zero register (x0). 
//  Setup procedures for reads and writes to general purpose registers (x1-x31)
//  declare the program counter register (???)


module RegisterFile(
    input wire CK_REF,
    input wire RST_N,
    input wire REG_RD_WRN,      // register read (HIGH) or write (LOW) mode
    //input wire [31:0] reg_pc,   // *** possibly instantiate program counter from within this module?
    input wire [4:0] RS1_REG_OFFSET,   // register address offset for the rs1 source register for the next instruction
    input wire [4:0] RS2_REG_OFFSET,   // register address offset for the rs2 source register for the next instruction
    input wire [4:0] RD_REG_OFFSET,    // register address offset for the rd destination register for the next instruction
    input wire [31:0] REG_DATA_IN,     // input 32 bit word to write to the register at address rd_reg_offset
    
    output wire [31:0] RS1_DATA_OUT,
    output wire [31:0] RS2_DATA_OUT,
    output wire [31:0] PC_DATA_OUT
    );
    
    // local signals
    // TODO: whats the deal with 33 registers? The 33rd can't be reached since RD_REG_OFFSET is only 5 bits
    reg [31:0] register_file [32:0];
    wire [31:0] rs1_data_out, rs2_data_out, pc_data_out;
    integer i;
    
    //***********************
    //Register Read Procedure
    //***********************
    // always @(*) begin
    //     if(REG_RD_WRN) begin
    //         //access the register at the address offset
    //         rs1_data_out <= register_file[RS1_REG_OFFSET];
    //         rs2_data_out <= register_file[RS2_REG_OFFSET];
    //     end
    //     else begin
    //         rs1_data_out = 32'b0;
    //         rs2_data_out = 32'b0;
    //     end
    // end
    
    // access the register at the address offset, register file can be read ALWAYS
    assign rs1_data_out = register_file[RS1_REG_OFFSET];
    assign rs2_data_out = register_file[RS2_REG_OFFSET];
    assign pc_data_out  = register_file[32];
    
    //************************
    //Register Write Procedure
    //************************
    always @(posedge CK_REF, negedge RST_N) begin
        if(!RST_N) begin
            // reset all registers to zero, for loop gets unrolled during synthesis
            for (i = 0; i < 33; i=i+1) begin
                register_file[i] = 32'd0;
            end
        end
        else begin
            // TODO: should probably be counting up by 4 each time, parameterise the increment value
            //       alternatively maybe make the control unit feed in a signal that says it's ok
            //       to increment, like in the commented out conditional below
            //if(increment_ok) begin
            register_file[32] = register_file[32] + 32'd1;
            //end

            //only write to a register in the range of x1-x31 inclusive. Don't write to the zero register x0.
            if(!REG_RD_WRN) begin
                register_file[RD_REG_OFFSET] = (RD_REG_OFFSET == 5'd0) ? register_file[RD_REG_OFFSET] : REG_DATA_IN;
            end

        end
    end

    //top-level assigns
    assign RS1_DATA_OUT = rs1_data_out;
    assign RS2_DATA_OUT = rs2_data_out;
    assign PC_DATA_OUT = pc_data_out;

endmodule 

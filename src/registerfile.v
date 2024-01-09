`timescale 1ns / 1ps

// REGISTER FILE:
//  create the 31 32-bit general purpose registers (x1-x31) and 32 bit zero register (x0). 
//  Setup procedures for reads and writes to general purpose registers (x1-x31)
//  declare the program counter register (???)


module RegisterFile(
    input wire CK_REF,
    input wire RST_N,
    input wire REG_RD_WRN,             // register read (HIGH) or write (LOW) mode
    input wire [4:0]  RS1_REG_OFFSET,  // register address offset for the rs1 source register for the next instruction
    input wire [4:0]  RS2_REG_OFFSET,  // register address offset for the rs2 source register for the next instruction
    input wire [4:0]  RD_REG_OFFSET,   // register address offset for the rd destination register for the next instruction
    input wire [31:0] REG_DATA_IN,     // input 32 bit word to write to the register at address rd_reg_offset
    input wire        UPDATE_PC,       // reprogram the value for the PC, occurs during WB stage of jump instructions
    input wire        FREEZE_PC,       // keep the PC constant and don't increment
    
    output wire [31:0] RS1_DATA_OUT,
    output wire [31:0] RS2_DATA_OUT,
    output wire [31:0] PC_DATA_OUT
    );
    
    // local signals
    // TODO: whats the deal with 33 registers? The 33rd can't be reached since RD_REG_OFFSET is only 5 bits
    reg [31:0] register_file [0:32];
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
    
    //************************
    //Register Write Procedure
    //************************
    always @(posedge CK_REF, negedge RST_N) begin
        if(!RST_N) begin
            // reset all registers to zero... 
            // FIXME: I can't get for loops working with Verilator?
            register_file[0]  <= 32'd0; 
            register_file[1]  <= 32'd0; 
            register_file[2]  <= 32'd0; 
            register_file[3]  <= 32'd0; 
            register_file[4]  <= 32'd0; 
            register_file[5]  <= 32'd0; 
            register_file[6]  <= 32'd0; 
            register_file[7]  <= 32'd0; 
            register_file[8]  <= 32'd0; 
            register_file[9]  <= 32'd0; 
            register_file[10] <= 32'd0; 
            register_file[11] <= 32'd0; 
            register_file[12] <= 32'd0; 
            register_file[13] <= 32'd0; 
            register_file[14] <= 32'd0; 
            register_file[15] <= 32'd0; 
            register_file[16] <= 32'd0;
            register_file[17] <= 32'd0;
            register_file[18] <= 32'd0;
            register_file[19] <= 32'd0;
            register_file[20] <= 32'd0;
            register_file[21] <= 32'd0;
            register_file[22] <= 32'd0;
            register_file[23] <= 32'd0;
            register_file[24] <= 32'd0;
            register_file[25] <= 32'd0;
            register_file[26] <= 32'd0;
            register_file[27] <= 32'd0;
            register_file[28] <= 32'd0;
            register_file[29] <= 32'd0;
            register_file[30] <= 32'd0;
            register_file[31] <= 32'd0;
            register_file[32] <= 32'd0;
        end
        else begin
            // TODO: should probably be counting up by 4 each time, parameterise the increment value
            //       alternatively maybe make the control unit feed in a signal that says it's ok
            //       to increment, like in the commented out conditional below
            if(!UPDATE_PC) begin
                // PC needs to stay constant and not increment
                if(FREEZE_PC) begin
                    register_file[32] <= register_file[32];
                end
                else begin
                    register_file[32] <= register_file[32] + 32'd1;
                end
            end
            // jump instruction is occurring, need to update the PC to the new value
            else begin
                register_file[32] <= REG_DATA_IN;
            end

            //only write to a register in the range of x1-x31 (+ PC). Don't write to the zero register x0.
            if(!REG_RD_WRN) begin
                register_file[RD_REG_OFFSET] <= (RD_REG_OFFSET == 5'd0) ? 32'd0 : REG_DATA_IN;
            end
        end
    end

    //top-level assigns
    assign RS1_DATA_OUT = register_file[RS1_REG_OFFSET];
    assign RS2_DATA_OUT = register_file[RS2_REG_OFFSET];
    assign PC_DATA_OUT  = register_file[32];

endmodule 

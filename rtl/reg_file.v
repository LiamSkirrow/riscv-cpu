`timescale 1ns / 1ps

// REGISTER FILE:
//  create the 31 32-bit general purpose registers (x1-x31) and 32 bit zero register (x0). 
//  Setup procedures for reads and writes to general purpose registers (x1-x31)
//  declare the program counter register (???)


module reg_file(
    input wire clk,
    input wire rst_n,
    input wire reg_rd_wrn,             // register read (HIGH) or write (LOW) mode
    input wire halt,                   // freeze all registers, CPU has been halted
    input wire [4:0]  rs1_reg_offset,  // register address offset for the rs1 source register for the next instruction
    input wire [4:0]  rs2_reg_offset,  // register address offset for the rs2 source register for the next instruction
    input wire [4:0]  rd_reg_offset,   // register address offset for the rd destination register for the next instruction
    input wire [31:0] reg_data_in,     // input 32 bit word to write to the register at address rd_reg_offset
    input wire        update_pc,       // reprogram the value for the PC, occurs during WB stage of jump instructions
    input wire        freeze_pc,       // keep the PC constant and don't increment
    
    output wire [31:0] rs1_data_out,
    output wire [31:0] rs2_data_out,
    output wire [31:0] pc_data_out
    );

    // FIXME: I want to rewrite this entire module... it's a bit crusty XD
    
    // local signals
    // TODO: whats the deal with 33 registers? The 33rd can't be reached since rd_reg_offset is only 5 bits
    reg [31:0] register_file [0:32];
    integer i;
    
    //***********************
    //Register Read Procedure
    //***********************
    // always @(*) begin
    //     if(reg_rd_wrn) begin
    //         //access the register at the address offset
    //         rs1_data_out <= register_file[rs1_reg_offset];
    //         rs2_data_out <= register_file[rs2_reg_offset];
    //     end
    //     else begin
    //         rs1_data_out = 32'b0;
    //         rs2_data_out = 32'b0;
    //     end
    // end
    
    //************************
    //Register Write Procedure
    //************************
    always @(posedge clk, negedge rst_n) begin
        if(!rst_n) begin
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
            if(!halt) begin
                // TODO: should probably be counting up by 4 each time, parameterise the increment value
                //       alternatively maybe make the control unit feed in a signal that says it's ok
                //       to increment, like in the commented out conditional below
                if(!update_pc) begin
                    // PC needs to stay constant and not increment
                    if(freeze_pc) begin
                        register_file[32] <= register_file[32];
                    end
                    else begin
                        register_file[32] <= register_file[32] + 32'd1;
                    end
                end
                // jump instruction is occurring, need to update the PC to the new value
                else begin
                    register_file[32] <= reg_data_in;
                end

                //only write to a register in the range of x1-x31 (+ PC). Don't write to the zero register x0.
                if(!reg_rd_wrn) begin
                    register_file[rd_reg_offset] <= (rd_reg_offset == 5'd0) ? 32'd0 : reg_data_in;
                end
            end
        end
    end

    //top-level assigns
    assign rs1_data_out = register_file[rs1_reg_offset];
    assign rs2_data_out = register_file[rs2_reg_offset];
    assign pc_data_out  = register_file[32];

endmodule 

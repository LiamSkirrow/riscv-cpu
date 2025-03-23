`timescale 1ns / 1ps

// ALU:
// decode the input operation bus
// register the inputs operand_a and operand_b
// perform the arithmetic or logic operation on the registered input operands operand_a_reg and operand_b_reg
// register the output of the arithmetic/logical operation into out_reg

// NOTE:
// - not yet using the `defines for the encoded op_val signal

module alu(
    input wire clk,
    input wire rst_n,
    input wire halt,     // CPU halt, freeze registers
    input wire alu_en,   // active high ALU enable TODO: remove this signal
    input wire [3:0] op_val,   // encoded operation bus, indicates which operand_a/L operation to perform
//     input wire SIGNED_UNSIGNED_N,   // signed or unsigned operation
    input wire [31:0] operand_a,   // ALU input 32 bit value
    input wire [31:0] operand_b,   // ALU input 32 bit value
    
    output wire [31:0] out,      // ALU output 32 bit value
    output wire [31:0] out_comb, // UNREGISTERED combinational output, needed for operand forwarding for consecutive instructions
    output wire carry_flag,
    output wire zero_flag,
    output wire overflow_flag,
    output wire alu_done   // ALU operation complete
    );
    
    // local signals
    reg alu_done_ff;
    // reg alu_done_ff_ff;
    reg alu_done_next;   // ALU register to enable the next pipeline stage
    reg [31:0] operand_a_reg, operand_b_reg;
    reg [32:0] out_reg, out_next;   // 33 bits to allow for carry bit as MSB
    reg [3:0] op_val_reg;

    // sequential process
    always @(posedge clk, negedge rst_n) begin
        if(!rst_n) begin
            operand_a_reg <= 32'h0000_0000;
            operand_b_reg <= 32'h0000_0000;
            out_reg <= 32'h0000_0000;
            alu_done_ff <= 1'b0;
            // alu_done_ff_ff <= 1'b0;
            op_val_reg <= 4'b0000;
        end
        else begin
            if(!halt) begin
                operand_a_reg <= operand_a;
                operand_b_reg <= operand_b;
                out_reg <= out_next;
                op_val_reg <= op_val;
                // 'alu_done_ff' is double-registered to add an extra clock cycle delay, therefore aligning with 'out_reg'
                // alu_done_ff <= alu_done_ff_ff;
                // alu_done_ff_ff <= alu_done_next;
                alu_done_ff <= alu_done_next;
            end
        end
    end
    
    // decode op_val and perform the arithmetic or logical operation
    always @(*) begin
        case (op_val_reg)

            // *** arithmetic operations ***
            4'b0001 : begin   // addition operation
                out_next = (operand_a_reg + operand_b_reg);
                alu_done_next = 1'b1;
            end
            //TODO: need to do declare nets as signed
            4'b0010 : begin   // subtraction operation
                out_next = (operand_a_reg - operand_b_reg);
                alu_done_next = 1'b1;
            end
            4'b0011 : begin   // set if less than
                out_next = ($signed(operand_a_reg) < $signed(operand_b_reg)) ? 32'd1 : 32'd0;
                alu_done_next = 1'b1;
            end
            4'b1011 : begin   // set if less than unsigned
                out_next = (operand_a_reg < operand_b_reg) ? 32'd1 : 32'd0;
                alu_done_next = 1'b1;
            end

            // *** logical operations ***

            4'b0100 : begin   // bitwise AND
                out_next = (operand_a_reg & operand_b_reg);
                alu_done_next = 1'b1;
            end
            4'b0101 : begin   // bitwise OR
                out_next = (operand_a_reg | operand_b_reg);
                alu_done_next = 1'b1;
            end
            4'b0110 : begin   // bitwise XOR
                out_next = (operand_a_reg ^ operand_b_reg);
                alu_done_next = 1'b1;
            end
            4'b0111 : begin   // shift left logical
                out_next = (operand_a_reg << operand_b_reg);
                alu_done_next = 1'b1;
            end
            4'b1000 : begin   // shift right logical
                out_next = (operand_a_reg >> operand_b_reg);
                alu_done_next = 1'b1;
            end
            4'b1001 : begin   // shift right arithmetic
                out_next = (operand_a_reg >>> operand_b_reg);
                alu_done_next = 1'b1;
            end
            
            default : begin   // invalid op_val, pipeline may be being filled (starting from reset) -> do nothing
                out_next = 33'h00000_0000;
                alu_done_next = 1'b0;
            end
        endcase
    end 
    
    //top-level assigns
    assign out        = out_reg[31:0];
    assign out_comb   = out_next[31:0];
    assign carry_flag = out_reg[32];
    assign zero_flag  = (out_reg[31:0] == 32'h0000_0000) ? 1'b1 : 1'b0;
    //assign overflow_flag = ???;
    
    assign alu_done = alu_done_ff;
    
endmodule

`timescale 1ns / 1ps

// ALU:
// decode the input operation bus
// register the inputs operand_a and operand_b
// perform the arithmetic or logic operation on the registered input operands operand_a and operand_b
// register the output of the arithmetic/logical operation into alu_result_out

// NOTE:
// - not yet using the `defines for the encoded op_val signal

module alu(
    input             clk,
    input             rst_n,
    input             halt,                // CPU halt, freeze registers
    input             signed_unsigned_n,   // TODO: flag to indicate whether this is a signed/unsigned operation
    input      [3:0]  op_val,              // encoded operation bus, indicates which math operation to perform
    input      [31:0] operand_a,           // ALU input 32 bit value
    input      [31:0] operand_b,           // ALU input 32 bit value
    output reg [31:0] alu_result_out,      // ALU output 33 bits to allow for carry bit as MSB
    output     [31:0] alu_result_out_comb, // UNREGISTERED combinational output, needed for operand forwarding for consecutive instructions
    output reg        carry_flag,
    output reg        zero_flag,
    output reg        overflow_flag // TODO: what's the diff between carry and overflow???
    );
    
    // local signals
    reg [32:0] alu_result; // 33 bits to allow for carry bit as MSB

    always @(posedge clk, negedge rst_n) begin
        if(!rst_n) begin
            alu_result_out <= 32'h0000_0000;
            carry_flag     <= 1'b0;
            zero_flag      <= 1'b0;
        end
        else begin
            if(!halt) begin
                alu_result_out <= alu_result[31:0];
                // flag register bits
                carry_flag <= alu_result[32];
                zero_flag  <= (alu_result[31:0] == 32'h0000_0000);
                // overflow_flag <= ???

            end
        end
    end
            
    //TODO: need to do declare nets as signed
    
    // decode op_val and perform the arithmetic or logical operation
    always @(*) begin
        case (op_val)

            // *** arithmetic operations ***
            4'b0001 : begin   // addition operation
                alu_result = (operand_a + operand_b);
            end
            4'b0010 : begin   // subtraction operation
                alu_result = (operand_a - operand_b);
            end
            4'b0011 : begin   // set if less than
                alu_result = ($signed(operand_a) < $signed(operand_b)) ? 32'd1 : 32'd0;
            end
            4'b1011 : begin   // set if less than unsigned
                alu_result = (operand_a < operand_b) ? 32'd1 : 32'd0;
            end

            // *** logical operations ***

            4'b0100 : begin   // bitwise AND
                alu_result = (operand_a & operand_b);
            end
            4'b0101 : begin   // bitwise OR
                alu_result = (operand_a | operand_b);
            end
            4'b0110 : begin   // bitwise XOR
                alu_result = (operand_a ^ operand_b);
            end
            4'b0111 : begin   // shift left logical
                alu_result = (operand_a << operand_b);
            end
            4'b1000 : begin   // shift right logical
                alu_result = (operand_a >> operand_b);
            end
            4'b1001 : begin   // shift right arithmetic
                alu_result = (operand_a >>> operand_b);
            end
            
            default : begin   // invalid op_val, pipeline may be being filled (starting from reset) -> do nothing
                alu_result = 33'h00000_0000;
            end
        endcase
    end 

    // instantaneous output used for operand forwarding
    assign alu_result_out_comb = alu_result[31:0];
    
endmodule

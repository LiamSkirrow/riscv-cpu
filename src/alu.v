`timescale 1ns / 1ps

// ALU:
// decode the input operation bus
// register the inputs A and B
// perform the arithmetic or logic operation on the registered input operands A_reg and B_reg
// register the output of the arithmetic/logical operation into OUT_reg

// NOTE:
// - not yet using the `defines for the encoded OP_VAL signal

module ALU(
    input wire CK_REF,
    input wire RST_N,
    input wire HALT,     // CPU halt, freeze registers
    input wire ALU_EN,   // active high ALU enable TODO: remove this signal
    input wire [3:0] OP_VAL,   // encoded operation bus, indicates which A/L operation to perform
//     input wire SIGNED_UNSIGNED_N,   // signed or unsigned operation
    input wire [31:0] A,   // ALU input 32 bit value
    input wire [31:0] B,   // ALU input 32 bit value
    
    output wire [31:0] OUT,    // ALU output 32 bit value
    output wire CARRY_FLAG,
    output wire ZERO_FLAG,
    output wire OVERFLOW_FLAG,
    output wire ALU_DONE   // ALU operation complete
    );
    
    // local signals
    reg alu_done_ff, alu_done_ff_ff, alu_done_next;   // ALU register to enable the next pipeline stage
    reg [31:0] A_reg, B_reg;
    reg [32:0] OUT_reg, OUT_next;   // 33 bits to allow for carry bit as MSB
    reg [3:0] OP_VAL_reg;

    // sequential process
    always @(posedge CK_REF, negedge RST_N) begin
        if(!RST_N) begin
            A_reg <= 32'h0000_0000;
            B_reg <= 32'h0000_0000;
            OUT_reg <= 32'h0000_0000;
            alu_done_ff <= 1'b0;
            alu_done_ff_ff <= 1'b0;
            OP_VAL_reg <= 4'b0000;
        end
        else begin
            if(!HALT) begin
                A_reg <= A;
                B_reg <= B;
                OUT_reg <= OUT_next;
                OP_VAL_reg <= OP_VAL;
                // 'alu_done_ff' is double-registered to add an extra clock cycle delay, therefore aligning with 'OUT_reg'
                // alu_done_ff <= alu_done_ff_ff;
                // alu_done_ff_ff <= alu_done_next;
                alu_done_ff <= alu_done_next;
            end
        end
    end
    
    // decode OP_VAL and perform the arithmetic or logical operation
    always @(*) begin
        case (OP_VAL_reg)

            // *** arithmetic operations ***
            4'b0001 : begin   // addition operation
                OUT_next = (A_reg + B_reg);
                alu_done_next = 1'b1;
            end
            //TODO: check that this does 2's complement addition
            4'b0010 : begin   // subtraction operation
                OUT_next = (A_reg - B_reg);
                alu_done_next = 1'b1;
            end
            4'b0011 : begin   // set if less than
                OUT_next = ($signed(A_reg) < $signed(B_reg)) ? 32'd1 : 32'd0;
                alu_done_next = 1'b1;
            end
            4'b1011 : begin   // set if less than unsigned
                OUT_next = (A_reg < B_reg) ? 32'd1 : 32'd0;
                alu_done_next = 1'b1;
            end

            // *** logical operations ***

            4'b0100 : begin   // bitwise AND
                OUT_next = (A_reg & B_reg);
                alu_done_next = 1'b1;
            end
            4'b0101 : begin   // bitwise OR
                OUT_next = (A_reg | B_reg);
                alu_done_next = 1'b1;
            end
            4'b0110 : begin   // bitwise XOR
                OUT_next = (A_reg ^ B_reg);
                alu_done_next = 1'b1;
            end
            4'b0111 : begin   // shift left logical
                OUT_next = (A_reg << B_reg);
                alu_done_next = 1'b1;
            end
            4'b1000 : begin   // shift right logical
                OUT_next = (A_reg >> B_reg);
                alu_done_next = 1'b1;
            end
            4'b1001 : begin   // shift right arithmetic
                OUT_next = (A_reg >>> B_reg);
                alu_done_next = 1'b1;
            end
            
            default : begin   // invalid OP_VAL, pipeline may be being filled (starting from reset) -> do nothing
                OUT_next = 33'h00000_0000;
                alu_done_next = 1'b0;
            end
        endcase
    end 
    
    //top-level assigns
    assign OUT = OUT_reg[31:0];
    assign CARRY_FLAG = OUT_reg[32];
    assign ZERO_FLAG = (OUT_reg[31:0] == 32'h0000_0000) ? 1'b1 : 1'b0;
    //assign OVERFLOW_FLAG = ???;
    
    assign ALU_DONE = alu_done_ff;
    
endmodule

`timescale 1ns / 1ps
// `include "rtl/defines.v"
// TODO: the above include interferes with the top level cpu debug harness

// main instruction decoder, read in opcode and set control signals accordingly

module instruction_decode(
    input             clk,
    input             rst_n,
    input             halt,
    input      [31:0] instruction_pointer_reg,
    input      [31:0] rs1_data_out,
    input      [31:0] rs2_data_out,
    input      [31:0] pc_data_out,
    input      [4:0]  rd_reg_offset_1c, // make pipeline reg at this level
    input      [4:0]  rd_reg_offset_2c,
    input      [4:0]  rd_reg_offset_3c,
    input      [31:0] alu_out_comb,     // TODO: needs to be conditionally removed if we're not forwarding
    input      [31:0] alu_output,       // TODO: (optional needs to be conditionally removed if we're not forwarding
    input      [31:0] alu_out_reg_1c,   // TODO: (optional needs to be conditionally removed if we're not forwarding
    output reg        update_pc_next,
    output reg [4:0]  rd_reg_offset_next,
    output reg [4:0]  rs1_reg_offset,
    output reg [4:0]  rs2_reg_offset,
    output reg [31:0] alu_input_a,
    output reg [31:0] alu_input_b,
    output reg [3:0]  alu_operation_code,
    output reg [1:0]  mem_access_operation_next,
    output reg        alu_mem_operation_n_next,
    output reg        reg_wb_flag_next,
    output reg [2:0]  reg_wb_data_type_next,
    output reg [31:0] rs2_data_out_next,
    output reg        breakpoint_flag_next,
    output reg        bubble_detect_next
);

    wire rd_register_rs1_in_flight_one_cycle;
    wire rd_register_rs2_in_flight_one_cycle;
    wire rd_register_rs1_in_flight_two_cycle;
    wire rd_register_rs2_in_flight_two_cycle;
    wire rd_register_rs1_in_flight_three_cycle;
    wire rd_register_rs2_in_flight_three_cycle;
    wire [31:0] alu_input_a_wire;
    wire [31:0] alu_input_b_wire;

    reg [31:0] alu_input_a_reg, alu_input_b_reg;
    reg branch_conditional_check;
    reg [3:0] alu_operation_code_reg;

    // FIXME: UP TO HERE!!!
    //        it seems that creating output regs causes it to infer synchronous elements whereas I want
    //        purely combo logic... need to recast with local regs and then assign wires and pass those out
    //        instead

    // latch the ALU input operands, pass out to ALU
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            alu_operation_code <= 4'd0;
            alu_input_a <= 32'd0;
            alu_input_b <= 32'd0;
        end
        else begin
            // only update the registers if halt is not active
            if(!halt) begin
                alu_operation_code <= alu_operation_code_reg;
                alu_input_a        <= alu_input_a_reg;
                alu_input_b        <= alu_input_b_reg;
            end
        end      
    end

    // TODO: might be nice to parameterise operand forwarding, doesn't look particularly difficult

    // TODO: need to figure out a priority system for operands in the case where two (or more) instructions
    //       modify the same register, the same register will be in flight at multiple stages. I think I need to prioritise
    //       in the order: one_cycle -> two_cycle -> three_cycle
    
    // TODO: is it easy to support (for example) single cycle forwarding for rs1 and also 2 cycle forwarding for rs2 at the exact same time?
    // it's certain that we'll run into cases where we have both types of forwarding for both rs registers... need to make supporting this
    // easy

    // operand forwarding logic
    // check if the current register we're trying to read from has been modified by the previous instruction (N-1)
    assign rd_register_rs1_in_flight_one_cycle  = (rs1_reg_offset == rd_reg_offset_1c) && (rs1_reg_offset != 5'd0);
    assign rd_register_rs2_in_flight_one_cycle  = (rs2_reg_offset == rd_reg_offset_1c) && (rs2_reg_offset != 5'd0);

    // check if the current register we're trying to read from has been modified by the 2nd most previous instruction (N-2)
    assign rd_register_rs1_in_flight_two_cycle  = (rs1_reg_offset == rd_reg_offset_2c) && (rs1_reg_offset != 5'd0);
    assign rd_register_rs2_in_flight_two_cycle  = (rs2_reg_offset == rd_reg_offset_2c) && (rs2_reg_offset != 5'd0);

    // check if the current register we're trying to read from has been modified by the 3rd most previous instruction (N-3)
    assign rd_register_rs1_in_flight_three_cycle  = (rs1_reg_offset == rd_reg_offset_3c) && (rs1_reg_offset != 5'd0);
    assign rd_register_rs2_in_flight_three_cycle  = (rs2_reg_offset == rd_reg_offset_3c) && (rs2_reg_offset != 5'd0);

`ifndef OPERAND_FORWARDING
    // TODO: need to pipeline stall here for a few clock cycles
    // to stall the pipeline it could be worth passing out a top level signal specifying how many clocks we want 
    // to stall for.

    // Alternatively: simply bitwise OR the above flags, and if asserted, freeze the PC and override the instruction register 
    //                to forcibly assert a NOP instruction. Once the data dependency has propagated through the pipeline, 
    //                the bitwise OR flag will deassert.

    // assign alu_input_a_wire = rs1_data_out;  // ALU A input is the output data of rs1
    // assign alu_input_b_wire = rs2_data_out;  // ALU B input is the output data of rs2
`else
    assign alu_input_a_wire = rd_register_rs1_in_flight_one_cycle ? alu_out_comb                                     :
                                                            ((rd_register_rs1_in_flight_two_cycle   ? alu_output     :
                                                             (rd_register_rs1_in_flight_three_cycle ? alu_out_reg_1c :
                                                              rs1_data_out)));  // ALU A input, operand forwarded

    assign alu_input_b_wire = rd_register_rs2_in_flight_one_cycle ? alu_out_comb                                     :
                                                            ((rd_register_rs2_in_flight_two_cycle   ? alu_output     :
                                                             (rd_register_rs2_in_flight_three_cycle ? alu_out_reg_1c :
                                                              rs2_data_out)));  // ALU B input, operand forwarded
`endif

    // TODO:
    // a good test of operand forwarding would be to test against an ADD instruction, where both source registers have 
    // been modified by previous instructions

    always @(*) begin
        // set sensible (inactive) default values for all registers
        branch_conditional_check = 1'b0;
        update_pc_next = 1'b0;
        rd_reg_offset_next = 5'd0;
        rs1_reg_offset = 5'd0;
        rs2_reg_offset = 5'd0;
        alu_input_a_reg = 32'd0;
        alu_input_b_reg = 32'd0;
        alu_operation_code_reg = 4'b0000;
        mem_access_operation_next = `MEM_NOP;
        alu_mem_operation_n_next = 1'b0;
        reg_wb_flag_next = 1'b0;
        reg_wb_data_type_next = `REG_WB_WORD;
        rs2_data_out_next = 32'd0;
        breakpoint_flag_next = 1'b0;

        case (instruction_pointer_reg[6:0])
            7'b011_0111 : begin   // LUI
                rd_reg_offset_next = instruction_pointer_reg[11:7];  // destination register being written to, must be triple registered/delayed for three ck cycles
                alu_input_a_reg = {instruction_pointer_reg[31:12], 12'd0}; // ALU A input, 20 bits, set 12 LSBs to zero
                alu_operation_code_reg = `ALU_ADD_OP; // ALU is set to perform an addition operation
                alu_mem_operation_n_next = 1'b1;      // indicate to the write back stage whether to load from ALU or memory, tripled registered/delayed for three ck cycles
                reg_wb_flag_next = 1'b1;              // register write back will occur for this instruction, must be triple registered/delayed for three ck cycles
            end
            7'b001_0111 : begin   // AUIPC
                rd_reg_offset_next = instruction_pointer_reg[11:7];  // destination register being written to, must be triple registered/delayed for three ck cycles
                alu_input_a_reg = {instruction_pointer_reg[31:12], 12'd0}; // ALU A input, 20 bits, set 12 LSBs to zero
                alu_input_b_reg = pc_data_out;        // ALU B input is the PC
                alu_operation_code_reg = `ALU_ADD_OP; // ALU is set to perform an addition operation
                alu_mem_operation_n_next = 1'b1;      // indicate to the write back stage whether to load from ALU or memory, tripled registered/delayed for three ck cycles
                reg_wb_flag_next = 1'b1;              // register write back will occur for this instruction, must be triple registered/delayed for three ck cycles            
            end
            7'b110_1111 : begin   // JAL
                update_pc_next = 1'b1;     // in three clock cycles, update the PC to the target address from the ALU
                rd_reg_offset_next = instruction_pointer_reg[11:7];  // destination register being written to, must be triple registered/delayed for three ck cycles
                
                // the ALU calculates the branch/jump target address
                alu_input_a_reg = { {12{instruction_pointer_reg[31]}},
                                   instruction_pointer_reg[19:12],
                                   instruction_pointer_reg[20],
                                   instruction_pointer_reg[30:21], 1'b0};   // ALU A input is...
                alu_input_b_reg = pc_data_out;                              // ALU B input is the PC
                alu_operation_code_reg = `ALU_ADD_OP; // ALU is set to perform an addition operation
                
                mem_access_operation_next = `MEM_NOP; // memory access stage will do nothing
                alu_mem_operation_n_next = 1'b1;   // indicate to the write back stage whether to load from ALU or memory, tripled registered/delayed for three ck cycles
                reg_wb_flag_next = 1'b1;           // register write back will occur for this instruction, must be triple registered/delayed for three ck cycles
            end
            7'b110_0111 : begin   // JALR
                update_pc_next = 1'b1;     // in three clock cycles, update the PC to the target address from the ALU
                rd_reg_offset_next = instruction_pointer_reg[11:7];  // destination register being written to, must be triple registered/delayed for three ck cycles
                rs1_reg_offset = instruction_pointer_reg[19:15];     // register address offset given by rs1 in INST
                
                // the ALU calculates the branch/jump target address
                alu_input_a_reg = { {21{instruction_pointer_reg[31]}},
                                        instruction_pointer_reg[29:19]};   // ALU A input is...
                alu_input_b_reg = alu_input_a_wire;                        // ALU B input is the PC
                alu_operation_code_reg = `ALU_ADD_OP; // ALU is set to perform an addition operation
                
                mem_access_operation_next = `MEM_NOP; // memory access stage will do nothing
                alu_mem_operation_n_next = 1'b1;   // indicate to the write back stage whether to load from ALU or memory, tripled registered/delayed for three ck cycles
                reg_wb_flag_next = 1'b1;           // register write back will occur for this instruction, must be triple registered/delayed for three ck cycles
            end
            7'b110_0011 : begin   // BEQ, BNE, BLT, BGE, BLTU, BGEU
                rs1_reg_offset = instruction_pointer_reg[19:15];     // register address offset given by rs1 in INST
                rs2_reg_offset = instruction_pointer_reg[24:20];     // register address offset given by rs2 in INST
                alu_input_a_reg = pc_data_out;                       // the PC's current value
                alu_input_b_reg = {{20{instruction_pointer_reg[31]}}, 
                                   {instruction_pointer_reg[7]},
                                   {instruction_pointer_reg[30:25]}, 
                                   {instruction_pointer_reg[11:8]}, 
                                   1'b0};   // immediate value in INST
                alu_mem_operation_n_next = 1'b1;        // indicate to the write back stage whether to load from ALU or memory, tripled registered/delayed for three ck cycles
                mem_access_operation_next = `MEM_NOP;   // set to inactive value
                reg_wb_data_type_next = 3'b000;         // set to inactive value

                alu_operation_code_reg    = branch_conditional_check ? `ALU_ADD_OP : `ALU_NOP_OP;  // conditionally perform an ALU add
                // reg_wb_flag_next          = branch_conditional_check;                              // conditional register write enable/disable
                update_pc_next            = branch_conditional_check;                              // in three clock cycles, update the PC to the target address from the ALU

                case(instruction_pointer_reg[14:12])
                    3'b000 : begin   // BEQ
                        branch_conditional_check = (alu_input_a_wire == alu_input_b_wire);
                    end
                    3'b001 : begin   // BNE
                        branch_conditional_check = (alu_input_a_wire != alu_input_b_wire);
                    end
                    3'b100 : begin   // BLT
                        branch_conditional_check = (alu_input_a_wire < alu_input_b_wire);
                    end
                    3'b101 : begin   // BGE
                        branch_conditional_check = (alu_input_a_wire >= alu_input_b_wire);
                    end
                    3'b110 : begin   // BLTU
                        branch_conditional_check = ($signed(alu_input_a_wire) < $signed(alu_input_b_wire));
                    end
                    3'b111 : begin   // BGEU
                        branch_conditional_check = ($signed(alu_input_a_wire) >= $signed(alu_input_b_wire));
                    end
                    default : begin //TODO: should this actually generate an illegal instruction exception?
                        branch_conditional_check = 1'b0;
                    end
                endcase
            end
            7'b000_0011 : begin   // LB, LH, LW, LBU, LHU
                rd_reg_offset_next = instruction_pointer_reg[11:7];  // destination register being written to, must be triple registered/delayed for three ck cycles
                rs1_reg_offset = instruction_pointer_reg[19:15];     // register address offset given by rs1 in INST
                rs2_reg_offset = 5'd0;                               // register address offset for rs2, not needed in this instruction
                // TODO: make sure operand forwarding doesn't break this next line of code
                alu_input_a_reg = alu_input_a_wire;   // ALU A input is the output data of rs1
                // TODO: do I need to actually sign extend the below line???
                alu_input_b_reg = {20'd0, instruction_pointer_reg[31:20]};    // ALU B input is the immediate in the instruction
                alu_operation_code_reg = `ALU_ADD_OP; // ALU is set to perform an addition operation
                mem_access_operation_next = `MEM_LOAD; // memory access stage will perform a memory load operation
                // alu_mem_operation_n_next = 1'b0;   // indicate to the write back stage whether to load from ALU or memory, tripled registered/delayed for three ck cycles
                reg_wb_flag_next = 1'b1;           // register write back will occur for this instruction, must be triple registered/delayed for three ck cycles

                case (instruction_pointer_reg[14:12])
                    3'b000 : begin   // LB
                        reg_wb_data_type_next = `REG_WB_BYTE_SIGNED;
                    end
                    3'b001 : begin   // LH
                        reg_wb_data_type_next = `REG_WB_HALF_SIGNED;
                    end
                    3'b010 : begin   // LW
                        reg_wb_data_type_next = `REG_WB_WORD;
                    end
                    3'b100 : begin   // LBU
                        reg_wb_data_type_next = `REG_WB_BYTE_UNSIGNED;
                    end
                    3'b101 : begin   // LHU
                        reg_wb_data_type_next = `REG_WB_HALF_UNSIGNED;
                    end

                    default : begin   // TODO: invalid opcode

                    end
                endcase
            end
            7'b010_0011 : begin   // SB, SH, SW
                rd_reg_offset_next = 5'd0;                           // rd_register_offset not needed for this instruction 
                rs1_reg_offset = instruction_pointer_reg[19:15];     // register address offset given by rs1 in INST
                rs2_reg_offset = instruction_pointer_reg[24:20];     // register address offset given by rs2 in INST
                // TODO: make sure operand forwarding doesn't break this next line of code
                alu_input_a_reg = alu_input_a_wire;   // ALU A input is the output data of rs1
                // TODO: do I need to actually sign extend the below line???
                alu_input_b_reg = {21'd0, {instruction_pointer_reg[31:25]}, 
                                        instruction_pointer_reg[10:7]};    // ALU B input is the immediate in the instruction
                alu_operation_code_reg = `ALU_ADD_OP;   // ALU is set to perform an addition operation
                mem_access_operation_next = `MEM_STORE; // memory access stage will perform a memory store operation
                // alu_mem_operation_n_next = 1'b0;   // indicate to the write back stage whether to load from ALU or memory, tripled registered/delayed for three ck cycles
                // reg_wb_flag_next = 1'b0;           // register write back will occur for this instruction, must be triple registered/delayed for three ck cycles
                rs2_data_out_next = rs2_data_out;  // register the value stored in rs2, needed for memory write stage 2 ck cycles later
                
                case (instruction_pointer_reg[14:12])
                    3'b000 : begin   // SB
                        reg_wb_data_type_next = `REG_WB_BYTE_SIGNED;
                    end
                    3'b001 : begin   // SH
                        reg_wb_data_type_next = `REG_WB_HALF_SIGNED;
                    end
                    3'b010 : begin   // SW
                        reg_wb_data_type_next = `REG_WB_WORD;
                    end
                    default : begin // TODO: invalid opcode

                    end
                endcase
            end
            7'b001_0011 : begin   // ADDI, SLTI, SLTIU, XORI, ORI, ANDI, SLLI, SRLI, SRAI
                rd_reg_offset_next = instruction_pointer_reg[11:7];  // destination register being written to, must be triple registered/delayed for three ck cycles
                rs1_reg_offset = instruction_pointer_reg[19:15];     // register address offset given by rs1 in INST
                rs2_reg_offset = 5'd0;                               // register address offset for rs2, not needed in this instruction
                alu_input_a_reg = alu_input_a_wire;                // Feed wire from operand forwarding logic
                // TODO: do I need to actually sign extend the below line???
                alu_input_b_reg = {20'd0, instruction_pointer_reg[31:20]};  // ALU B input is the immediate in the instruction
                mem_access_operation_next = `MEM_NOP; // memory access stage will perform a memory load operation
                alu_mem_operation_n_next = 1'b1;   // indicate to the write back stage whether to load from ALU or memory, tripled registered/delayed for three ck cycles
                reg_wb_flag_next = 1'b1;           // register write back will occur for this instruction, must be triple registered/delayed for three ck cycles                    

                case (instruction_pointer_reg[14:12])
                    3'b000 : begin   // ADDI
                        alu_operation_code_reg = `ALU_ADD_OP;
                    end
                    3'b010 : begin   // SLTI
                        alu_operation_code_reg = `ALU_SLT_OP;
                    end
                    3'b011 : begin   // SLTIU
                        alu_operation_code_reg = `ALU_SLTU_OP;
                    end
                    3'b100 : begin   // XORI
                        alu_operation_code_reg = `ALU_XOR_OP;
                    end
                    3'b110 : begin   // ORI
                        alu_operation_code_reg = `ALU_OR_OP;
                    end
                    3'b111 : begin   // ANDI
                        alu_operation_code_reg = `ALU_AND_OP;
                    end
                    3'b001 : begin   // SLLI
                        alu_operation_code_reg = `ALU_SLL_OP;
                    end
                    3'b101 : begin   // SRLI, SRAI
                        case (instruction_pointer_reg[30])
                            1'b0 : begin   // SRLI
                                alu_operation_code_reg = `ALU_SRL_OP;
                            end
                            1'b1 : begin   // SRAI
                                alu_operation_code_reg = `ALU_SRA_OP;
                            end
                        endcase
                    end
                    default : begin // TODO: invalid instruction slice
                        
                    end
                endcase
            end
            7'b011_0011 : begin   // ADD, SUB, SLL, SLT, SLTU, XOR, SRL, SRA, OR, AND 
                rd_reg_offset_next = instruction_pointer_reg[11:7];  // destination register being written to, must be triple registered/delayed for three ck cycles
                rs1_reg_offset = instruction_pointer_reg[19:15];     // register address offset given by rs1 in INST
                rs2_reg_offset = instruction_pointer_reg[24:20];     // register address offset given by rs2 in INST
                alu_input_a_reg = alu_input_a_wire;    // ALU A input is the output data of rs1
                alu_input_b_reg = alu_input_b_wire;    // ALU B input is the output data of rs2
                mem_access_operation_next = `MEM_NOP; // memory access stage will perform a memory load operation
                alu_mem_operation_n_next = 1'b1;   // indicate to the write back stage whether to load from ALU or memory, tripled registered/delayed for three ck cycles
                reg_wb_flag_next = 1'b1;           // register write back will occur for this instruction, must be triple registered/delayed for three ck cycles              

                case (instruction_pointer_reg[14:12])
                    3'b000 : begin   // ADD, SUB
                        case (instruction_pointer_reg[30])
                            1'b0: begin
                                alu_operation_code_reg = `ALU_ADD_OP;
                            end
                            1'b1 : begin
                                alu_operation_code_reg = `ALU_SUB_OP;
                            end
                        endcase
                    end
                    3'b010 : begin   // SLT
                        alu_operation_code_reg = `ALU_SLT_OP;
                    end
                    3'b011 : begin   // SLTU
                        alu_operation_code_reg = `ALU_SLTU_OP;
                    end
                    3'b100 : begin   // XOR
                        alu_operation_code_reg = `ALU_XOR_OP;
                    end
                    3'b110 : begin   // OR
                        alu_operation_code_reg = `ALU_OR_OP;
                    end
                    3'b111 : begin   // AND
                        alu_operation_code_reg = `ALU_AND_OP;
                    end
                    3'b001 : begin   // SLL
                        alu_operation_code_reg = `ALU_SLL_OP;
                    end
                    3'b101 : begin   // SRL, SRA
                        case (instruction_pointer_reg[30])
                            1'b0 : begin   // SRL
                                alu_operation_code_reg = `ALU_SRL_OP;
                            end
                            1'b1 : begin   // SRA
                                alu_operation_code_reg = `ALU_SRA_OP;
                            end
                        endcase
                    end
                    default : begin  // TODO: invalid opcode

                    end
                endcase
            end
            7'b000_1111 : begin   // FENCE
            
            end
            7'b111_0011 : begin   // ECALL, EBREAK

                // EBREAK
                if(instruction_pointer_reg[20]) begin
                    breakpoint_flag_next = 1'b1;
                end
                // ECALL 
                else begin
                    // treat ECALLs like a bubble for now... no functionality implemented
                end
            
            end

            7'b000_0000 : begin   // PIPELINE BUBBLE STATE
                
                // TODO: add bubble flag here (set to 1), pass it down the pipeline and use it to 
                //       detect whether instructions are being retired or not

                bubble_detect_next = 1'b1;

            end

            default : begin   // UNRECOGNISED OPCODE STATE
                
                //TODO: set illegal opcode exception flag
                
            end
        endcase
    end

endmodule
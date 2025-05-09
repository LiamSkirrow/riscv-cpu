`timescale 1ns / 1ps
`include "riscv-cpu/rtl/defines.v"

// main instruction decoder, read in opcode and set control signals accordingly

// NOTE: Thoughts
//       - define all the *_next signals in this module and pass them out to the top level
//         which is where they shall get latched/registered

// TODO: each opcode sub-case has its own default statement we should flag an invalid opcode by using an assert()
//       this will be useful for simulation, but what do we expect to happen on the CPU? Need to handle this case
//       maybe create an exception mechanism? May need an interrupt controller to be present...

module instruction_decode(
    input             clk,
    input             rst_n,
    input             decode_pulse,
    input      [31:0] instruction_pointer_reg,
    input      [31:0] rs1_data_out,
    input      [31:0] rs2_data_out,
    input      [4:0]  rd_reg_offset_1c,
    input      [4:0]  rd_reg_offset_2c,
    input      [4:0]  rd_reg_offset_3c,
    input      [31:0] alu_out_comb,
    input      [31:0] alu_output,
    input      [31:0] alu_out_reg_1c,
    input      [31:0] alu_out_reg_2c,
    output reg        update_pc_next,
    output reg [4:0]  rd_reg_offset_next,
    output reg [4:0]  rs1_reg_offset,
    output reg [4:0]  rs2_reg_offset,
    output reg [31:0] alu_input_a_reg,
    output reg [31:0] alu_input_b_reg,
    output reg [3:0]  alu_operation_code_reg,
    output reg [1:0]  mem_access_operation_next,
    output reg        alu_mem_operation_n_next,
    output reg        reg_wb_flag_next,
    output reg [2:0]  reg_wb_data_type_next,
    output reg [31:0] rs2_data_out_next
);

    wire rd_register_rs1_in_flight_one_cycle, rd_register_rs2_in_flight_one_cycle;
    wire rd_register_rs1_in_flight_two_cycle, rd_register_rs2_in_flight_two_cycle;
    wire rd_register_rs1_in_flight_three_cycle, rd_register_rs2_in_flight_three_cycle;
    wire [31:0] alu_input_a_wire, alu_input_b_wire;

    // TODO: might be nice to parameterise operand forwarding, doesn't look particularly difficult

    // TODO: need to figure out a priority system for operands in the case where two (or more) instructions
    //       modify the same register, the same register will be in flight at multiple stages. I think I need to prioritise
    //       in the order: one_cycle -> two_cycle -> three_cycle
    
    // TODO: is it easy to support (for example) single cycle forwarding for rs1 and also 2 cycle forwarding for rs2 at the exact same time?
    // it's certain that we'll run into cases where we have both types of forwarding for both rs registers... need to make supporting this
    // easy

    // operand forwarding logic
    // check if the current register we're trying to read from has been modified by the previous instruction (N-1)
    assign rd_register_rs1_in_flight_one_cycle  = (rs1_reg_offset == rd_reg_offset_1c) && (rs1_reg_offset != 32'd0);
    assign rd_register_rs2_in_flight_one_cycle  = (rs2_reg_offset == rd_reg_offset_1c) && (rs2_reg_offset != 32'd0);

    // check if the current register we're trying to read from has been modified by the 2nd most previous instruction (N-2)
    assign rd_register_rs1_in_flight_two_cycle  = (rs1_reg_offset == rd_reg_offset_2c) && (rs1_reg_offset != 32'd0);
    assign rd_register_rs2_in_flight_two_cycle  = (rs2_reg_offset == rd_reg_offset_2c) && (rs2_reg_offset != 32'd0);

    // check if the current register we're trying to read from has been modified by the 3rd most previous instruction (N-3)
    assign rd_register_rs1_in_flight_three_cycle  = (rs1_reg_offset == rd_reg_offset_3c) && (rs1_reg_offset != 32'd0);
    assign rd_register_rs2_in_flight_three_cycle  = (rs2_reg_offset == rd_reg_offset_3c) && (rs2_reg_offset != 32'd0);

`ifndef OPERAND_FORWARDING
    // TODO: need to pipeline stall here for a few clock cycles
    // to stall the pipeline it could be worth passing out a top level signal specifying how many clocks we want 
    // to stall for.

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

        case (instruction_pointer_reg[6:0])
            7'b011_0111 : begin   // LUI
                rd_reg_offset_next = instruction_pointer_reg[11:7];  // destination register being written to, must be triple registered/delayed for three ck cycles
                alu_input_a_reg = {instruction_pointer_reg[31:12], 12'd0}; // ALU A input, 20 bits, set 12 LSBs to zero
                alu_input_b_reg = 32'd0;                                   // ALU B input, zero
                alu_operation_code_reg = `ALU_ADD_OP; // ALU is set to perform an addition operation
                alu_mem_operation_n_next = 1'b1;      // indicate to the write back stage whether to load from ALU or memory, tripled registered/delayed for three ck cycles
                reg_wb_flag_next = 1'b1;              // register write back will occur for this instruction, must be triple registered/delayed for three ck cycles
            end
            7'b001_0111 : begin   // AUIPC
            
            end
            7'b110_1111 : begin   // JAL
                // create a single cycle pulse to ensure we don't execute the same instruction 5 times
                update_pc_next = decode_pulse;   // in three clock cycles, update the PC to the decoded value below
                rd_reg_offset_next = instruction_pointer_reg[11:7];  // destination register being written to, must be triple registered/delayed for three ck cycles
                
                // TODO: this is wrong, need to instead shift
                alu_input_a_reg = instruction_pointer_reg[31:12];   // ALU A input is...
                alu_input_b_reg = 32'd0;                            // ALU B input is...
                alu_operation_code_reg = `ALU_ADD_OP; // ALU is set to perform an addition operation
                // TODO: this is wrong, need to instead shift
                
                mem_access_operation_next = `MEM_NOP; // memory access stage will do nothing
                alu_mem_operation_n_next = 1'b1;   // indicate to the write back stage whether to load from ALU or memory, tripled registered/delayed for three ck cycles
                reg_wb_flag_next = 1'b1;           // register write back will occur for this instruction, must be triple registered/delayed for three ck cycles
            end
            7'b110_0111 : begin   // JALR
            
            end
            7'b110_0011 : begin   // BEQ, BNE, BLT, BGE, BLTU, BGEU
                // rd_reg_offset_next = `REG_FILE_PC_OFFSET;            // rd_register_offset not needed for this instruction 
                // rs1_reg_offset = instruction_pointer_reg[19:15];     // register address offset given by rs1 in INST
                // rs2_reg_offset = instruction_pointer_reg[24:20];     // register address offset given by rs2 in INST
                // alu_input_a_reg = pc_data_out;                       // the PC's current value
                // alu_input_b_reg = {{instruction_pointer_reg[31]}, {instruction_pointer_reg[7]},
                //                    {instruction_pointer_reg[30:25]}, {instruction_pointer_reg[11:8]}};   // immediate value in INST
                // alu_mem_operation_n_next = 1'b1;        // indicate to the write back stage whether to load from ALU or memory, tripled registered/delayed for three ck cycles
                // mem_access_operation_next = `MEM_NOP;   // set to inactive value
                // reg_wb_data_type_next = 3'b000;         // set to inactive value

                // case(instruction_pointer_reg[14:12])
                //     3'b000 : begin   // BEQ
                //         alu_operation_code_reg    = (rs1_data_out == rs2_data_out) ? `ALU_ADD_OP : `ALU_NOP_OP;   // conditionally perform an ALU add
                //         reg_wb_flag_next          = (rs1_data_out == rs2_data_out) ? 1'b1 : 1'b0;   // conditional register write enable/disable
                //         pipeline_flush_n_next     = (rs1_data_out == rs2_data_out) ? 1'b0 : 1'b1;   // conditional pipeline flush signal -> ACTIVE LOW
                //     end

                //     // TODO: need to think about pipeline_flush_n_ff/next signal, needs to go active for only one clock cycle (?)
                //     //       -> ternary on line 100 ????
                    
                //     default : begin //TODO: fill this with the remaining signals...
                //         reg_wb_data_type_next = `REG_WB_WORD;
                //     end

                // endcase


            end
            7'b000_0011 : begin   // LB, LH, LW, LBU, LHU
                rd_reg_offset_next = instruction_pointer_reg[11:7];  // destination register being written to, must be triple registered/delayed for three ck cycles
                rs1_reg_offset = instruction_pointer_reg[19:15];     // register address offset given by rs1 in INST
                rs2_reg_offset = 5'd0;                               // register address offset for rs2, not needed in this instruction
                // TODO: make sure operand forwarding doesn't break this next line of code
                alu_input_a_reg = alu_input_a_wire;   // ALU A input is the output data of rs1
                alu_input_b_reg = instruction_pointer_reg[31:20];    // ALU B input is the immediate in the instruction
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
                alu_input_b_reg = {{instruction_pointer_reg[31:25]}, 
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
                alu_input_b_reg = instruction_pointer_reg[31:20];  // ALU B input is the immediate in the instruction
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
                alu_input_b_reg = alu_input_b_wire;    // ALU B input is the immediate in the instruction
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
            
            end

            7'b000_0000 : begin   // PIPELINE BUBBLE STATE
                // set each control signal to an inactive value, should have a null effect on the pipeline
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
            end

            default : begin   // UNRECOGNISED OPCODE STATE
                //TODO: could include a top-level output to signal an invalid opcode detect...
            end
        endcase
    end

endmodule
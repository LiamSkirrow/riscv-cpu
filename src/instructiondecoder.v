`timescale 1ns / 1ps
`include "riscv-cpu/src/defines.v"

// main instruction decoder, read in opcode and set control signals accordingly

// NOTE: Thoughts
//       - define all the *_next signals in this module and pass them out to the top level
//         which is where they shall get latched/registered

// TODO: each opcode sub-case has its own default statement we should flag an invalid opcode by using an assert()
//       this will be useful for simulation, but what do we expect to happen on the CPU? Need to handle this case
//       maybe create an exception mechanism? May need an interrupt controller to be present...

module InstructionDecoder(
    input      [31:0] instruction_pointer_reg,
    input      [31:0] rs1_data_out,
    input      [31:0] rs2_data_out,
    input      [4:0]  rd_reg_offset_1c,
    input      [31:0] alu_out_comb,
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
    output reg [31:0] rs2_data_out_next,
    output reg        pipeline_flush_n_next
);

    wire rd_register_in_flight_one_cycle, rs1_register_in_flight_two_cycles;
    
    // TODO: NOTE: only supporting single cycle delay operand forwarding for now...

    // operand forwarding logic
    //   check if the current register we're trying to read from has been modified by the previous instruction (N-1)
    assign rd_register_in_flight_one_cycle  = (rs1_reg_offset == rd_reg_offset_1c) && (rs1_reg_offset != 32'd0);
    //   check if the current register we're trying to read from has been modified by the 2nd most previous instruction (N-2)
    // assign rs1_register_in_flight_two_cycles = (rs1_reg_offset == rs1_reg_offset_2c);

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
        pipeline_flush_n_next = 1'b1;

        case (instruction_pointer_reg[6:0])
            7'b011_0111 : begin   // LUI
            
            end
            7'b001_0111 : begin   // AUIPC
            
            end
            7'b110_1111 : begin   // JAL
                // HOWTO;
                // - freeze PC for 3 clocks cycles to allow for remaining pipelined instructions to complete
                // - whilst waiting, force control signals to zero to have null effect on subsequent clocks
                // - decode imm jump address, shift by [amount], ALU output shall form the value to write into 
                //   the rd register
                // - also, need some logic to say that we want to write that same ALU output value to the PC in 
                //   order to perform the actual jump

                update_pc_next = 1'b1;   // in three clock cycles, update the PC to the decoded value below
                rd_reg_offset_next = instruction_pointer_reg[11:7];  // destination register being written to, must be triple registered/delayed for three ck cycles
                
                // TODO: this is wrong, need to instead shift
                alu_input_a_reg = instruction_pointer_reg[20:12];   // ALU A input is the output data of rs1
                alu_input_b_reg = 32'd0;                            // ALU B input is the immediate in the instruction
                alu_operation_code_reg = `ALU_ADD_OP; // ALU is set to perform an addition operation
                // TODO: this is wrong, need to instead shift
                
                mem_access_operation_next = `MEM_NOP; // memory access stage will do nothing
                alu_mem_operation_n_next = 1'b1;   // indicate to the write back stage whether to load from ALU or memory, tripled registered/delayed for three ck cycles
                reg_wb_flag_next = 1'b1;           // register write back will occur for this instruction, must be triple registered/delayed for three ck cycles
            
            end
            7'b110_0111 : begin   // JALR
            
            end
            // TODO: the pipeline flush logic here needs checking!!! might not need the pipeline_flush_n_next signal at all..
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
                alu_input_a_reg = rs1_data_out;   // ALU A input is the output data of rs1
                alu_input_b_reg = instruction_pointer_reg[31:20];    // ALU B input is the immediate in the instruction
                alu_operation_code_reg = `ALU_ADD_OP; // ALU is set to perform an addition operation
                mem_access_operation_next = `MEM_LOAD; // memory access stage will perform a memory load operation
                alu_mem_operation_n_next = 1'b0;   // indicate to the write back stage whether to load from ALU or memory, tripled registered/delayed for three ck cycles
                reg_wb_flag_next = 1'b1;           // register write back will occur for this instruction, must be triple registered/delayed for three ck cycles
                pipeline_flush_n_next = 1'b1;      // no pipeline flush (1 = inactive)

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
                alu_input_a_reg = rs1_data_out;   // ALU A input is the output data of rs1
                alu_input_b_reg = {{instruction_pointer_reg[31:25]}, 
                                        instruction_pointer_reg[10:7]};    // ALU B input is the immediate in the instruction
                alu_operation_code_reg = `ALU_ADD_OP;   // ALU is set to perform an addition operation
                mem_access_operation_next = `MEM_STORE; // memory access stage will perform a memory store operation
                alu_mem_operation_n_next = 1'b0;   // indicate to the write back stage whether to load from ALU or memory, tripled registered/delayed for three ck cycles
                reg_wb_flag_next = 1'b0;           // register write back will occur for this instruction, must be triple registered/delayed for three ck cycles
                rs2_data_out_next = rs2_data_out;  // register the value stored in rs2, needed for memory write stage 2 ck cycles later
                pipeline_flush_n_next = 1'b1;      // no pipeline flush (1 = inactive)
                
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

                // operand forwarding
                alu_input_a_reg = rd_register_in_flight_one_cycle ? alu_out_comb : rs1_data_out;  // ALU A input is the output data of rs1
                alu_input_b_reg = instruction_pointer_reg[31:20];                                  // ALU B input is the immediate in the instruction
                //

                mem_access_operation_next = `MEM_NOP; // memory access stage will perform a memory load operation
                alu_mem_operation_n_next = 1'b1;   // indicate to the write back stage whether to load from ALU or memory, tripled registered/delayed for three ck cycles
                reg_wb_flag_next = 1'b1;           // register write back will occur for this instruction, must be triple registered/delayed for three ck cycles                    
                reg_wb_data_type_next = `REG_WB_WORD;
                pipeline_flush_n_next = 1'b1;      // no pipeline flush (1 = inactive)

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
                alu_input_a_reg = rs1_data_out;    // ALU A input is the output data of rs1
                alu_input_b_reg = rs2_data_out;    // ALU B input is the immediate in the instruction
                mem_access_operation_next = `MEM_NOP; // memory access stage will perform a memory load operation
                alu_mem_operation_n_next = 1'b1;   // indicate to the write back stage whether to load from ALU or memory, tripled registered/delayed for three ck cycles
                reg_wb_flag_next = 1'b1;           // register write back will occur for this instruction, must be triple registered/delayed for three ck cycles              
                pipeline_flush_n_next = 1'b1;      // no pipeline flush (1 = inactive)

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
                pipeline_flush_n_next = 1'b1;
            end

            default : begin   // UNRECOGNISED OPCODE STATE
                //TODO: could include a top-level output to signal an invalid opcode detect...
            end
        endcase
    end

endmodule
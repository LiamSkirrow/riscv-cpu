`timescale 1ns / 1ps
`include "src/defines.v"

// ***
// NOTES: 
// - not using any `defines for the state variable just yet, need to come up with better `define format
// - consider registering the signals alu_input_a_reg and alu_input_b_reg in this module, originally
//   I was planning on shifting these registers inside the ALU, but it might make more sense for them 
//   to exist here so that the decode phase of the pipeline has a single-cycle execution rather than being purely combinatorial
// ***

module Top(
    input wire CK_REF,
    input wire RST_N,
    input wire [31:0] INST_MEM_DATA_BUS,    // current instruction
    input wire [31:0] MEM_ACCESS_DATA_IN_BUS,    // RAM register block data input bus

    output wire [31:0] INST_MEM_ADDRESS_BUS,   // address bus driving the code memory, direct output of PC
    output wire MEM_ACCESS_READ_WRN,    // control signal to RAM register block indicating whether a read or write
    output wire [15:0] MEM_ACCESS_ADDRESS_BUS,    // RAM register block address bus
    output wire [31:0] MEM_ACCESS_DATA_OUT_BUS    // RAM register block data output bus
    );
        
    // local signals
    // pipeline control
    reg pipeline_flush_n_next, pipeline_flush_n_ff, pipeline_flush_n_ff_ff, pipeline_flush_n_ff_ff_ff, pipeline_flush_n_ff_ff_ff_ff;
    wire int_rst_n;
    // instruction fetch
    reg [31:0] program_counter_reg, instruction_pointer_reg;
    // register file
    wire reg_rd_wrn;
    reg  [4:0]  rs1_reg_offset, rs2_reg_offset, rd_reg_offset;
    reg  [31:0] reg_data_in;
    wire [31:0] rs1_data_out, rs2_data_out;
    wire [31:0] pc_data_out, ir_data_out;
    // alu
    reg  [31:0] alu_input_a_reg, alu_input_b_reg;
    wire [31:0] alu_input_a, alu_input_b;
    wire [31:0] alu_output;
    reg  [3:0] alu_operation_code_reg;
    wire [3:0] alu_operation_code;
    reg alu_en_reg;
    wire alu_en;
    wire alu_carry_flag;
    wire alu_zero_flag;
    wire alu_overflow_flag;
    wire alu_done;
    // memory access
    reg [1:0] mem_access_operation_ff, mem_access_operation_ff_ff, mem_access_operation_next;
    reg mem_access_read_wrn;
    reg [15:0] mem_access_address_bus;
    reg [31:0] mem_access_data_out_bus;
    reg [31:0] mem_data_ff, mem_data_next;
    reg mem_access_done;
    reg [31:0] mem_access_data_out_bus_adjusted;
    // register write back
    reg [4:0] rd_reg_offset_ff, rd_reg_offset_ff_ff, rd_reg_offset_ff_ff_ff, rd_reg_offset_next;
    reg reg_wb_flag_ff, reg_wb_flag_ff_ff, reg_wb_flag_ff_ff_ff, reg_wb_flag_next;
    reg alu_mem_operation_n_ff, alu_mem_operation_n_ff_ff, alu_mem_operation_n_ff_ff_ff, alu_mem_operation_n_next;
    reg [31:0] alu_out_reg_ff, alu_out_reg_next;
    reg [2:0] reg_wb_data_type_next, reg_wb_data_type_ff, reg_wb_data_type_ff_ff, reg_wb_data_type_ff_ff_ff;
    reg [31:0] alu_out_reg_adjusted;
    reg [31:0] mem_data_adjusted;
    reg [31:0] rs2_data_out_ff, rs2_data_out_ff_ff, rs2_data_out_ff_ff_ff, rs2_data_out_next;

    assign alu_input_a = alu_input_a_reg;
    assign alu_input_b = alu_input_b_reg;
    assign alu_operation_code = alu_operation_code_reg;
    assign alu_en = alu_en_reg;
    assign int_rst_n = RST_N & pipeline_flush_n_ff;
    
    // instantiate sub-modules
    RegisterFile inst_reg_file (
        .CK_REF(CK_REF), .RST_N(RST_N), .REG_RD_WRN(reg_rd_wrn), .RS1_REG_OFFSET(rs1_reg_offset), 
        .RS2_REG_OFFSET(rs2_reg_offset), .RD_REG_OFFSET(rd_reg_offset), .REG_DATA_IN(reg_data_in), 
        .RS1_DATA_OUT(rs1_data_out), .RS2_DATA_OUT(rs2_data_out), .PC_DATA_OUT(pc_data_out)
    );

    ALU inst_alu (
        .CK_REF(CK_REF), .RST_N(RST_N), .ALU_EN(alu_en), .OP_VAL(alu_operation_code),
        .A(alu_input_a), .B(alu_input_b), .OUT(alu_output), .CARRY_FLAG(alu_carry_flag),
        .ZERO_FLAG(alu_zero_flag), .OVERFLOW_FLAG(alu_overflow_flag), .ALU_DONE(alu_done)
    );

    // **************** NOTE ****************
    // the below registers will (probably) need resetting
    // when a pipeline flush occurs... might wanna AND gate RST_N with a pipeline_flush_n signal
    // so that the registers are cleared when the pipeline is emptied, so the pipeline stages are inactive 
    // when the pipeline is first being filled
    // **************** NOTE ****************
    
    // Sequential Processes
    always @(posedge CK_REF, negedge RST_N) begin
        if(!RST_N) begin
            pipeline_flush_n_ff <= 1'b1;
            pipeline_flush_n_ff_ff <= 1'b1;
            pipeline_flush_n_ff_ff_ff <= 1'b1;
            pipeline_flush_n_ff_ff_ff_ff <= 1'b1;
        end
        else begin 
            pipeline_flush_n_ff <= pipeline_flush_n_ff_ff;
            pipeline_flush_n_ff_ff <= pipeline_flush_n_ff_ff_ff;
            pipeline_flush_n_ff_ff_ff <= pipeline_flush_n_ff_ff_ff_ff;
            pipeline_flush_n_ff_ff_ff_ff <= pipeline_flush_n_next;
        end
    end

    always @(posedge CK_REF, negedge int_rst_n) begin
        if(!RST_N) begin
            rd_reg_offset_ff <= 5'b00000;
            rd_reg_offset_ff_ff <= 5'b00000;
            rd_reg_offset_ff_ff_ff <= 5'b00000;

            reg_wb_flag_ff <= 1'b0;
            reg_wb_flag_ff_ff <= 1'b0;
            reg_wb_flag_ff_ff_ff <= 1'b0;
            
            alu_mem_operation_n_ff <= 1'b0;
            alu_mem_operation_n_ff_ff <= 1'b0;
            alu_mem_operation_n_ff_ff_ff <= 1'b0;

            reg_wb_data_type_ff <= 3'b000;
            reg_wb_data_type_ff_ff <= 3'b000;
            reg_wb_data_type_ff_ff_ff <= 3'b000;

            rs2_data_out_ff <= 32'd0;
            rs2_data_out_ff_ff <= 32'd0;

            alu_out_reg_ff <= 32'h0000_0000;
            mem_data_ff <= 32'h0000_0000;
            mem_access_operation_ff <= 2'b00;
        end
        else begin
            rd_reg_offset_ff <= rd_reg_offset_ff_ff;
            rd_reg_offset_ff_ff <= rd_reg_offset_ff_ff_ff;
            rd_reg_offset_ff_ff_ff <= rd_reg_offset_next;

            reg_wb_flag_ff <= reg_wb_flag_ff_ff;
            reg_wb_flag_ff_ff <= reg_wb_flag_ff_ff_ff;
            reg_wb_flag_ff_ff_ff <= reg_wb_flag_next;
            
            alu_mem_operation_n_ff <= alu_mem_operation_n_ff_ff;
            alu_mem_operation_n_ff_ff <= alu_mem_operation_n_ff_ff_ff;
            alu_mem_operation_n_ff_ff_ff <= alu_mem_operation_n_next;

            reg_wb_data_type_ff <= reg_wb_data_type_ff_ff;
            reg_wb_data_type_ff_ff <= reg_wb_data_type_ff_ff_ff;
            reg_wb_data_type_ff_ff_ff <= reg_wb_data_type_next;

            rs2_data_out_ff <= rs2_data_out_ff_ff;
            rs2_data_out_ff_ff <= rs2_data_out_next;

            mem_access_operation_ff <= mem_access_operation_ff_ff;
            mem_access_operation_ff_ff <= mem_access_operation_next;

            mem_data_ff <= MEM_ACCESS_DATA_IN_BUS;
            alu_out_reg_ff <= alu_out_reg_next;
            
        end
    end


    //************************
    // Instruction Fetch Stage
    //************************

    // shifted the PC into Register_File.v for ease of reading/writing

    // IR register sequential process, using a SYNCHRONOUS reset here (TODO: figure out if this is an issue)
    always @(posedge CK_REF) begin
        if(!RST_N) begin 
            instruction_pointer_reg <= 32'd0;
        end
        else begin
            instruction_pointer_reg <= INST_MEM_DATA_BUS;
        end
    end   


    //*************************
    // Instruction Decode Stage
    //*************************
    // TODO: go through and make sure all the control signals are reset in the default statements...
    always @(*) begin
        case (instruction_pointer_reg[6:0])
            7'b011_0111 : begin   // LUI
            
            end
            7'b001_0111 : begin   // AUIPC
            
            end
            7'b110_1111 : begin   // JAL
            
            end
            7'b110_0111 : begin   // JALR
            
            end
            7'b110_0011 : begin   // BEQ, BNE, BLT, BGE, BLTU, BGEU
                rd_reg_offset_next = `REG_FILE_PC_OFFSET;            // rd_register_offset not needed for this instruction 
                rs1_reg_offset = instruction_pointer_reg[19:15];     // register address offset given by rs1 in INST
                rs2_reg_offset = instruction_pointer_reg[24:20];     // register address offset given by rs2 in INST
                alu_input_a_reg = pc_data_out;                       // the PC's current value
                alu_input_b_reg = {{instruction_pointer_reg[31]}, {instruction_pointer_reg[7]},
                                   {instruction_pointer_reg[30:25]}, {instruction_pointer_reg[11:8]}};   // immediate value in INST
                alu_mem_operation_n_next = 1'b1;        // indicate to the write back stage whether to load from ALU or memory, tripled registered/delayed for three ck cycles
                mem_access_operation_next = `MEM_NOP;   // set to inactive value
                reg_wb_data_type_next = 3'b000;         // set to inactive value

                case(instruction_pointer_reg[14:12])
                    3'b000 : begin   // BEQ
                        alu_operation_code_reg    = (rs1_data_out == rs2_data_out) ? `ALU_ADD_OP : `ALU_NOP_OP;   // conditionally perform an ALU add
                        reg_wb_flag_next          = (rs1_data_out == rs2_data_out) ? 1'b1 : 1'b0;   // conditional register write enable/disable
                        pipeline_flush_n_next     = (rs1_data_out == rs2_data_out) ? 1'b0 : 1'b1;   // conditional pipeline flush signal -> ACTIVE LOW
                    end

                    // TODO: need to think about pipeline_flush_n_ff/next signal, needs to go active for only one clock cycle (?)
                    //       -> ternary on line 100 ????
                    
                    default : begin //TODO: fill this with the remaining signals...
                        reg_wb_data_type_next = `REG_WB_WORD;
                    end

                endcase


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

                    default : begin   // invalid opcode, set all control signals to sensible values
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
                    default : begin
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
                    end
                endcase
            end
            7'b001_0011 : begin   // ADDI, SLTI, SLTIU, XORI, ORI, ANDI, SLLI, SRLI, SRAI
                rd_reg_offset_next = instruction_pointer_reg[11:7];  // destination register being written to, must be triple registered/delayed for three ck cycles
                rs1_reg_offset = instruction_pointer_reg[19:15];     // register address offset given by rs1 in INST
                rs2_reg_offset = 5'd0;                               // register address offset for rs2, not needed in this instruction
                alu_input_a_reg = rs1_data_out;   // ALU A input is the output data of rs1
                alu_input_b_reg = instruction_pointer_reg[31:20];    // ALU B input is the immediate in the instruction
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
                            default : begin
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
                            end
                        endcase
                    end
                    default : begin
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
                            default : begin
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
                            default : begin
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
                            end
                        endcase
                    end
                    default : begin
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
                    end
                endcase
            end
            7'b000_1111 : begin   // FENCE
            
            end
            7'b111_0011 : begin   // ECALL, EBREAK
            
            end
            default : begin   // this state is the equivalent of a pipeline bubble, 
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
                //TODO: could include a top-level output to signal an invalid opcode detect...
            end
        endcase
    end 
    
    
    //********************
    // Memory Access Stage
    //********************

    // decode the word/halfword/byte
    always @(*) begin
        case (reg_wb_data_type_ff_ff) 
            3'b000 : begin   // WORD
                mem_access_data_out_bus_adjusted = rs2_data_out_ff;
            end
            3'b010 : begin   // SIGNED HALFWORD
                mem_access_data_out_bus_adjusted = $signed(rs2_data_out_ff[15:0]);
            end
            3'b100 : begin   // SIGNED BYTE
                mem_access_data_out_bus_adjusted = $signed(rs2_data_out_ff[7:0]);
            end
            default : begin
                mem_access_data_out_bus_adjusted = 32'hDEAD_BEEF; //TODO: replace with 32'd0
            end
        endcase
    end

    always @(*) begin
        // only proceed if the ALU_DONE flag is high (up to the correct stage in the pipeline)
        if(alu_done) begin
            case (mem_access_operation_ff) 
                2'b00 : begin   // MEM LOAD
                    // set top level memory interface READ bit
                    // set the address bus
                    // read the value from the data bus into mem_data_next (latched on next clock edge), performed at top of code
                    
                    mem_access_read_wrn = 1'b1;
                    mem_access_address_bus = alu_output;
                    mem_access_done = 1'b1;  // TODO: check in TB what happens when this is removed
                end
                2'b01 : begin   // MEM STORE
                    // set top level memory interface WRITE bit
                    // set the address bus
                    // write the value to the data bus to RAM (latched on next clock edge)

                    mem_access_read_wrn = 1'b0;
                    mem_access_address_bus = alu_output;
                    mem_access_data_out_bus = mem_access_data_out_bus_adjusted;
                    
                end
                default : begin   // MEM NOP
                    // NOP case, don't interface with memory at all...
                    mem_access_read_wrn = 1'b1; 
                    alu_out_reg_next = alu_output;
                    mem_access_address_bus = 16'd0;
                    mem_access_data_out_bus = 32'd0;
                end
            endcase
        end
        // TODO: add all signals here, set to sensible inactive values
        else begin
            mem_access_read_wrn = 1'b1; 
            alu_out_reg_next = alu_output;
            mem_access_address_bus = 16'd0;
        end
    end


    //********************
    // Register Write Back
    //********************
    
    // ensure the reg_rd_wrn flag is low only when register write-back occurs
    assign reg_rd_wrn = (reg_wb_flag_ff) ? 1'b0 : 1'b1;

    // decode the word/halfword/byte, signed/unsigned indicator bus 
    always @(*) begin
        case (reg_wb_data_type_ff) 
            3'b000 : begin   // WORD
                mem_data_adjusted = mem_data_ff;
            end
            3'b001 : begin   // UNSIGNED HALFWORD
                mem_data_adjusted = mem_data_ff[15:0];
            end
            3'b010 : begin   // SIGNED HALFWORD
                mem_data_adjusted = $signed(mem_data_ff[15:0]);
            end
            3'b011 : begin   // UNSIGNED BYTE
                mem_data_adjusted = mem_data_ff[7:0];
            end
            3'b100 : begin   // SIGNED BYTE
                mem_data_adjusted = $signed(mem_data_ff[7:0]);
            end
            default : begin
                mem_data_adjusted = 32'd0;
            end
        endcase
    end

    always @(*) begin
        // only proceed if the reg_wb_flag flag is high (up to the correct stage in the pipeline)
        if(reg_wb_flag_ff) begin   // write the data read from either memory or ALU to the value stored in rd_reg_offset_ff
            rd_reg_offset = rd_reg_offset_ff;
            // check whether write value is ALU ouput (math/logical instruction) or memory output (load/store instruction)
            reg_data_in = alu_mem_operation_n_ff ? alu_out_reg_ff : mem_data_adjusted;
        end
        else begin
            // address the zero register r0, no write operation will occur
            rd_reg_offset = 5'd0;
            reg_data_in = 32'd0;
        end          
    end

    assign MEM_ACCESS_READ_WRN = mem_access_read_wrn;    
    assign MEM_ACCESS_ADDRESS_BUS = mem_access_address_bus;
    assign MEM_ACCESS_DATA_OUT_BUS = mem_access_data_out_bus;
    assign INST_MEM_ADDRESS_BUS = pc_data_out;
        
endmodule

`timescale 1ns / 1ps
// `include "rtl/defines.v"
// TODO: the above include interferes with the top level cpu debug harness

// ***
// NOTES: 
// - not using any `defines for the state variable just yet, need to come up with better `define format
// - consider registering the signals alu_input_a_reg and alu_input_b_reg in this module, originally
//   I was planning on shifting these registers inside the ALU, but it might make more sense for them 
//   to exist here so that the decode phase of the pipeline has a single-cycle execution rather than being purely combinatorial
// ***

module top(
    input wire clk,
    input wire rst_n,
    input wire halt,                        // halt the CPU pipeline
    input  wire [31:0] IMEM_DATA_BUS,       // current instruction
    output wire [31:0] IMEM_ADDRESS_BUS,    // address bus driving the code memory, direct output of PC

    output wire        DMEM_READ_WRN,       // control signal to RAM register block indicating whether a read or write
    output wire [15:0] DMEM_ADDRESS_BUS,    // RAM register block address bus
    input  wire [31:0] DMEM_DATA_IN_BUS,    // RAM register block data input bus
    output wire [31:0] DMEM_DATA_OUT_BUS,   // RAM register block data output bus
    
    output wire        breakpoint_fired,    // breakpoint status bit
    output wire        instruction_retired, // instruction retired flag
    output wire        finish_exec_signal   // finish execution
    );
        
    // instruction fetch
    reg [31:0] program_counter_reg, instruction_pointer_reg, instruction_pointer_reg_1c;
    reg [6:0]  instruction_pointer_reg_2c, instruction_pointer_reg_3c, instruction_pointer_reg_4c;
    // register file
    wire reg_rd_wrn;
    reg  [31:0] reg_data_in;
    wire [31:0] rs1_data_out, rs2_data_out;
    wire [31:0] pc_data_out, ir_data_out;
    wire freeze_pc;
    reg update_pc_3c, update_pc_2c, update_pc_1c;
    // alu
    reg  [31:0] alu_input_a, alu_input_b;
    wire [31:0] alu_output;
    wire [3:0]  alu_operation_code;
    wire [31:0] alu_out_comb;
    wire alu_en;
    wire alu_carry_flag;
    wire alu_zero_flag;
    wire alu_overflow_flag;
    // memory access
    reg [1:0] mem_access_operation_2c, mem_access_operation_1c;
    reg mem_access_read_wrn;
    reg [15:0] mem_access_address_bus;
    reg [31:0] mem_access_data_out_bus;
    reg [31:0] mem_data_1c, mem_data_next;
    reg mem_access_done;
    reg [31:0] mem_access_data_out_bus_adjusted;
    // register write back and operand forwarding
    reg [4:0] rd_reg_offset_3c, rd_reg_offset_2c, rd_reg_offset_1c;
    reg reg_wb_flag_3c, reg_wb_flag_2c, reg_wb_flag_1c;
    reg alu_mem_operation_n_3c, alu_mem_operation_n_2c, alu_mem_operation_n_1c;
    reg [31:0] alu_out_reg_1c;
    reg [2:0] reg_wb_data_type_3c, reg_wb_data_type_2c, reg_wb_data_type_1c;
    reg [31:0] alu_out_reg_adjusted;
    reg [31:0] mem_data_adjusted;
    reg [31:0] rs2_data_out_2c, rs2_data_out_1c;
    reg [4:0]  rs1_reg_offset, rs2_reg_offset, rd_reg_offset;
    reg [31:0] rd_reg_data_1c;
    reg freeze_pc_reg;
    // debug
    reg breakpoint_flag_3c, breakpoint_flag_2c, breakpoint_flag_1c;
    wire breakpoint_flag_next;
    // reg bubble_detect_flag_3c, bubble_detect_flag_2c, bubble_detect_flag_1c;
    wire bubble_detect_next;
    reg finish_exec_flag_3c, finish_exec_flag_2c, finish_exec_flag_1c;
    wire finish_exec_next;

    // wires for the instruction decoder
    wire        update_pc_next;
    wire [4:0]  rd_reg_offset_next;
    wire [1:0]  mem_access_operation_next;
    wire        alu_mem_operation_n_next;
    wire        reg_wb_flag_next;
    wire [2:0]  reg_wb_data_type_next;
    wire [31:0] rs2_data_out_next;
    
    // if we get any kind of jump instruction, then we need to freeze the value of the PC.
    // Read the instruction straight from DMEM, we have to do this before we even latch the instruction
    // since it would be too late by then, and the PC would have already advanced to the next address.
    assign freeze_pc = (IMEM_DATA_BUS[6:0] == 7'b110_1111);

    // instantiate sub-modules
    reg_file u_reg_file (
        .clk(clk), 
        .rst_n(rst_n), 
        .reg_rd_wrn(reg_rd_wrn), 
        .rs1_reg_offset(rs1_reg_offset), 
        .rs2_reg_offset(rs2_reg_offset), 
        .rd_reg_offset(rd_reg_offset), 
        .reg_data_in(reg_data_in), 
        .rs1_data_out(rs1_data_out), 
        .rs2_data_out(rs2_data_out), 
        .pc_data_out(pc_data_out), 
        .update_pc(update_pc_3c),
        .freeze_pc(freeze_pc), 
        .halt(halt)
    );
    
    // ******************
    // Pipeline registers
    // ******************

    always @(posedge clk, negedge rst_n) begin
        if(!rst_n) begin
            rd_reg_offset_3c <= 5'b00000;
            rd_reg_offset_2c <= 5'b00000;
            rd_reg_offset_1c <= 5'b00000;

            reg_wb_flag_3c <= 1'b0;
            reg_wb_flag_2c <= 1'b0;
            reg_wb_flag_1c <= 1'b0;
            
            alu_mem_operation_n_3c <= 1'b0;
            alu_mem_operation_n_2c <= 1'b0;
            alu_mem_operation_n_1c <= 1'b0;

            reg_wb_data_type_3c <= 3'b000;
            reg_wb_data_type_2c <= 3'b000;
            reg_wb_data_type_1c <= 3'b000;

            rs2_data_out_2c <= 32'd0;
            rs2_data_out_1c <= 32'd0;

            alu_out_reg_1c <= 32'h0000_0000;
            mem_data_1c <= 32'h0000_0000;
            mem_access_operation_2c <= 2'b00;
            mem_access_operation_1c <= 2'b00;

            update_pc_3c <= 1'b0;
            update_pc_2c <= 1'b0;
            update_pc_1c <= 1'b0;

            breakpoint_flag_3c <= 1'b0;
            breakpoint_flag_2c <= 1'b0;
            breakpoint_flag_1c <= 1'b0;

            // bubble_detect_flag_3c <= 1'b0;
            // bubble_detect_flag_2c <= 1'b0;
            // bubble_detect_flag_1c <= 1'b0;

            finish_exec_flag_3c <= 1'b0;
            finish_exec_flag_2c <= 1'b0;
            finish_exec_flag_1c <= 1'b0;
        end
        else begin
            // only update the registers if halt is not active
            if(!halt) begin
                rd_reg_offset_3c <= rd_reg_offset_2c;
                rd_reg_offset_2c <= rd_reg_offset_1c;
                rd_reg_offset_1c <= rd_reg_offset_next;

                reg_wb_flag_3c <= reg_wb_flag_2c;
                reg_wb_flag_2c <= reg_wb_flag_1c;
                reg_wb_flag_1c <= reg_wb_flag_next;
                
                alu_mem_operation_n_3c <= alu_mem_operation_n_2c;
                alu_mem_operation_n_2c <= alu_mem_operation_n_1c;
                alu_mem_operation_n_1c <= alu_mem_operation_n_next;

                reg_wb_data_type_3c <= reg_wb_data_type_2c;
                reg_wb_data_type_2c <= reg_wb_data_type_1c;
                reg_wb_data_type_1c <= reg_wb_data_type_next;
                
                rs2_data_out_2c <= rs2_data_out_1c;
                rs2_data_out_1c <= rs2_data_out_next;

                mem_access_operation_2c <= mem_access_operation_1c;
                mem_access_operation_1c <= mem_access_operation_next;

                mem_data_1c <= DMEM_DATA_IN_BUS;
                alu_out_reg_1c <= alu_output;

                update_pc_3c <= update_pc_2c;
                update_pc_2c <= update_pc_1c;
                update_pc_1c <= update_pc_next;

                breakpoint_flag_3c <= breakpoint_flag_2c;
                breakpoint_flag_2c <= breakpoint_flag_1c;
                breakpoint_flag_1c <= breakpoint_flag_next;

                // bubble_detect_flag_3c <= bubble_detect_flag_2c;
                // bubble_detect_flag_2c <= bubble_detect_flag_1c;
                // bubble_detect_flag_1c <= bubble_detect_next;

                finish_exec_flag_3c <= finish_exec_flag_2c;
                finish_exec_flag_2c <= finish_exec_flag_1c;
                finish_exec_flag_1c <= finish_exec_next;
            end
        end
    end


    //************************
    // Instruction Fetch Stage
    //************************

    // IR register sequential process, using a SYNCHRONOUS reset here
    // TODO: reverted to async reset... why did I want to use sync reset ^ again???
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin 
            freeze_pc_reg              <= 1'b0;
            instruction_pointer_reg_4c <= 7'd0;   // opcode is all we need here
            instruction_pointer_reg_3c <= 7'd0;   // opcode is all we need here
            instruction_pointer_reg_2c <= 7'd0;   // opcode is all we need here
            instruction_pointer_reg_1c <= 32'd0;
            instruction_pointer_reg    <= 32'd0;
        end
        else begin
            if(!halt) begin
                freeze_pc_reg              <= freeze_pc;
                instruction_pointer_reg_4c <= instruction_pointer_reg_3c;
                instruction_pointer_reg_3c <= instruction_pointer_reg_2c;
                instruction_pointer_reg_2c <= instruction_pointer_reg_1c[6:0];
                instruction_pointer_reg_1c <= instruction_pointer_reg;
                instruction_pointer_reg    <= freeze_pc_reg ? {24'd0, 8'h13} : IMEM_DATA_BUS;
                                                            // ^ADDI x0, x0, 0 => NOP
                                                            // 000000000000 00000 000 0000 00010011
                // FIXME: consider moving this mux after the fetch pipeline registers so that we can reuse it for the non-forwarding logic
                //        refer to diagram in book...
            end
        end
    end

    //*************************
    // Instruction Decode Stage
    //*************************
    
    // given the current instruction, decode the relevant fields and pass out the control signals to the top level
    instruction_decode u_inst_decode(
        .clk(clk), 
        .rst_n(rst_n),
        .halt(halt),
        .instruction_pointer_reg(instruction_pointer_reg), 
        .rs1_data_out(rs1_data_out), 
        .rs2_data_out(rs2_data_out),
        .pc_data_out(pc_data_out),
        .update_pc_next(update_pc_next), 
        .rd_reg_offset_next(rd_reg_offset_next),
        .rs1_reg_offset(rs1_reg_offset), 
        .rs2_reg_offset(rs2_reg_offset), 
        .alu_input_a(alu_input_a),
        .alu_input_b(alu_input_b), 
        .alu_operation_code(alu_operation_code), 
        .mem_access_operation_next(mem_access_operation_next),
        .alu_mem_operation_n_next(alu_mem_operation_n_next), 
        .reg_wb_flag_next(reg_wb_flag_next), 
        .reg_wb_data_type_next(reg_wb_data_type_next), 
        .rs2_data_out_next(rs2_data_out_next), 
        .alu_out_comb(alu_out_comb), 
        .alu_output(alu_output),
        .rd_reg_offset_1c(rd_reg_offset_1c), 
        .rd_reg_offset_2c(rd_reg_offset_2c), 
        .rd_reg_offset_3c(rd_reg_offset_3c),
        .alu_out_reg_1c(alu_out_reg_1c),
        .breakpoint_flag_next(breakpoint_flag_next),
        .bubble_detect_next(bubble_detect_next),
        .finish_exec_next(finish_exec_next)
    );


    //********************
    // Execute/ALU Stage
    //********************

    alu u_alu (
        .clk(clk), 
        .rst_n(rst_n), 
        .halt(halt),
        .signed_unsigned_n(1'b0), // TODO: needs connecting... What does this do again?
        .jump_instruction(update_pc_1c),
        .op_val(alu_operation_code),
        .operand_a(alu_input_a), 
        .operand_b(alu_input_b), 
        .alu_result_out(alu_output), //TODO: 33 bits
        .alu_result_out_comb(alu_out_comb),
        .carry_flag(alu_carry_flag),
        .zero_flag(alu_zero_flag), 
        .overflow_flag(alu_overflow_flag)
    );
    

    //********************
    // Memory Access Stage
    //********************

    // decode the word/halfword/byte
    always @(*) begin
        case (reg_wb_data_type_2c) 
            3'b000 : begin   // WORD
                mem_access_data_out_bus_adjusted = rs2_data_out_2c;
            end
            3'b010 : begin   // SIGNED HALFWORD
                mem_access_data_out_bus_adjusted = { {16{rs2_data_out_2c[15]}}, $signed(rs2_data_out_2c[15:0])};
            end
            3'b100 : begin   // SIGNED BYTE
                mem_access_data_out_bus_adjusted = { {24{rs2_data_out_2c[7]}}, $signed(rs2_data_out_2c[7:0])};
            end
            default : begin
                mem_access_data_out_bus_adjusted = 32'h0;
            end
        endcase
    end

    always @(*) begin
        case (mem_access_operation_2c) 
            2'b00 : begin   // MEM LOAD
                // set top level memory interface READ bit
                // set the address bus
                // read the value from the data bus into mem_data_next (latched on next clock edge), performed at top of code
                
                mem_access_read_wrn = 1'b1;
                mem_access_address_bus = alu_output[15:0];
                mem_access_done = 1'b1;  // TODO: check in TB what happens when this is removed
            end
            2'b01 : begin   // MEM STORE
                // set top level memory interface WRITE bit
                // set the address bus
                // write the value to the data bus to RAM (latched on next clock edge)

                mem_access_read_wrn = 1'b0;
                mem_access_address_bus = alu_output[15:0];
                mem_access_data_out_bus = mem_access_data_out_bus_adjusted;
                
            end
            default : begin   // MEM NOP
                // NOP case, don't interface with memory at all...
                mem_access_read_wrn = 1'b1; 
                mem_access_address_bus = 16'd0;
                mem_access_data_out_bus = 32'd0;
            end
        endcase
    end


    //********************
    // Register Write Back
    //********************
    
    // ensure the reg_rd_wrn flag is low only when register write-back occurs
    assign reg_rd_wrn = (reg_wb_flag_3c) ? 1'b0 : 1'b1;

    // decode the word/halfword/byte, signed/unsigned indicator bus 
    always @(*) begin
        case (reg_wb_data_type_3c) 
            3'b000 : begin   // WORD
                mem_data_adjusted = mem_data_1c;
            end
            3'b001 : begin   // UNSIGNED HALFWORD
                mem_data_adjusted = {16'd0, mem_data_1c[15:0]};
            end
            3'b010 : begin   // SIGNED HALFWORD
                mem_data_adjusted = {{16{mem_data_1c[15]}}, $signed(mem_data_1c[15:0])};
            end
            3'b011 : begin   // UNSIGNED BYTE
                mem_data_adjusted = {24'd0, mem_data_1c[7:0]};
            end
            3'b100 : begin   // SIGNED BYTE
                mem_data_adjusted = {{24{mem_data_1c[7]}}, $signed(mem_data_1c[7:0])};
            end
            default : begin
                mem_data_adjusted = 32'd0;
            end
        endcase
    end

    always @(*) begin
        // only proceed if the reg_wb_flag flag is high (up to the correct stage in the pipeline)
        if(reg_wb_flag_3c) begin   // write the data read from either memory or ALU to the value stored in rd_reg_offset_3c
            rd_reg_offset = rd_reg_offset_3c;
            // check whether write value is ALU ouput (math/logical instruction) or memory output (load/store instruction)
            reg_data_in = alu_mem_operation_n_3c ? alu_out_reg_1c : mem_data_adjusted;
        end
        else begin
            // address the zero register r0, no write operation will occur
            rd_reg_offset = 5'd0;
            reg_data_in = 32'd0;
        end
    end

    // EBREAK instruction has finished travelling down the pipeline, ready to be fired
    assign breakpoint_fired    = breakpoint_flag_3c;
    // single step instruction flag
    assign instruction_retired = (instruction_pointer_reg_4c != 7'd0);
    // fire finish program signal
    assign finish_exec_signal = finish_exec_flag_3c;

    assign DMEM_READ_WRN = mem_access_read_wrn;    
    assign DMEM_ADDRESS_BUS = mem_access_address_bus;
    assign DMEM_DATA_OUT_BUS = mem_access_data_out_bus;
    assign IMEM_ADDRESS_BUS = pc_data_out;
        
endmodule

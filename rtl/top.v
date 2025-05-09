`timescale 1ns / 1ps
// `include "riscv-cpu/rtl/defines.v"
`include "rtl/defines.v"

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
    input wire halt,     // halt the CPU pipeline
    input wire [31:0] INST_MEM_DATA_BUS,    // current instruction
    input wire [31:0] MEM_ACCESS_DATA_IN_BUS,    // RAM register block data input bus

    output wire [31:0] INST_MEM_ADDRESS_BUS,   // address bus driving the code memory, direct output of PC
    output wire MEM_ACCESS_READ_WRN,    // control signal to RAM register block indicating whether a read or write
    output wire [15:0] MEM_ACCESS_ADDRESS_BUS,    // RAM register block address bus
    output wire [31:0] MEM_ACCESS_DATA_OUT_BUS    // RAM register block data output bus
    );
        
    // local signals
    wire int_rst_n;
    // instruction fetch
    reg [31:0] program_counter_reg, instruction_pointer_reg, instruction_pointer_reg_1c;
    wire decode_pulse;
    // register file
    wire reg_rd_wrn;
    reg  [31:0] reg_data_in;
    wire [31:0] rs1_data_out, rs2_data_out;
    wire [31:0] pc_data_out, ir_data_out;
    wire freeze_pc;
    reg update_pc_3c, update_pc_2c, update_pc_1c;
    // alu
    reg  [31:0] alu_input_a_reg, alu_input_b_reg;
    wire [31:0] alu_input_a, alu_input_b;
    wire [31:0] alu_output;
    reg  [3:0]  alu_operation_code_reg;
    wire [3:0]  alu_operation_code;
    wire [31:0] alu_out_comb;
    reg alu_en_reg;
    wire alu_en;
    wire alu_carry_flag;
    wire alu_zero_flag;
    wire alu_overflow_flag;
    wire alu_done;
    // memory access
    reg [1:0] mem_access_operation_2c, mem_access_operation_1c, mem_access_operation_next;
    reg mem_access_read_wrn;
    reg [15:0] mem_access_address_bus;
    reg [31:0] mem_access_data_out_bus;
    reg [31:0] mem_data_1c, mem_data_next;
    reg mem_access_done;
    reg [31:0] mem_access_data_out_bus_adjusted;
    // register write back and operand forwarding
    reg [4:0] rd_reg_offset_3c, rd_reg_offset_2c, rd_reg_offset_1c;
    reg reg_wb_flag_3c, reg_wb_flag_2c, reg_wb_flag_1c, reg_wb_flag_next;
    reg alu_mem_operation_n_3c, alu_mem_operation_n_2c, alu_mem_operation_n_1c, alu_mem_operation_n_next;
    reg [31:0] alu_out_reg_2c, alu_out_reg_1c, alu_out_reg_next;
    reg [2:0] reg_wb_data_type_next, reg_wb_data_type_3c, reg_wb_data_type_2c, reg_wb_data_type_1c;
    reg [31:0] alu_out_reg_adjusted;
    reg [31:0] mem_data_adjusted;
    reg [31:0] rs2_data_out_2c, rs2_data_out_1c, rs2_data_out_next;
    reg [4:0]  rs1_reg_offset, rs2_reg_offset, rd_reg_offset;
    reg [31:0] rd_reg_data_1c;

    // wires for the instruction decoder
    wire        update_pc_next;
    wire [4:0]  rd_reg_offset_next;
    wire [3:0]  alu_operation_code_reg;
    wire [1:0]  mem_access_operation_next;
    wire        alu_mem_operation_n_next;
    wire        reg_wb_flag_next;
    wire [2:0]  reg_wb_data_type_next;
    wire [31:0] rs2_data_out_next;

    assign alu_input_a = alu_input_a_reg;
    assign alu_input_b = alu_input_b_reg;
    assign alu_operation_code = alu_operation_code_reg;
    assign alu_en = alu_en_reg;
    assign int_rst_n = rst_n;
    
    // if we get any kind of jump instruction, then we need to freeze the value of the PC.
    // Read the instruction straight from DMEM, we have to do this before we even latch the instruction
    // since it would be too late by then, and the PC would have already advanced to the next address.
    assign freeze_pc = (INST_MEM_DATA_BUS[6:0] == 7'b110_1111);

    // instantiate sub-modules
    reg_file u_reg_file (
        .clk(clk), .rst_n(rst_n), .reg_rd_wrn(reg_rd_wrn), .rs1_reg_offset(rs1_reg_offset), 
        .rs2_reg_offset(rs2_reg_offset), .rd_reg_offset(rd_reg_offset), .reg_data_in(reg_data_in), 
        .rs1_data_out(rs1_data_out), .rs2_data_out(rs2_data_out), .pc_data_out(pc_data_out), .update_pc(update_pc_3c),
        .freeze_pc(freeze_pc), .halt(halt)
    );

    alu u_alu (
        .clk(clk), .rst_n(rst_n), .alu_en(alu_en), .op_val(alu_operation_code),
        .operand_a(alu_input_a), .operand_b(alu_input_b), .out(alu_output), .carry_flag(alu_carry_flag),
        .zero_flag(alu_zero_flag), .overflow_flag(alu_overflow_flag), .alu_done(alu_done), .halt(halt), .out_comb(alu_out_comb)
    );
    
    // Sequential Processes

    always @(posedge clk, negedge int_rst_n) begin
        if(!int_rst_n) begin
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

            alu_out_reg_2c <= 32'h0000_0000;
            alu_out_reg_1c <= 32'h0000_0000;
            mem_data_1c <= 32'h0000_0000;
            mem_access_operation_2c <= 2'b00;
            mem_access_operation_1c <= 2'b00;

            update_pc_3c <= 1'b0;
            update_pc_2c <= 1'b0;
            update_pc_1c <= 1'b0;
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

                mem_data_1c <= MEM_ACCESS_DATA_IN_BUS;
                alu_out_reg_2c <= alu_out_reg_1c;
                alu_out_reg_1c <= alu_out_reg_next;

                update_pc_3c <= update_pc_2c;
                update_pc_2c <= update_pc_1c;
                update_pc_1c <= update_pc_next;
            end
        end
    end


    //************************
    // Instruction Fetch Stage
    //************************

    // IR register sequential process, using a SYNCHRONOUS reset here (TODO: figure out if this is an issue)
    always @(posedge clk) begin
        if(!rst_n) begin 
            instruction_pointer_reg    <= 32'd0;
            instruction_pointer_reg_1c <= 32'd0;
        end
        else begin
            instruction_pointer_reg    <= INST_MEM_DATA_BUS;
            instruction_pointer_reg_1c <= instruction_pointer_reg;
        end
    end

    // the delayed version of the instruction will be equal to the instantaneous value during PC freezing (jal for example)
    // this creates a one-cycle pulse needed on update_pc_next
    assign decode_pulse = (instruction_pointer_reg != instruction_pointer_reg_1c);

    //*************************
    // Instruction Decode Stage
    //*************************
    
    // given the current instruction, decode the relevant fields and pass out the control signals to the top level
    instruction_decode u_inst_decode(
        .clk(clk), .rst_n(rst_n),
        .instruction_pointer_reg(instruction_pointer_reg), .rs1_data_out(rs1_data_out), .rs2_data_out(rs2_data_out),
        .update_pc_next(update_pc_next), .rd_reg_offset_next(rd_reg_offset_next),
        .rs1_reg_offset(rs1_reg_offset), .rs2_reg_offset(rs2_reg_offset), .alu_input_a_reg(alu_input_a_reg),
        .alu_input_b_reg(alu_input_b_reg), .alu_operation_code_reg(alu_operation_code_reg), .mem_access_operation_next(mem_access_operation_next),
        .alu_mem_operation_n_next(alu_mem_operation_n_next), .reg_wb_flag_next(reg_wb_flag_next), .reg_wb_data_type_next(reg_wb_data_type_next), 
        .rs2_data_out_next(rs2_data_out_next), .alu_out_comb(alu_out_comb), .alu_output(alu_output),
        .rd_reg_offset_1c(rd_reg_offset_1c), .rd_reg_offset_2c(rd_reg_offset_2c), .rd_reg_offset_3c(rd_reg_offset_3c),
        .alu_out_reg_1c(alu_out_reg_1c), .alu_out_reg_2c(alu_out_reg_2c), .decode_pulse(decode_pulse)
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
                mem_access_data_out_bus_adjusted = $signed(rs2_data_out_2c[15:0]);
            end
            3'b100 : begin   // SIGNED BYTE
                mem_access_data_out_bus_adjusted = $signed(rs2_data_out_2c[7:0]);
            end
            default : begin
                mem_access_data_out_bus_adjusted = 32'hDEAD_BEEF; //TODO: replace with 32'd0
            end
        endcase
    end

    always @(*) begin
        // only proceed if the alu_done flag is high (up to the correct stage in the pipeline)
        if(alu_done) begin
            case (mem_access_operation_2c) 
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
    assign reg_rd_wrn = (reg_wb_flag_3c) ? 1'b0 : 1'b1;

    // decode the word/halfword/byte, signed/unsigned indicator bus 
    always @(*) begin
        case (reg_wb_data_type_3c) 
            3'b000 : begin   // WORD
                mem_data_adjusted = mem_data_1c;
            end
            3'b001 : begin   // UNSIGNED HALFWORD
                mem_data_adjusted = mem_data_1c[15:0];
            end
            3'b010 : begin   // SIGNED HALFWORD
                mem_data_adjusted = $signed(mem_data_1c[15:0]);
            end
            3'b011 : begin   // UNSIGNED BYTE
                mem_data_adjusted = mem_data_1c[7:0];
            end
            3'b100 : begin   // SIGNED BYTE
                mem_data_adjusted = $signed(mem_data_1c[7:0]);
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

    assign MEM_ACCESS_READ_WRN = mem_access_read_wrn;    
    assign MEM_ACCESS_ADDRESS_BUS = mem_access_address_bus;
    assign MEM_ACCESS_DATA_OUT_BUS = mem_access_data_out_bus;
    assign INST_MEM_ADDRESS_BUS = pc_data_out;
        
endmodule

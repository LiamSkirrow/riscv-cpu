`timescale 1ns/1ns

module Control_Unit_tb();

  //input registers
  reg RST_N, CK_REF;
  reg [31:0] INST_MEM_DATA_BUS, MEM_ACCESS_DATA_IN_BUS;

  wire MEM_ACCESS_READ_WRN;    // control signal to RAM register block indicating whether a read or write
  wire [15:0] MEM_ACCESS_ADDRESS_BUS;    // RAM register block address bus
  wire [31:0] MEM_ACCESS_DATA_OUT_BUS;
  
  //miscellaneous
  reg [8*60:1] TEST_STRING;
  
  Control_Unit inst_cont_unit (
    .CK_REF(CK_REF), .RST_N(RST_N), .INST_MEM_DATA_BUS(INST_MEM_DATA_BUS), .MEM_ACCESS_DATA_IN_BUS(MEM_ACCESS_DATA_IN_BUS),
    .MEM_ACCESS_READ_WRN(MEM_ACCESS_READ_WRN), .MEM_ACCESS_ADDRESS_BUS(MEM_ACCESS_ADDRESS_BUS),
    .MEM_ACCESS_DATA_OUT_BUS(MEM_ACCESS_DATA_OUT_BUS)
  );
     
localparam CK_PERIOD = 8;  // 125MHz 

always #(CK_PERIOD/2) CK_REF = !CK_REF;

initial
  begin    
    //Setup initial conditions/settings    
    RST_N = 1'b0; CK_REF = 1'b0;
    TEST_STRING="Reset";
    
    #(CK_PERIOD-2) RST_N = 1'b1; //deassert reset (halfway through a clock phase - all transitions now align here
    #(CK_PERIOD);
    INST_MEM_DATA_BUS = 32'b000000000011_00010_010_00001_0000011;
    #(CK_PERIOD);
    INST_MEM_DATA_BUS = 32'b000000000001_00001_010_00010_0000011;
    #(CK_PERIOD);
    INST_MEM_DATA_BUS = 32'b000000000001_00001_010_00011_0000011;
    MEM_ACCESS_DATA_IN_BUS = 32'h0000_0001;
    #(CK_PERIOD);
    INST_MEM_DATA_BUS = 32'b000000000001_00001_010_00100_0000011;
    MEM_ACCESS_DATA_IN_BUS = 32'h0000_0002;
    #(CK_PERIOD); // first instruction has written back
    MEM_ACCESS_DATA_IN_BUS = 32'h0000_0003;
    #(CK_PERIOD); // second instruction has written back
    MEM_ACCESS_DATA_IN_BUS = 32'h0000_0004;
    #(CK_PERIOD);
    #(CK_PERIOD);
        
    $finish;
    end
endmodule

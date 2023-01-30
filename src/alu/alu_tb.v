`timescale 1ns/1ns

module alu_tb();

  //FDD input registers
  reg RST_N, CK_REF, ALU_EN;
  reg [31:0] A, B;
  reg [3:0] OP_VAL;
  wire ZERO_FLAG, CARRY_FLAG, OVERFLOW_FLAG, ALU_DONE;
  wire [31:0] OUT;
  

  //miscellaneous
  reg [8*60:1] TEST_STRING;
  
  alu u_alu (
    .CK_REF(CK_REF), .RST_N(RST_N), .ALU_EN(ALU_EN), .OP_VAL(OP_VAL), .A(A), .B(B), .OUT(OUT), .CARRY_FLAG(CARRY_FLAG),
    .ZERO_FLAG(ZERO_FLAG), .OVERFLOW_FLAG(OVERFLOW_FLAG), .ALU_DONE(ALU_DONE)
  );
     
localparam CK_PERIOD = 8;  // 125MHz 

always #(CK_PERIOD/2) CK_REF = !CK_REF;

initial
  begin
    
    //Setup initial conditions/settings    
    RST_N = 1'b0; CK_REF = 1'b0; ALU_EN = 1'b0; A = 32'd0; B = 32'd0; OP_VAL = 4'd0;
    TEST_STRING="Reset";
    
    #(CK_PERIOD-2) RST_N = 1'b1; //deassert reset (halfway through a clock phase - all transitions now align here
    #(2*CK_PERIOD);
    
    TEST_STRING="Perform an addition operation";
    A = 32'd5; B = 32'd6; OP_VAL = 4'b0001;
    #(CK_PERIOD);
//    #(CK_PERIOD);
    TEST_STRING="Z = 11";
//    #(CK_PERIOD);
    
    TEST_STRING="Perform an addition operation";
    A = 32'd15; B = 32'd100; OP_VAL = 4'b0001;
    #(CK_PERIOD);
//    #(CK_PERIOD);
    TEST_STRING="Z = 115";
//    #(CK_PERIOD);
    
    TEST_STRING="Perform an addition operation";
    A = 32'b1111_1111_1111_1111_1111_1111_1111_1111; 
    B = 32'b0000_0000_0000_0000_0000_0000_0000_0001; 
    OP_VAL = 4'b0001;
    #(CK_PERIOD);
//    #(CK_PERIOD);
    TEST_STRING="Z = 0, Carry = 1, Zero = 1";
//    #(CK_PERIOD);
    
    TEST_STRING="Perform an addition operation";
    A = 32'd9000; B = 32'd8192; OP_VAL = 4'b0001;
    #(CK_PERIOD);
//    #(CK_PERIOD);
    TEST_STRING="Z = 17,192, Carry = 0, Zero = 0";
    #(CK_PERIOD);


    $finish;
    end
endmodule

`timescale 1ns/1ns

module Top_CPU_tb();

  //input registers
  reg RST_N, CK_REF;

  //miscellaneous
  reg [8*60:1] TEST_STRING;
  
  Top_CPU inst_top_cpu (
    .CK_REF(CK_REF), .RST_N(RST_N)
  );
     
localparam CK_PERIOD = 8;  // 125MHz 

always #(CK_PERIOD/2) CK_REF = !CK_REF;

initial
  begin    
    //Setup initial conditions/settings    
    RST_N = 1'b0; CK_REF = 1'b0;
    TEST_STRING="Reset";
    
    #(CK_PERIOD-2) RST_N = 1'b1; //deassert reset (halfway through a clock phase - all transitions now align here
    
    // more clocks than needed to execute through the rest of memory
    #(50*CK_PERIOD);

    $finish;
    end
endmodule

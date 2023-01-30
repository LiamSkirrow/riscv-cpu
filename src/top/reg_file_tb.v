`timescale 1ns/1ns

module reg_file_tb();

    reg RST_N, CK_REF, REG_RD_WRN;
    reg [4:0] RS1_REG_OFFSET, RS2_REG_OFFSET, RD_REG_OFFSET;
    reg [31:0] REG_DATA_IN;
    
    wire [31:0] RS1_DATA_OUT, RS2_DATA_OUT, DEBUG_OUT;

    //miscellaneous
    reg [8*60:1] TEST_STRING;
  
    Register_File u_reg_file (
     .CK_REF(CK_REF), .RST_N(RST_N), .REG_RD_WRN(REG_RD_WRN), .RS1_REG_OFFSET(RS1_REG_OFFSET), .RS2_REG_OFFSET(RS2_REG_OFFSET), 
     .RD_REG_OFFSET(RD_REG_OFFSET), .REG_DATA_IN(REG_DATA_IN), .RS1_DATA_OUT(RS1_DATA_OUT), .RS2_DATA_OUT(RS2_DATA_OUT)
    );
     
localparam CK_PERIOD = 8;  // 125MHz 

always #(CK_PERIOD/2) CK_REF = !CK_REF;

initial
  begin
    
    //Setup initial conditions/settings    
    RST_N = 1'b0; CK_REF = 1'b0; REG_RD_WRN = 1'b0; RS1_REG_OFFSET = 5'd0; RS2_REG_OFFSET = 5'd0; RD_REG_OFFSET = 5'd0;
    REG_DATA_IN = 32'd0; 
    TEST_STRING="Reset";
    
    #(CK_PERIOD-2) RST_N = 1'b1; //deassert reset (halfway thru a clock phase - all transitions now align here
    #(2*CK_PERIOD);
    
    TEST_STRING="Write to register file";
    RD_REG_OFFSET = 5'd00; REG_DATA_IN = 32'hFFFF_FFFF; REG_RD_WRN = 1'b0;
    #(2*CK_PERIOD);
    
    TEST_STRING="Read from register file, should be all zeros";
    RS1_REG_OFFSET = 5'd00; REG_RD_WRN = 1'b1; RS2_REG_OFFSET = 5'd0;
    #(2*CK_PERIOD);
    
    TEST_STRING="Write to register file";
    RD_REG_OFFSET = 5'd01; REG_DATA_IN = 32'hFFFF_FFFF; REG_RD_WRN = 1'b0;
    #(2*CK_PERIOD);
    
    TEST_STRING="Read from register file";
    RS1_REG_OFFSET = 5'd01; REG_RD_WRN = 1'b1; RS2_REG_OFFSET = 5'd1;
    #(2*CK_PERIOD);
    
    TEST_STRING="Write to register file";
    RD_REG_OFFSET = 5'd02; REG_DATA_IN = 32'hFFFF_FFFF; REG_RD_WRN = 1'b0;
    #(2*CK_PERIOD);
    
    TEST_STRING="Read from register file";
    RS1_REG_OFFSET = 5'd02; REG_RD_WRN = 1'b1; RS2_REG_OFFSET = 5'd2;
    #(2*CK_PERIOD);
    
    TEST_STRING="Write to register file";
    RD_REG_OFFSET = 5'd03; REG_DATA_IN = 32'hFFFF_FFFF; REG_RD_WRN = 1'b0;
    #(2*CK_PERIOD);
    
    TEST_STRING="Read from register file";
    RS1_REG_OFFSET = 5'd03; REG_RD_WRN = 1'b1; RS2_REG_OFFSET = 5'd3;
    #(2*CK_PERIOD);
    
    TEST_STRING="Write to register file";
    RD_REG_OFFSET = 5'd04; REG_DATA_IN = 32'hFFFF_FFFF; REG_RD_WRN = 1'b0;
    #(2*CK_PERIOD);
    
    TEST_STRING="Read from register file";
    RS1_REG_OFFSET = 5'd04; REG_RD_WRN = 1'b1; RS2_REG_OFFSET = 5'd4;
    #(2*CK_PERIOD);
    
    TEST_STRING="Write to register file";
    RD_REG_OFFSET = 5'd05; REG_DATA_IN = 32'hFFFF_FFFF; REG_RD_WRN = 1'b0;
    #(2*CK_PERIOD);
    
    TEST_STRING="Read from register file";
    RS1_REG_OFFSET = 5'd05; REG_RD_WRN = 1'b1; RS2_REG_OFFSET = 5'd5;
    #(2*CK_PERIOD);
    
    TEST_STRING="Write to register file";
    RD_REG_OFFSET = 5'd06; REG_DATA_IN = 32'hFFFF_FFFF; REG_RD_WRN = 1'b0;
    #(2*CK_PERIOD);
    
    TEST_STRING="Read from register file";
    RS1_REG_OFFSET = 5'd06; REG_RD_WRN = 1'b1; RS2_REG_OFFSET = 5'd6;
    #(2*CK_PERIOD);
    
    TEST_STRING="Write to register file";
    RD_REG_OFFSET = 5'd07; REG_DATA_IN = 32'hFFFF_FFFF; REG_RD_WRN = 1'b0;
    #(2*CK_PERIOD);
    
    TEST_STRING="Read from register file";
    RS1_REG_OFFSET = 5'd07; REG_RD_WRN = 1'b1; RS2_REG_OFFSET = 5'd7;
    #(2*CK_PERIOD);
    
    TEST_STRING="Write to register file";
    RD_REG_OFFSET = 5'd08; REG_DATA_IN = 32'hFFFF_FFFF; REG_RD_WRN = 1'b0;
    #(2*CK_PERIOD);
    
    TEST_STRING="Read from register file";
    RS1_REG_OFFSET = 5'd08; REG_RD_WRN = 1'b1; RS2_REG_OFFSET = 5'd8;
    #(2*CK_PERIOD);
    
    TEST_STRING="Write to register file";
    RD_REG_OFFSET = 5'd09; REG_DATA_IN = 32'hFFFF_FFFF; REG_RD_WRN = 1'b0;
    #(2*CK_PERIOD);
    
    TEST_STRING="Read from register file";
    RS1_REG_OFFSET = 5'd09; REG_RD_WRN = 1'b1; RS2_REG_OFFSET = 5'd9;
    #(2*CK_PERIOD);
    
    TEST_STRING="Write to register file";
    RD_REG_OFFSET = 5'd10; REG_DATA_IN = 32'hFFFF_FFFF; REG_RD_WRN = 1'b0;
    #(2*CK_PERIOD);
    
    TEST_STRING="Read from register file";
    RS1_REG_OFFSET = 5'd10; REG_RD_WRN = 1'b1; RS2_REG_OFFSET = 5'd10;
    #(2*CK_PERIOD);
    
    TEST_STRING="Write to register file";
    RD_REG_OFFSET = 5'd11; REG_DATA_IN = 32'hFFFF_FFFF; REG_RD_WRN = 1'b0;
    #(2*CK_PERIOD);
    
    TEST_STRING="Read from register file";
    RS1_REG_OFFSET = 5'd11; REG_RD_WRN = 1'b1; RS2_REG_OFFSET = 5'd11;
    #(2*CK_PERIOD);
    
    TEST_STRING="Write to register file";
    RD_REG_OFFSET = 5'd12; REG_DATA_IN = 32'hFFFF_FFFF; REG_RD_WRN = 1'b0;
    #(2*CK_PERIOD);
    
    TEST_STRING="Read from register file";
    RS1_REG_OFFSET = 5'd12; REG_RD_WRN = 1'b1; RS2_REG_OFFSET = 5'd12;
    #(2*CK_PERIOD);
    
    TEST_STRING="Write to register file";
    RD_REG_OFFSET = 5'd13; REG_DATA_IN = 32'hFFFF_FFFF; REG_RD_WRN = 1'b0;
    #(2*CK_PERIOD);
    
    TEST_STRING="Read from register file";
    RS1_REG_OFFSET = 5'd13; REG_RD_WRN = 1'b1; RS2_REG_OFFSET = 5'd13;
    #(2*CK_PERIOD);
    
    TEST_STRING="Write to register file";
    RD_REG_OFFSET = 5'd14; REG_DATA_IN = 32'hFFFF_FFFF; REG_RD_WRN = 1'b0;
    #(2*CK_PERIOD);
    
    TEST_STRING="Read from register file";
    RS1_REG_OFFSET = 5'd14; REG_RD_WRN = 1'b1; RS2_REG_OFFSET = 5'd14;
    #(2*CK_PERIOD);
    
    TEST_STRING="Write to register file";
    RD_REG_OFFSET = 5'd15; REG_DATA_IN = 32'hFFFF_FFFF; REG_RD_WRN = 1'b0;
    #(2*CK_PERIOD);
    
    TEST_STRING="Read from register file";
    RS1_REG_OFFSET = 5'd15; REG_RD_WRN = 1'b1; RS2_REG_OFFSET = 5'd15;
    #(2*CK_PERIOD);
    
    TEST_STRING="Write to register file";
    RD_REG_OFFSET = 5'd16; REG_DATA_IN = 32'hFFFF_FFFF; REG_RD_WRN = 1'b0;
    #(2*CK_PERIOD);
    
    TEST_STRING="Read from register file";
    RS1_REG_OFFSET = 5'd16; REG_RD_WRN = 1'b1; RS2_REG_OFFSET = 5'd16;
    #(2*CK_PERIOD);
    
    TEST_STRING="Write to register file";
    RD_REG_OFFSET = 5'd17; REG_DATA_IN = 32'hFFFF_FFFF; REG_RD_WRN = 1'b0;
    #(2*CK_PERIOD);
    
    TEST_STRING="Read from register file";
    RS1_REG_OFFSET = 5'd17; REG_RD_WRN = 1'b1; RS2_REG_OFFSET = 5'd17;
    #(2*CK_PERIOD);
    
    TEST_STRING="Write to register file";
    RD_REG_OFFSET = 5'd18; REG_DATA_IN = 32'hFFFF_FFFF; REG_RD_WRN = 1'b0;
    #(2*CK_PERIOD);
    
    TEST_STRING="Read from register file";
    RS1_REG_OFFSET = 5'd18; REG_RD_WRN = 1'b1; RS2_REG_OFFSET = 5'd18;
    #(2*CK_PERIOD);
    
    TEST_STRING="Write to register file";
    RD_REG_OFFSET = 5'd19; REG_DATA_IN = 32'hFFFF_FFFF; REG_RD_WRN = 1'b0;
    #(2*CK_PERIOD);
    
    TEST_STRING="Read from register file";
    RS1_REG_OFFSET = 5'd19; REG_RD_WRN = 1'b1; RS2_REG_OFFSET = 5'd19;
    #(2*CK_PERIOD);
    
    TEST_STRING="Write to register file";
    RD_REG_OFFSET = 5'd20; REG_DATA_IN = 32'hFFFF_FFFF; REG_RD_WRN = 1'b0;
    #(2*CK_PERIOD);
    
    TEST_STRING="Read from register file";
    RS1_REG_OFFSET = 5'd20; REG_RD_WRN = 1'b1; RS2_REG_OFFSET = 5'd20;
    #(2*CK_PERIOD);
    
    TEST_STRING="Write to register file";
    RD_REG_OFFSET = 5'd21; REG_DATA_IN = 32'hFFFF_FFFF; REG_RD_WRN = 1'b0;
    #(2*CK_PERIOD);
    
    TEST_STRING="Read from register file";
    RS1_REG_OFFSET = 5'd21; REG_RD_WRN = 1'b1; RS2_REG_OFFSET = 5'd21;
    #(2*CK_PERIOD);
    
    TEST_STRING="Write to register file";
    RD_REG_OFFSET = 5'd22; REG_DATA_IN = 32'hFFFF_FFFF; REG_RD_WRN = 1'b0;
    #(2*CK_PERIOD);
    
    TEST_STRING="Read from register file";
    RS1_REG_OFFSET = 5'd22; REG_RD_WRN = 1'b1; RS2_REG_OFFSET = 5'd22;
    #(2*CK_PERIOD);
    
    TEST_STRING="Write to register file";
    RD_REG_OFFSET = 5'd23; REG_DATA_IN = 32'hFFFF_FFFF; REG_RD_WRN = 1'b0;
    #(2*CK_PERIOD);
    
    TEST_STRING="Read from register file";
    RS1_REG_OFFSET = 5'd23; REG_RD_WRN = 1'b1; RS2_REG_OFFSET = 5'd23;
    #(2*CK_PERIOD);
    
    TEST_STRING="Write to register file";
    RD_REG_OFFSET = 5'd24; REG_DATA_IN = 32'hFFFF_FFFF; REG_RD_WRN = 1'b0;
    #(2*CK_PERIOD);
    
    TEST_STRING="Read from register file";
    RS1_REG_OFFSET = 5'd24; REG_RD_WRN = 1'b1; RS2_REG_OFFSET = 5'd24;
    #(2*CK_PERIOD);
    
    TEST_STRING="Write to register file";
    RD_REG_OFFSET = 5'd25; REG_DATA_IN = 32'hFFFF_FFFF; REG_RD_WRN = 1'b0;
    #(2*CK_PERIOD);
    
    TEST_STRING="Read from register file";
    RS1_REG_OFFSET = 5'd25; REG_RD_WRN = 1'b1; RS2_REG_OFFSET = 5'd25;
    #(2*CK_PERIOD);
    
    TEST_STRING="Write to register file";
    RD_REG_OFFSET = 5'd26; REG_DATA_IN = 32'hFFFF_FFFF; REG_RD_WRN = 1'b0;
    #(2*CK_PERIOD);
    
    TEST_STRING="Read from register file";
    RS1_REG_OFFSET = 5'd26; REG_RD_WRN = 1'b1; RS2_REG_OFFSET = 5'd26;
    #(2*CK_PERIOD);
    
    TEST_STRING="Write to register file";
    RD_REG_OFFSET = 5'd27; REG_DATA_IN = 32'hFFFF_FFFF; REG_RD_WRN = 1'b0;
    #(2*CK_PERIOD);
    
    TEST_STRING="Read from register file";
    RS1_REG_OFFSET = 5'd27; REG_RD_WRN = 1'b1; RS2_REG_OFFSET = 5'd27;
    #(2*CK_PERIOD);
    
    TEST_STRING="Write to register file";
    RD_REG_OFFSET = 5'd28; REG_DATA_IN = 32'hFFFF_FFFF; REG_RD_WRN = 1'b0;
    #(2*CK_PERIOD);
    
    TEST_STRING="Read from register file";
    RS1_REG_OFFSET = 5'd28; REG_RD_WRN = 1'b1; RS2_REG_OFFSET = 5'd28;
    #(2*CK_PERIOD);
    
    TEST_STRING="Write to register file";
    RD_REG_OFFSET = 5'd29; REG_DATA_IN = 32'hFFFF_FFFF; REG_RD_WRN = 1'b0;
    #(2*CK_PERIOD);
    
    TEST_STRING="Read from register file";
    RS1_REG_OFFSET = 5'd29; REG_RD_WRN = 1'b1; RS2_REG_OFFSET = 5'd29;
    #(2*CK_PERIOD);
    
    TEST_STRING="Write to register file";
    RD_REG_OFFSET = 5'd30; REG_DATA_IN = 32'hFFFF_FFFF; REG_RD_WRN = 1'b0;
    #(2*CK_PERIOD);
    
    TEST_STRING="Read from register file";
    RS1_REG_OFFSET = 5'd30; REG_RD_WRN = 1'b1; RS2_REG_OFFSET = 5'd30;
    #(2*CK_PERIOD);
    
    TEST_STRING="Write to register file";
    RD_REG_OFFSET = 5'd31; REG_DATA_IN = 32'hFFFF_FFFF; REG_RD_WRN = 1'b0;
    #(2*CK_PERIOD);
    
    TEST_STRING="Read from register file";
    RS1_REG_OFFSET = 5'd31; REG_RD_WRN = 1'b1; RS2_REG_OFFSET = 5'd31;
    #(2*CK_PERIOD);
    


    $finish;
    end
endmodule

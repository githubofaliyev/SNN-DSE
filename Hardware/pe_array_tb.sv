`timescale 1ns / 1ps
module tb;

    logic clk, rst;    
    pe_array syst_arr(clk, rst);
    
    int cycle_cnt = 0;
    always begin
        #10 clk = ~clk;
    end  
    
    always @(posedge clk) begin
      cycle_cnt = cycle_cnt + 1;
    end
  
    initial begin
        clk = 0;
        rst = 1;
        #20 rst = 0;

        // end simulation
        //#1000 $finish;
    end

endmodule

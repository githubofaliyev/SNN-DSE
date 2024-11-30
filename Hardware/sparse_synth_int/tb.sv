`timescale 1ns / 1ps

module tb;

  localparam CONV_1_1_INPUT_FRAME_WIDTH = 32;
  localparam CONV_1_1_INPUT_CHANNELS = 3;
  localparam CONV_1_1_OUTPUT_CHANNELS = 64;
  localparam CONV_1_1_KERNEL_SIZE = 3;
  localparam CONV_1_1_INPUT_FRAME_SIZE = CONV_1_1_INPUT_FRAME_WIDTH*CONV_1_1_INPUT_FRAME_WIDTH;
  //localparam model_dir = "C:/Users/jlopezramos/Desktop/VivadoProjects/Models/INT4_S2_{2_56_48_27_30_28_10_8_10}";
  //localparam model_dir = "C:/Users/jlopezramos/Desktop/Vivado Projects/Models/FP32_S2_{1_56_48_27_30_28_10_4_5}";
  logic clk = 0;
  logic rst = 0;
  logic input_avail = 0;

  top_wrapper #( 
    .CONV_1_1_OUTPUT_CHANNELS(CONV_1_1_OUTPUT_CHANNELS), .CONV_1_1_KERNEL_SIZE(CONV_1_1_KERNEL_SIZE), 
    .CONV_1_1_INPUT_FRAME_WIDTH(CONV_1_1_INPUT_FRAME_WIDTH)) // .model_dir(model_dir))
  top_wrapper (
    .clk(clk), .rst(rst),
    .input_avail(input_avail),
    .conv_1_1_avail(layer_1_1_avail)
  );
  // clock generation
  always begin
    #10 clk = ~clk;
  end  
  
    integer unsigned cycle_cnt = 0;
    
    always @(posedge clk) begin
      cycle_cnt = cycle_cnt + 1;
    end
     
  initial begin
    // reset
    rst = 1;
    #30 rst = 0;
    #20 input_avail = 1;
    #400 input_avail = 0;
    #100000;

    // end simulation
    //#1000 $finish;
  end


endmodule

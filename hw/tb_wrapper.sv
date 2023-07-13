`timescale 1ns / 1ps

module tb;

  localparam EC_UNIT_SIZE = 4;
  localparam LAYER_SIZE = 16;
  localparam PRE_SYN_LAYER_SIZE = 32;
  localparam NEURAL_UNIT_SIZE = LAYER_SIZE/EC_UNIT_SIZE;
  localparam SPARSE_SIZE = PRE_SYN_LAYER_SIZE/2;
  localparam NEURAL_LAT = 3;
  localparam TIME_STEPS = 6;
  localparam FIXED_POINT_WIDTH = 32; // Total width is 32 bits
  localparam INTEGER_WIDTH = 2; // We have 2 bits for the integer part
  localparam FRACTIONAL_WIDTH = 30; // And 30 bits for the fractional part
  localparam BRAM_SIZE = NEURAL_UNIT_SIZE * PRE_SYN_LAYER_SIZE;
  localparam BRAM_ADDR_WIDTH = $clog2(BRAM_SIZE);  

  reg clk = 0;
  reg rst = 0;
  reg pre_synp_avail = 0;
  reg [PRE_SYN_LAYER_SIZE-1:0] pre_synpt_spk_train = 0; 
  wire layer_avail;
  reg [LAYER_SIZE-1:0] post_syn_spk;

  top_wrapper #(EC_UNIT_SIZE, LAYER_SIZE, PRE_SYN_LAYER_SIZE, NEURAL_UNIT_SIZE, SPARSE_SIZE, NEURAL_LAT, TIME_STEPS, FIXED_POINT_WIDTH, INTEGER_WIDTH, FRACTIONAL_WIDTH, BRAM_SIZE, BRAM_ADDR_WIDTH)
  top (
    .clk(clk),
    .rst(rst),
    .pre_synp_avail(pre_synp_avail),
    .pre_synpt_spk_train(pre_synpt_spk_train),
    .layer_avail(layer_avail),
    .post_syn_spk(post_syn_spk)
  );

  // clock generation
  always begin
    #10 clk = ~clk;
  end
  
  integer file_pointer;
  integer time_step = 0;  
     
  initial begin
    // reset
    rst = 1;
    #20 rst = 0;
    #20;
    // read spike trains from file
    file_pointer = $fopen("spike_file.txt", "r");
    if (file_pointer) begin
        while (!$feof(file_pointer)) begin
          @(posedge clk);
          if (layer_avail) begin
            if(time_step < TIME_STEPS) begin
                if (!$fscanf(file_pointer, "%b\n", pre_synpt_spk_train)) begin
                  $display("Error reading spike_file.txt at line %0d", time_step+1);
                  $finish;
                end
                time_step = time_step + 1;
                $display($time, " Spike from file is %b.", pre_synpt_spk_train);
                pre_synp_avail = 1;
                $display($time, " pre_synp_avail is enabled.");
                @(posedge clk);
                pre_synp_avail = 0;
                $display($time, " pre_synp_avail is disabled.");
            end
          end
        end
      $fclose(file_pointer);
    end 
    else begin
      $display("Error opening spike_file.txt");
      $finish;
    end

    // end simulation
    #1000 $finish;
  end

  initial begin
    // Monitor signals
    $monitor($time, " pre_synp_avail = %b, pre_synpt_spk_train = %b, layer_avail = %b", pre_synp_avail, pre_synpt_spk_train, layer_avail);
  end

endmodule

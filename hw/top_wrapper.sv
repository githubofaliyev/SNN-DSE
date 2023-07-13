module top_wrapper #(
    parameter EC_UNIT_SIZE = 16,
    parameter LAYER_SIZE = 1024,
    parameter PRE_SYN_LAYER_SIZE = 784,
    parameter NEURAL_UNIT_SIZE = LAYER_SIZE/EC_UNIT_SIZE,
    parameter SPARSE_SIZE = PRE_SYN_LAYER_SIZE/2,
    parameter NEURAL_LAT = 2,
    parameter TIME_STEPS = 4,
    parameter FIXED_POINT_WIDTH = 32,
    parameter INTEGER_WIDTH = 2,
    parameter FRACTIONAL_WIDTH = 30,
    parameter BRAM_DEPTH = NEURAL_UNIT_SIZE * PRE_SYN_LAYER_SIZE,
    parameter BRAM_ADDR_WIDTH = $clog2(BRAM_DEPTH),
    parameter POSITIVE_THRESHOLD = 32'b01000000000000000000000000000000,
    parameter BIAS = 32'b00001110111110011101101100100011,
    parameter BETA = 32'b00111001100110011001100110011010
) (
    input clk, rst,
    input pre_synp_avail,
    input [PRE_SYN_LAYER_SIZE-1:0] pre_synpt_spk_train,
    output wire layer_avail,
    output wire [LAYER_SIZE-1:0] post_syn_spk
);

  reg en_accum = 0;
  reg en_activ = 0;
  reg [BRAM_ADDR_WIDTH-1:0] bram_addr[EC_UNIT_SIZE-1:0];
  wire bram_en[EC_UNIT_SIZE-1:0];
  wire signed [FIXED_POINT_WIDTH-1:0] bram_rdat[EC_UNIT_SIZE-1:0];
  wire [EC_UNIT_SIZE-1:0][$clog2(PRE_SYN_LAYER_SIZE)-1:0] out_spk_addr_array;
  wire [EC_UNIT_SIZE-1:0][NEURAL_UNIT_SIZE-1:0] post_syn_spk_unit;
  
  event_control #(EC_UNIT_SIZE, LAYER_SIZE, SPARSE_SIZE, PRE_SYN_LAYER_SIZE, NEURAL_UNIT_SIZE, NEURAL_LAT, TIME_STEPS) 
  ec (
    .clk(clk),
    .rst(rst),
    .pre_synp_avail(pre_synp_avail),
    .pre_synpt_spk_train(pre_synpt_spk_train),
    .out_spk_addr_array(out_spk_addr_array),
    .layer_avail(layer_avail),
    .en_accum(en_accum),
    .en_activ(en_activ)
  );

generate
  for (genvar i=0; i<EC_UNIT_SIZE; i=i+1) begin : gen_neuron
    neural #(
        .NEURAL_SIZE(NEURAL_UNIT_SIZE),
        .PRE_SYN_LAYER_SIZE(PRE_SYN_LAYER_SIZE),
        .FIXED_POINT_WIDTH(FIXED_POINT_WIDTH),
        .INTEGER_WIDTH(INTEGER_WIDTH),
        .FRACTIONAL_WIDTH(FRACTIONAL_WIDTH),
        .BRAM_ADDR_WIDTH(BRAM_ADDR_WIDTH),
        .POSITIVE_THRESHOLD(POSITIVE_THRESHOLD),
        .BIAS(BIAS),
        .BETA(BETA)
    ) neural_i (
        .clk(clk),
        .rst(rst),
        .en_accum(en_accum),
        .en_activ(en_activ),
        .spk_addr(out_spk_addr_array[i]),
        .bram_rdat(bram_rdat[i]),
        .bram_addr(bram_addr[i]),
        .bram_en(bram_en[i]),
        .post_syn_spk(post_syn_spk_unit[i])
    );

    my_bram #(.BRAM_DEPTH(BRAM_DEPTH), .BRAM_ADDR_WIDTH(BRAM_ADDR_WIDTH), .FIXED_POINT_WIDTH(FIXED_POINT_WIDTH), 
    .FILENAME($sformatf("C:/Users/Ilkin/penc_test/penc_test.srcs/sim_1/new/weight_0_%0d_%0d.txt", i*NEURAL_UNIT_SIZE, i*NEURAL_UNIT_SIZE + NEURAL_UNIT_SIZE - 1)))
    bram_i (
      .clk(clk),
      .addr(bram_addr[i]),
      .bram_en(bram_en[i]),
      .data_out(bram_rdat[i])
    );

    assign post_syn_spk[i*NEURAL_UNIT_SIZE+:NEURAL_UNIT_SIZE] = post_syn_spk_unit[i];
  end
endgenerate

endmodule

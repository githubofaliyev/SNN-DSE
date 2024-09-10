`timescale 1ns / 1ps

module event_control_wrapper #(parameter EC_SIZE = 2048, parameter NEURAL_SIZE = 4, parameter NEURON_LAT = 4)
(
    input wire clk,
    input wire rst,
    input wire enable,
    output reg done
);

    // Define constants
    localparam NEURAL_SIZE = 4;
    localparam PRE_SYN_LAYER_SIZE = 8;
    localparam FIXED_POINT_WIDTH = 32; // Total width is 32 bits
    localparam INTEGER_WIDTH = 2; // We have 2 bits for the integer part
    localparam FRACTIONAL_WIDTH = 30; // And 30 bits for the fractional part
    localparam BRAM_SIZE = NEURAL_SIZE * PRE_SYN_LAYER_SIZE;
    localparam BRAM_ADDR_WIDTH = $clog2(BRAM_SIZE);

    logic post_synp_avail;
    logic [EC_SIZE-1:0] pre_synpt_spk;
    logic [EC_SIZE-1:0] neuron_spk;
    logic [EC_SIZE-1:0] post_synp_spk_buffer;
    logic [$clog2(EC_SIZE):0] shift_phase;
    logic en_accum;
    logic en_activ;
    logic activ_en, layer_activ;
    logic [$clog2(NEURAL_SIZE)-1:0] select_spk;
    
    logic [EC_SIZE/NEURAL_SIZE-1:0] bram_en;
    logic [9:0] bram_addr[EC_SIZE/NEURAL_SIZE-1:0];
    logic [31:0] bram_rdat[EC_SIZE/NEURAL_SIZE-1:0], wdat[EC_SIZE/NEURAL_SIZE-1:0];


    // Create an instance of event_control
    (* dont_touch = "true" *)
    event_control #(EC_SIZE, NEURAL_SIZE, NEURON_LAT, $clog2(EC_SIZE)) u_event_control (
        .clk(clk),
        .rst(rst),
        .post_synp_avail(post_synp_avail),
        .pre_synpt_spk(pre_synpt_spk),
        .neuron_spk(neuron_spk),
        .select_spk(select_spk),
        .post_synp_spk_buffer(post_synp_spk_buffer),
        .shift_phase(shift_phase),
        .en_accum(en_accum),
        .en_activ(en_activ)
    );
    
    generate
        for (genvar i=0; i<EC_SIZE; i=i+1) begin : gen_neuron

            neural #(
                .NEURAL_SIZE(NEURAL_SIZE),
                .PRE_SYN_LAYER_SIZE(PRE_SYN_LAYER_SIZE),
                .FIXED_POINT_WIDTH(FIXED_POINT_WIDTH),
                .INTEGER_WIDTH(INTEGER_WIDTH),
                .FRACTIONAL_WIDTH(FRACTIONAL_WIDTH),
                .BRAM_ADDR_WIDTH(BRAM_ADDR_WIDTH)
            ) neural_i (
                .clk(clk),
                .rst(rst),
                .en_accum(en_accum),
                .spk_addr(spk_addr),
                .bram_rdat(bram_rdat),
                .bram_addr(bram_addr),
                .bram_en(bram_en)
            );
    
          // Instance of BRAM for each neural module
          my_bram bram_i (
            .clk(clk),
            .addr(bram_addr[i]),
            .data_in(wdat[i]),
            .wr_en(bram_en[i]),
            .data_out(bram_rdat[i])
          );
        end
    endgenerate


    //(* dont_touch = "true" *) my_bram B0(.clk(clk), .addr(bram_addr), .data_in(wdat), .wr_en(bram_en), .data_out(bram_rdat));

    // Assign input and output signals
    always_ff @(posedge clk) begin
        if (rst) begin
            post_synp_avail <= '0;
            pre_synpt_spk <= '0;
            //neuron_spk <= '0;
            done <= 0;
        end
        else if (enable) begin
            post_synp_avail <= 1'b1;
            pre_synpt_spk <= {EC_SIZE{1'b1}};
            //neuron_spk <= {EC_SIZE{1'b1}};
        end
        if (en_activ && en_accum) begin
            done <= 1'b1;
            post_synp_avail <= '0;
            pre_synpt_spk <= '0;
            //neuron_spk <= '0;
        end
    end
    
    // Define the N-to-1 multiplexer function
    function automatic [$clog2(EC_SIZE)-1:0] muxNto1(input [$clog2(NEURAL_SIZE)-1:0] sel, input [$clog2(EC_SIZE)-1:0] in[NEURAL_SIZE-1:0]);
        for (integer i = 0; i < NEURAL_SIZE; i = i + 1) begin
            if (i == sel)
                muxNto1 = in[i];
        end
    endfunction

endmodule


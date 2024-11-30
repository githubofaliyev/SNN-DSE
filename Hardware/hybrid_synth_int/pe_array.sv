`timescale 1ns / 1ps

module pe_array #(    
    parameter IN_CHANNELS = 3,
    parameter OUT_CHANNELS = 2,
    parameter KERNEL_SIZE = 2,
    parameter BIT_WIDTH = 31,
    parameter PE_ARRAY_COL_SIZE = IN_CHANNELS*KERNEL_SIZE*KERNEL_SIZE,
    parameter PE_ARRAY_ROW_SIZE = 2,
    parameter w_sfactor = 0.24,
    parameter w_zpt = 0.24,
    parameter model_dir = "C:/Users/jlopezramos/Desktop/VivadoProjects/Models/dense_core_weights"
)
(   input wire clk, rst, transit,
    input logic [$clog2(OUT_CHANNELS):0] oc_phase,
    input logic [31:0] col0_in0[PE_ARRAY_COL_SIZE-1:0],
    output logic [31:0] d_out[PE_ARRAY_ROW_SIZE-1:0]
);

    // intermediate signals 
    logic [31:0] col0_out0[PE_ARRAY_COL_SIZE-1:0], col0_out1[PE_ARRAY_COL_SIZE-1:0];
    //logic [31:0] col1_out0[PE_ARRAY_COL_SIZE-1:0], col1_out1[PE_ARRAY_COL_SIZE-1:0];
    
    // instantiate a column of 27 PEs for 3 input channel 3x3 filter
    generate
        /*for(genvar i=0; i<PE_ARRAY_COL_SIZE; i++) begin : col_1
            if(i == 0) 
                pe #(.OUT_CHANNELS(OUT_CHANNELS), .WEIGHT_SIZE(OUT_CHANNELS/PE_ARRAY_ROW_SIZE),
                .w_sfactor(w_sfactor), .w_zpt(w_zpt), 
                .WEIGHT_FILENAME($sformatf("%s/pe%0d_1.txt", model_dir, i)))
                pe_col1_fm0(.clk(clk), .rst(rst), .transit(transit), .in0(col0_out0[i]), .in1(0),              
                .oc_phase(oc_phase), .out0(col1_out0[i]), .out1(col1_out1[i]));
            else
                pe #(.OUT_CHANNELS(OUT_CHANNELS), .WEIGHT_SIZE(OUT_CHANNELS/PE_ARRAY_ROW_SIZE),
                .w_sfactor(w_sfactor), .w_zpt(w_zpt), 
                .WEIGHT_FILENAME($sformatf("%s/pe%0d_1.txt", model_dir, i)))            
                pe_col1_fm0(.clk(clk), .rst(rst), .transit(transit), .in0(col0_out0[i]), .in1(col1_out1[i-1]), 
                .oc_phase(oc_phase), .out0(col1_out0[i]), .out1(col1_out1[i]));
        end*/        
        for(genvar i=0; i<PE_ARRAY_COL_SIZE; i++) begin : col_0
            if(i == 0) // first PE need 0 for its partial sum, rest PEs connect to upper PE's out1
                // first 27 weights + 1 bias are for the first feature map
                //pe #(.WEIGHT_FILENAME($sformatf("%s/weights/conv2_nc%0d.txt", model_dir, i)))
                pe #(.OUT_CHANNELS(OUT_CHANNELS), .WEIGHT_SIZE(OUT_CHANNELS/PE_ARRAY_ROW_SIZE),
                .w_sfactor(w_sfactor), .w_zpt(w_zpt), .BIT_WIDTH(BIT_WIDTH),
                .WEIGHT_FILENAME($sformatf("%s/pe%0d_0.txt", model_dir, i)))
                pe_col0_fm0(.clk(clk), .rst(rst), .transit(transit), .in0(col0_in0[i]), .in1(0),              
                .oc_phase(oc_phase), .out0(col0_out0[i]), .out1(col0_out1[i]));
            else
                pe #(.OUT_CHANNELS(OUT_CHANNELS), .WEIGHT_SIZE(OUT_CHANNELS/PE_ARRAY_ROW_SIZE),
                .w_sfactor(w_sfactor), .w_zpt(w_zpt), .BIT_WIDTH(BIT_WIDTH),
                .WEIGHT_FILENAME($sformatf("%s/pe%0d_0.txt", model_dir, i)))
                pe_col0_fm0(.clk(clk), .rst(rst), .transit(transit), .in0(col0_in0[i]), .in1(col0_out1[i-1]), 
                .oc_phase(oc_phase), .out0(col0_out0[i]), .out1(col0_out1[i]));
        end
    
    endgenerate

    assign d_out[0] = col0_out1[PE_ARRAY_COL_SIZE-1];
    //assign d_out[1] = col1_out1[PE_ARRAY_COL_SIZE-1];

endmodule

`timescale 1ns / 1ps

module dense_nc #(    
    parameter TIME_STEPS = 3,
    parameter IN_CHANNELS = 3,
    parameter OUT_CHANNELS = 16,
    parameter FRAME_WIDTH = 6,
    parameter KERNEL_SIZE = 3,
    parameter PE_ARRAY_COL_SIZE = IN_CHANNELS*KERNEL_SIZE*KERNEL_SIZE,
    parameter PE_ARRAY_ROW_SIZE = 2,
    parameter w_sfactor = 0.24,
    parameter b_sfactor = 0.54,
    parameter w_zpt = 0.24,
    parameter b_zpt = 0.54,
    parameter model_dir = "C:/Users/jlopezramos/Desktop/VivadoProjects/Models/dense_core_weights"
)
(   input wire clk, rst,
    input logic pre_syn_RAM_loaded,
    output logic post_syn_RAM_loaded, 
    output logic [$clog2(TIME_STEPS):0] prev_time_step,
    output logic [$clog2(OUT_CHANNELS):0] prev_oc_phase,
    output logic [FRAME_WIDTH*FRAME_WIDTH-1:0] spk_arr [PE_ARRAY_ROW_SIZE-1:0],
    output logic new_spk_train_ready
);

    // input shift registers for 3 feature maps
    shortreal fmap0_in0_shift, fmap0_in1_shift[0:1], fmap0_in2_shift[0:2], fmap0_in3_shift[0:3], fmap0_in4_shift[0:4], fmap0_in5_shift[0:5], fmap0_in6_shift[0:6], fmap0_in7_shift[0:7], fmap0_in8_shift[0:8];
    shortreal fmap1_in0_shift[0:9], fmap1_in1_shift[0:10], fmap1_in2_shift[0:11], fmap1_in3_shift[0:12], fmap1_in4_shift[0:13], fmap1_in5_shift[0:14], fmap1_in6_shift[0:15], fmap1_in7_shift[0:16], fmap1_in8_shift[0:17];
    shortreal fmap2_in0_shift[0:18], fmap2_in1_shift[0:19], fmap2_in2_shift[0:20], fmap2_in3_shift[0:21], fmap2_in4_shift[0:22], fmap2_in5_shift[0:23], fmap2_in6_shift[0:24], fmap2_in7_shift[0:25], fmap2_in8_shift[0:26];

    shortreal d_out[PE_ARRAY_ROW_SIZE-1:0], dout0, dout1; 
    int ind0, ind1, ind2, ind3, ind4, ind5, ind6, ind7, ind8; // indices for 9 filter coeff addresses

    shortreal col0_in0[PE_ARRAY_COL_SIZE-1:0]; // systolic array input regs
    shortreal fmap0 [0:FRAME_WIDTH*FRAME_WIDTH-1]; // 4x4 image
    shortreal fmap1 [0:FRAME_WIDTH*FRAME_WIDTH-1]; // 4x4 image
    shortreal fmap2 [0:FRAME_WIDTH*FRAME_WIDTH-1]; // 4x4 image
    
    logic [$clog2(FRAME_WIDTH*FRAME_WIDTH):0] pix_iter;
    logic [$clog2(TIME_STEPS):0] time_step;
    logic [$clog2(OUT_CHANNELS):0] oc_phase;
    logic [2:0] fsm_state;
    logic [$clog2(IN_CHANNELS*KERNEL_SIZE*KERNEL_SIZE):0] cntr;
    logic transit; // resets PEs once a time step completed
    logic new_oc; // resets membr_pot_array in threshold PE for new oc processing
    logic [0:PE_ARRAY_ROW_SIZE-1] en_thresh;
    integer file;
    initial begin
        file = $fopen($sformatf("%s/image.txt", model_dir), "r");
        for (int i = 0; i < IN_CHANNELS*FRAME_WIDTH*FRAME_WIDTH; i++) begin
            if(i < FRAME_WIDTH*FRAME_WIDTH)
                $fscanf(file, "%f", fmap0[i]);
            else if (i < 2*FRAME_WIDTH*FRAME_WIDTH)
                $fscanf(file, "%f", fmap1[i-FRAME_WIDTH*FRAME_WIDTH]);
            else
                $fscanf(file, "%f", fmap2[i -2*FRAME_WIDTH*FRAME_WIDTH]);
        end
        $fclose(file);
    end

    assign en_thresh[0] = (pix_iter > IN_CHANNELS*KERNEL_SIZE*KERNEL_SIZE + 0) ? 1'b1 : 1'b0;
    assign en_thresh[1] = (pix_iter > IN_CHANNELS*KERNEL_SIZE*KERNEL_SIZE + 1) ? 1'b1 : 1'b0;

    always_ff @(posedge clk) begin : feed_inputs
        if(rst) begin
            for (int i = 0; i < IN_CHANNELS*KERNEL_SIZE*KERNEL_SIZE; i++) begin
                if (i < 1) fmap0_in0_shift = 0.0;
                if (i < 2) fmap0_in1_shift[i] = 0.0;
                if (i < 3) fmap0_in2_shift[i] = 0.0;
                if (i < 4) fmap0_in3_shift[i] = 0.0;
                if (i < 5) fmap0_in4_shift[i] = 0.0;
                if (i < 6) fmap0_in5_shift[i] = 0.0;
                if (i < 7) fmap0_in6_shift[i] = 0.0;
                if (i < 8) fmap0_in7_shift[i] = 0.0;
                if (i < 9) fmap0_in8_shift[i] = 0.0;
                if (i < 10) fmap1_in0_shift[i] = 0.0;
                if (i < 11) fmap1_in1_shift[i] = 0.0;
                if (i < 12) fmap1_in2_shift[i] = 0.0;
                if (i < 13) fmap1_in3_shift[i] = 0.0;
                if (i < 14) fmap1_in4_shift[i] = 0.0;
                if (i < 15) fmap1_in5_shift[i] = 0.0;
                if (i < 16) fmap1_in6_shift[i] = 0.0;
                if (i < 17) fmap1_in7_shift[i] = 0.0;
                if (i < 18) fmap1_in8_shift[i] = 0.0;
                if (i < 19) fmap2_in0_shift[i] = 0.0;
                if (i < 20) fmap2_in1_shift[i] = 0.0;
                if (i < 21) fmap2_in2_shift[i] = 0.0;
                if (i < 22) fmap2_in3_shift[i] = 0.0;
                if (i < 23) fmap2_in4_shift[i] = 0.0;
                if (i < 24) fmap2_in5_shift[i] = 0.0;
                if (i < 25) fmap2_in6_shift[i] = 0.0;
                if (i < 26) fmap2_in7_shift[i] = 0.0;
                if (i < 27) fmap2_in8_shift[i] = 0.0;
            end
            pix_iter <= 0;
            post_syn_RAM_loaded <= 0;
            fsm_state <= 0;
            time_step <= 0;
            oc_phase <= 0;
            transit <= 0;
            cntr <= 0;
            new_oc <= 0;
            prev_time_step <= 0;
        end else begin       
            prev_time_step <= time_step;
            prev_oc_phase <= oc_phase;
            case(fsm_state)
                0: begin
                    post_syn_RAM_loaded <= 0;
                    new_spk_train_ready <= 0;
                    if(pre_syn_RAM_loaded) fsm_state <= 1;
                end
                1: begin
                    /****************** read fmap inputs into shift registers **********************/
                    post_syn_RAM_loaded <= 0;
                    transit <= 0;
                    new_oc <= 0;
                    new_spk_train_ready <= 0;
                    ind0 = pix_iter;
                    ind1 = pix_iter + 1;
                    ind2 = pix_iter + 2;
                    ind3 = pix_iter + FRAME_WIDTH;
                    ind4 = pix_iter + FRAME_WIDTH + 1;
                    ind5 = pix_iter + FRAME_WIDTH + 2;
                    ind6 = pix_iter + 2*FRAME_WIDTH;
                    ind7 = pix_iter + 2*FRAME_WIDTH + 1;
                    ind8 = pix_iter + 2*FRAME_WIDTH + 2;
                
                    fmap0_in0_shift <= fmap0[ind0];
                    fmap0_in1_shift[0] <= fmap0[ind1];
                    fmap0_in2_shift[0] <= fmap0[ind2];
                    fmap0_in3_shift[0] <= fmap0[ind3];
                    fmap0_in4_shift[0] <= fmap0[ind4];
                    fmap0_in5_shift[0] <= fmap0[ind5];
                    fmap0_in6_shift[0] <= fmap0[ind6];
                    fmap0_in7_shift[0] <= fmap0[ind7];
                    fmap0_in8_shift[0] <= fmap0[ind8];
                    fmap1_in0_shift[0] <= fmap1[ind0];
                    fmap1_in1_shift[0] <= fmap1[ind1];
                    fmap1_in2_shift[0] <= fmap1[ind2];
                    fmap1_in3_shift[0] <= fmap1[ind3];
                    fmap1_in4_shift[0] <= fmap1[ind4];
                    fmap1_in5_shift[0] <= fmap1[ind5];
                    fmap1_in6_shift[0] <= fmap1[ind6];
                    fmap1_in7_shift[0] <= fmap1[ind7];
                    fmap1_in8_shift[0] <= fmap1[ind8];
                    fmap2_in0_shift[0] <= fmap2[ind0];
                    fmap2_in1_shift[0] <= fmap2[ind1];
                    fmap2_in2_shift[0] <= fmap2[ind2];
                    fmap2_in3_shift[0] <= fmap2[ind3];
                    fmap2_in4_shift[0] <= fmap2[ind4];
                    fmap2_in5_shift[0] <= fmap2[ind5];
                    fmap2_in6_shift[0] <= fmap2[ind6];
                    fmap2_in7_shift[0] <= fmap2[ind7];
                    fmap2_in8_shift[0] <= fmap2[ind8];
                    /*******************************************************************************/  

                    /**************** iterate pixels, conv wind sliding *************************/            
                    if(pix_iter < FRAME_WIDTH*FRAME_WIDTH)
                        pix_iter <= pix_iter + 1;
                    else begin
                        cntr <= 0;
                        fsm_state <= 2;
                    end
                    /*******************************************************************************/
                end
                2: begin // wait for all 27 pixels flow into the threshold block
                    
                    if(cntr < IN_CHANNELS*KERNEL_SIZE*KERNEL_SIZE) begin                        
                        cntr <= cntr + 1;
                    end else begin
                        new_spk_train_ready <= 1;
                        pix_iter <= 0;
                        cntr <= 0;
                        transit <= 1;
                        if(time_step < TIME_STEPS - 1) begin
                            time_step <= time_step + 1;
                            fsm_state <= 1;
                        end else begin
                            time_step <= 0;
                            new_oc <= 1;                            
                            if(oc_phase < OUT_CHANNELS/PE_ARRAY_ROW_SIZE - 1) begin
                                oc_phase <= oc_phase + 1;
                                fsm_state <= 1;
                            end else begin
                                oc_phase <= 0;
                                fsm_state <= 0;
                                post_syn_RAM_loaded <= 1;
                            end
                        end
                    end
                end 
            endcase
            
            // shift reg: delay inputs by up to 12 cycles for 3 channel 2x2 filter
            for (int i = 1; i < IN_CHANNELS*KERNEL_SIZE*KERNEL_SIZE; i++) begin
                if (i < 2)  fmap0_in1_shift[i] <= fmap0_in1_shift[i-1];
                if (i < 3)  fmap0_in2_shift[i] <= fmap0_in2_shift[i-1];
                if (i < 4)  fmap0_in3_shift[i] <= fmap0_in3_shift[i-1];
                if (i < 5)  fmap0_in4_shift[i] <= fmap0_in4_shift[i-1];
                if (i < 6)  fmap0_in5_shift[i] <= fmap0_in5_shift[i-1];
                if (i < 7)  fmap0_in6_shift[i] <= fmap0_in6_shift[i-1];
                if (i < 8)  fmap0_in7_shift[i] <= fmap0_in7_shift[i-1];
                if (i < 9)  fmap0_in8_shift[i] <= fmap0_in8_shift[i-1];
                if (i < 10) fmap1_in0_shift[i] <= fmap1_in0_shift[i-1];
                if (i < 11) fmap1_in1_shift[i] <= fmap1_in1_shift[i-1];
                if (i < 12) fmap1_in2_shift[i] <= fmap1_in2_shift[i-1];
                if (i < 13) fmap1_in3_shift[i] <= fmap1_in3_shift[i-1];
                if (i < 14) fmap1_in4_shift[i] <= fmap1_in4_shift[i-1];
                if (i < 15) fmap1_in5_shift[i] <= fmap1_in5_shift[i-1];
                if (i < 16) fmap1_in6_shift[i] <= fmap1_in6_shift[i-1];
                if (i < 17) fmap1_in7_shift[i] <= fmap1_in7_shift[i-1];
                if (i < 18) fmap1_in8_shift[i] <= fmap1_in8_shift[i-1];
                if (i < 19) fmap2_in0_shift[i] <= fmap2_in0_shift[i-1];
                if (i < 20) fmap2_in1_shift[i] <= fmap2_in1_shift[i-1];
                if (i < 21) fmap2_in2_shift[i] <= fmap2_in2_shift[i-1];
                if (i < 22) fmap2_in3_shift[i] <= fmap2_in3_shift[i-1];
                if (i < 23) fmap2_in4_shift[i] <= fmap2_in4_shift[i-1];
                if (i < 24) fmap2_in5_shift[i] <= fmap2_in5_shift[i-1];
                if (i < 25) fmap2_in6_shift[i] <= fmap2_in6_shift[i-1];
                if (i < 26) fmap2_in7_shift[i] <= fmap2_in7_shift[i-1];
                if (i < 27) fmap2_in8_shift[i] <= fmap2_in8_shift[i-1];
            end 
        end
    end

    assign col0_in0[0] = fmap0_in0_shift;
    assign col0_in0[1] = fmap0_in1_shift[1];
    assign col0_in0[2] = fmap0_in2_shift[2];
    assign col0_in0[3] = fmap0_in3_shift[3];
    assign col0_in0[4] = fmap0_in4_shift[4];
    assign col0_in0[5] = fmap0_in5_shift[5];
    assign col0_in0[6] = fmap0_in6_shift[6];
    assign col0_in0[7] = fmap0_in7_shift[7];
    assign col0_in0[8] = fmap0_in8_shift[8];
    assign col0_in0[9] = fmap1_in0_shift[9];
    assign col0_in0[10] = fmap1_in1_shift[10];
    assign col0_in0[11] = fmap1_in2_shift[11];
    assign col0_in0[12] = fmap1_in3_shift[12];
    assign col0_in0[13] = fmap1_in4_shift[13];
    assign col0_in0[14] = fmap1_in5_shift[14];
    assign col0_in0[15] = fmap1_in6_shift[15];
    assign col0_in0[16] = fmap1_in7_shift[16];
    assign col0_in0[17] = fmap1_in8_shift[17];
    assign col0_in0[18] = fmap2_in0_shift[18];
    assign col0_in0[19] = fmap2_in1_shift[19];
    assign col0_in0[20] = fmap2_in2_shift[20];
    assign col0_in0[21] = fmap2_in3_shift[21];
    assign col0_in0[22] = fmap2_in4_shift[22];
    assign col0_in0[23] = fmap2_in5_shift[23];
    assign col0_in0[24] = fmap2_in6_shift[24];
    assign col0_in0[25] = fmap2_in7_shift[25];
    assign col0_in0[26] = fmap2_in8_shift[26];

    pe_array #(
        .IN_CHANNELS(IN_CHANNELS), 
        .OUT_CHANNELS(OUT_CHANNELS), 
        .KERNEL_SIZE(KERNEL_SIZE), 
        .PE_ARRAY_COL_SIZE(PE_ARRAY_COL_SIZE), 
        .PE_ARRAY_ROW_SIZE(PE_ARRAY_ROW_SIZE),
        .w_sfactor(`w_sfactor), .w_zpt(`w_zpt), 
        .model_dir($sformatf("%s/dc_weights", model_dir))
    ) 
    pe_array0(
        .clk(clk), .rst(rst), .transit(transit), .oc_phase(oc_phase),
        .col0_in0(col0_in0), .d_out(d_out)
    );
    
    assign dout0 = d_out[0];
    assign dout1 = d_out[1];
    thresholding #(.FRAME_WIDTH(FRAME_WIDTH), .SIZE(OUT_CHANNELS/PE_ARRAY_ROW_SIZE), .OUT_CHANNELS(OUT_CHANNELS),
    .b_sfactor(`b_sfactor),  .b_zpt(`b_zpt),
    .BIAS_FILENAME($sformatf("%s/dc_weights/threshold1.txt", model_dir))) 
    fm1(.clk(clk), .rst(rst), .new_oc(new_oc), .oc_phase(oc_phase), .en_thresh(en_thresh[1]), .membr_pot(dout1), .spk_arr(spk_arr[1]));

    thresholding #(.FRAME_WIDTH(FRAME_WIDTH), .SIZE(OUT_CHANNELS/PE_ARRAY_ROW_SIZE), .OUT_CHANNELS(OUT_CHANNELS),
    .b_sfactor(`b_sfactor),  .b_zpt(`b_zpt),
    .BIAS_FILENAME($sformatf("%s/dc_weights/threshold0.txt", model_dir))) 
    fm0(.clk(clk), .rst(rst), .new_oc(new_oc), .oc_phase(oc_phase), .en_thresh(en_thresh[0]), .membr_pot(dout0), .spk_arr(spk_arr[0]));
    
endmodule

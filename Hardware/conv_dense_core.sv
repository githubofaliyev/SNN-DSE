`timescale 1ns / 1ps

// simple 4x4 PE array. 
// inputs from left, outputs from buttom row
module conv_dense_nc #(
    parameter INPUT_FRAME_WIDTH = 5, 
    parameter KERNEL_ROW = 2, 
    parameter TIME_STEPS = 32)
(
    input wire clk, rst
);
    
    // array I/O
    shortreal in0, in1_shift[0:1], in2_shift[0:2], in3_shift[0:3];
    shortreal out0, out1, out2, out3; 
    int idx0, idx1, idx2, idx3;

    // intermediate signals 
    shortreal out0_0_0, out0_0_1, out0_1_0, out0_1_1, out0_2_0, out0_2_1, out0_3_0, out0_3_1;
    shortreal out1_0_0, out1_0_1, out1_1_0, out1_1_1, out1_2_0, out1_2_1, out1_3_0, out1_3_1;
    shortreal out2_0_0, out2_0_1, out2_1_0, out2_1_1, out2_2_0, out2_2_1, out2_3_0, out2_3_1;
    shortreal out3_0_0, out3_0_1, out3_1_0, out3_1_1, out3_2_0, out3_2_1, out3_3_0, out3_3_1;

    shortreal pixels [0:INPUT_FRAME_WIDTH*INPUT_FRAME_WIDTH-1]; // 4x4 image
    logic [9:0] pix_iter;
    logic [0:3] en_thresh;
    logic [0:INPUT_FRAME_WIDTH*INPUT_FRAME_WIDTH-1] spk_arr [3:0]; // 4x4 spike array for 4 fmaps

    integer file;
    initial begin
        file = $fopen("C:/Users/jlopezramos/Desktop/VivadoProjects/img_file.txt", "r");
        if (file == 0) begin
            $display("Error: Opening file failed!");
        end else begin
            $display("Success: Opening file!");
            for (int i = 0; i < INPUT_FRAME_WIDTH*INPUT_FRAME_WIDTH; i++) begin
            $fscanf(file, "%f", pixels[i]);
            end
            $fclose(file);
        end
    end

    assign en_thresh[0] = (pix_iter > KERNEL_ROW*KERNEL_ROW + 1) ? 1'b1 : 1'b0;
    assign en_thresh[1] = (pix_iter > KERNEL_ROW*KERNEL_ROW + 2) ? 1'b1 : 1'b0;
    assign en_thresh[2] = (pix_iter > KERNEL_ROW*KERNEL_ROW + 3) ? 1'b1 : 1'b0;
    assign en_thresh[3] = (pix_iter > KERNEL_ROW*KERNEL_ROW + 4) ? 1'b1 : 1'b0;


    always_ff @(posedge clk) begin : feed_inputs
        if(rst) begin
            for (int i = 0; i < KERNEL_ROW; i++) begin
                if (i < 1) in0 = 0.0;
                if (i < 2) in1_shift[i] = 0.0;
                if (i < 3) in2_shift[i] = 0.0;
                if (i < 4) in3_shift[i] = 0.0;
            end
            pix_iter = 0;
        end else begin       
            idx0 = pix_iter;
            idx1 = pix_iter + 1;
            idx2 = pix_iter + INPUT_FRAME_WIDTH;
            idx3 = pix_iter + INPUT_FRAME_WIDTH + 1;
            
            in0 <= pixels[idx0];
            in1_shift[0] <= pixels[idx1];
            in2_shift[0] <= pixels[idx2];
            in3_shift[0] <= pixels[idx3];
            // delay inputs by 1,2,3 cycles
            for (int i = 1; i < 4; i++) begin
                if (i < 2)  in1_shift[i] <= in1_shift[i-1];
                if (i < 3)  in2_shift[i] <= in2_shift[i-1];
                if (i < 4)  in3_shift[i] <= in3_shift[i-1];
            end
                
            if(pix_iter%INPUT_FRAME_WIDTH == INPUT_FRAME_WIDTH - 2) // skip last column bc 2x2 filter
                pix_iter <= pix_iter + 2;
            else
                pix_iter <= pix_iter + 1;
            // also some mechanism to stop at the row before the last one
        end
    end
    
    // instantiate PEs, row, col idxexing
    pe #(.WEIGHT(8.0)) pe0_0(.clk(clk), .rst(rst), .in0(in0),      .in1(0), .out0(out0_0_0), .out1(out0_0_1));
    pe #(.WEIGHT(0.503)) pe0_1(.clk(clk), .rst(rst), .in0(out0_0_0), .in1(0), .out0(out0_1_0), .out1(out0_1_1));
    pe #(.WEIGHT(0.503)) pe0_2(.clk(clk), .rst(rst), .in0(out0_1_0), .in1(0), .out0(out0_2_0), .out1(out0_2_1));
    pe #(.WEIGHT(0.503)) pe0_3(.clk(clk), .rst(rst), .in0(out0_2_0), .in1(0), .out0(out0_3_0), .out1(out0_3_1));

    pe #(.WEIGHT(8.0)) pe1_0(.clk(clk), .rst(rst), .in0(in1_shift[1]),      .in1(out0_0_1), .out0(out1_0_0), .out1(out1_0_1));
    pe #(.WEIGHT(0.503)) pe1_1(.clk(clk), .rst(rst), .in0(out1_0_0), .in1(out0_1_1), .out0(out1_1_0), .out1(out1_1_1));
    pe #(.WEIGHT(0.503)) pe1_2(.clk(clk), .rst(rst), .in0(out1_1_0), .in1(out0_2_1), .out0(out1_2_0), .out1(out1_2_1));
    pe #(.WEIGHT(0.503)) pe1_3(.clk(clk), .rst(rst), .in0(out1_2_0), .in1(out0_3_1), .out0(out1_3_0), .out1(out1_3_1));

    pe #(.WEIGHT(4.0)) pe2_0(.clk(clk), .rst(rst), .in0(in2_shift[2]),      .in1(out1_0_1), .out0(out2_0_0), .out1(out2_0_1));
    pe #(.WEIGHT(0.503)) pe2_1(.clk(clk), .rst(rst), .in0(out2_0_0), .in1(out1_1_1), .out0(out2_1_0), .out1(out2_1_1));
    pe #(.WEIGHT(0.503)) pe2_2(.clk(clk), .rst(rst), .in0(out2_1_0), .in1(out1_2_1), .out0(out2_2_0), .out1(out2_2_1));
    pe #(.WEIGHT(0.503)) pe2_3(.clk(clk), .rst(rst), .in0(out2_2_0), .in1(out1_3_1), .out0(out2_3_0), .out1(out2_3_1));

    pe #(.WEIGHT(4.0)) pe3_0(.clk(clk), .rst(rst), .in0(in3_shift[3]),      .in1(out2_0_1), .out0(out3_0_0), .out1(out0));
    pe #(.WEIGHT(0.503)) pe3_1(.clk(clk), .rst(rst), .in0(out3_0_0), .in1(out2_1_1), .out0(out3_1_0), .out1(out1));
    pe #(.WEIGHT(0.503)) pe3_2(.clk(clk), .rst(rst), .in0(out3_1_0), .in1(out2_2_1), .out0(out3_2_0), .out1(out2));
    pe #(.WEIGHT(0.503)) pe3_3(.clk(clk), .rst(rst), .in0(out3_2_0), .in1(out2_3_1), .out0(out3_3_0), .out1(out3));

    thresholding fm0(.clk(clk), .rst(rst), .en_thresh(en_thresh[0]), .membr_pot(out0), .spk_arr(spk_arr[0]));
    thresholding fm1(.clk(clk), .rst(rst), .en_thresh(en_thresh[1]), .membr_pot(out1), .spk_arr(spk_arr[1]));
    thresholding fm2(.clk(clk), .rst(rst), .en_thresh(en_thresh[2]), .membr_pot(out2), .spk_arr(spk_arr[2]));
    thresholding fm3(.clk(clk), .rst(rst), .en_thresh(en_thresh[3]), .membr_pot(out3), .spk_arr(spk_arr[3]));

endmodule

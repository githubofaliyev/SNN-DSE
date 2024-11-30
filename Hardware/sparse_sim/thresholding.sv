`timescale 1ns / 1ps

module thresholding #(
    parameter FRAME_WIDTH = 5,
    parameter THRESHOLD = 0.5,
    parameter SIZE = 4,
    parameter OUT_CHANNELS = 2,
    parameter BETA = 0.15,
    parameter b_sfactor = 0.54,
    parameter b_zpt = 0.54,
    parameter string BIAS_FILENAME = "weight_file_0_3.txt"
)
(
    input clk, rst, en_thresh, new_oc,
    input shortreal membr_pot,
    input logic [$clog2(OUT_CHANNELS):0] oc_phase,
    output logic [FRAME_WIDTH*FRAME_WIDTH-1:0] spk_arr
);

    shortreal bias[SIZE-1:0]; //  bias
    shortreal membr_pot_reg;
    integer file;
    initial begin
        file = $fopen(BIAS_FILENAME, "r");
        if (file == 0) begin
            $display("Error: Opening file failed!");
        end else begin
            $display("Success: Opening file!");
            for (int i = 0; i < SIZE; i++) begin
                $fscanf(file, "%f", bias[i]);
            end
            $fclose(file);
        end
    end

    shortreal membr_pot_arr[0:FRAME_WIDTH*FRAME_WIDTH-1], intermed_dat;
    logic [9:0] pix_iter, cntr;
    logic [1:0] fsm_state;
    logic spike_stage, spk_intermed;

    always_ff @(posedge clk) begin
        if(rst) begin
            spk_arr <= 0;
            pix_iter <= 0;
            cntr <= 0;
            fsm_state <= 0;
            spike_stage <= 0;
            for(int i=0; i<FRAME_WIDTH*FRAME_WIDTH; i++) membr_pot_arr[i] <= 0;
        end else begin
            case(fsm_state)
                0: begin
                    spk_arr <= 0;
                    pix_iter <= 0;
                    cntr <= 0;
                    spike_stage <= 0;
                    if(en_thresh) begin
                        membr_pot_reg = membr_pot; // this is to offset 1 cycle delay, bc membr_pot arrives at state 0
                        fsm_state <= 1; 
                    end
                end
                1: begin
                    membr_pot_reg <= membr_pot;
                    intermed_dat = membr_pot_arr[pix_iter] + BETA*membr_pot_reg + (bias[oc_phase] - b_zpt)*b_sfactor;
                    membr_pot_arr[pix_iter] = intermed_dat;
                    spike_stage <= 1;
                    pix_iter <= pix_iter + 1;
                    
                    if(spike_stage) begin
                        if(membr_pot_arr[pix_iter-1] > THRESHOLD) spk_intermed = 1;
                        else spk_intermed = 0;
                        spk_arr[pix_iter-1] = spk_intermed;
                    end
                    
                    if(!(en_thresh) || (pix_iter > 63)) fsm_state <= 0;
                                        
                    if(new_oc) begin
                        for(int i=0; i<FRAME_WIDTH*FRAME_WIDTH; i++) membr_pot_arr[i] <= 0.0;
                    end
                end
            endcase
        end
    end

endmodule
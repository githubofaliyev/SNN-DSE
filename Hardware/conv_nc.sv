module conv_nc #(
    parameter NEURON_OFFSET = 0, // with respect to oc_phase, max EC_SIZE
    parameter EC_SIZE = 2,
    parameter IN_CHANNELS = 2,
    parameter OUT_CHANNELS = 4,
    parameter KERNEL_SIZE = 3,
    parameter INPUT_FRAME_WIDTH = 28,
    parameter INPUT_FRAME_SIZE = INPUT_FRAME_WIDTH * INPUT_FRAME_WIDTH,
    parameter OUTPUT_FRAME_WIDTH = 26,
    parameter BRAM_ADDR_WIDTH = 10,
    parameter w_sfactor = 0.24,
    parameter b_sfactor = 0.54,
    parameter w_zpt = 0.24,
    parameter b_zpt = 0.54,
    parameter NEURON_TYPE = 0, // 0 for LIF, 1 for Lapicque
    parameter string WEIGHT_FILENAME = "/sim_1/new/weight_file_0_3.txt"
  )(
  input logic clk, rst,
  input en_accum, en_activ,
  input last_time_step,
  input ic_done,
  input logic [$clog2(IN_CHANNELS)+1:0] ic,
  input logic [$clog2(KERNEL_SIZE)+1:0] filter_phase,
  input logic [$clog2(OUT_CHANNELS)+1:0] oc_phase,
  input logic [$clog2(INPUT_FRAME_WIDTH)-1:0] affect_neur_addr_row,
  input logic [$clog2(INPUT_FRAME_WIDTH)-1:0] affect_neur_addr_col,
  input logic neur_addr_invalid,

  output logic [OUTPUT_FRAME_WIDTH*OUTPUT_FRAME_WIDTH-1:0] post_syn_spk,
  input shortreal bram_rdat,
  output shortreal bram_wrdat,
  output logic [BRAM_ADDR_WIDTH-1:0] bram_raddr, // ?
  output logic bram_ren,
  output logic [BRAM_ADDR_WIDTH-1:0] bram_wraddr, // ?
  output logic bram_wren
  );
  
  int spk_ctr = 0;
  
  shortreal BETA = (NEURON_TYPE == 0) ? 1.0 : 0.24; // Old Value: 0.15, New Value: 0.24
  shortreal signed_POSITIVE_THRESHOLD = 0.23; // Old Value: 0.5, New Value: 0.23
  shortreal membr_pot, membr_pot_nxt;

  logic [3:0] fsm_state, fsm_state_nxt;
  logic [OUTPUT_FRAME_WIDTH*OUTPUT_FRAME_WIDTH-1:0] post_syn_spk_nxt;
  logic accum_membr_calc_stage, accum_membr_calc_stage_nxt;
  logic activ_membr_calc_stage, activ_membr_calc_stage_nxt;
  logic [BRAM_ADDR_WIDTH-1:0] intermed_addr, intermed_addr_nxt;
  
  logic [31:0] weight_addr;
  shortreal weight_data;
  int bias_addr;
  shortreal bias_data;

  `ifdef SIM
  shortreal weight_n_bias[(OUT_CHANNELS/EC_SIZE)*(IN_CHANNELS*KERNEL_SIZE*KERNEL_SIZE  + 1) - 1:0]; // weight_n_bias and bias
  `else
  logic [31:0] weight_n_bias[(OUT_CHANNELS/EC_SIZE)*(IN_CHANNELS*KERNEL_SIZE*KERNEL_SIZE + 1) - 1:0]; // weight_n_bias and bias
  `endif
  shortreal intermed_pot;

  integer file;
  initial begin
    file = $fopen(WEIGHT_FILENAME, "r");
    if (file == 0) begin
      $display("Error: Opening file failed!");
    end else begin
       $display("Success: Opening file!");
      for (int i = 0; i < (OUT_CHANNELS/EC_SIZE)*(IN_CHANNELS * KERNEL_SIZE * KERNEL_SIZE + 1); i++) begin
        $fscanf(file, "%f", weight_n_bias[i]);
      end
      $fclose(file);
    end
  end
  // stage enable signals
  logic accum_calc_stage, accum_calc_stage_nxt;
 
  always_ff @(posedge clk) begin
    fsm_state <=  fsm_state_nxt;
    post_syn_spk <= post_syn_spk_nxt;
    membr_pot <= membr_pot_nxt;
    accum_membr_calc_stage <= accum_membr_calc_stage_nxt;
    intermed_addr <= intermed_addr_nxt;
    activ_membr_calc_stage <= activ_membr_calc_stage_nxt;
  end

  always_comb begin : event_control
    if(rst) begin
      fsm_state_nxt = 0;
      post_syn_spk_nxt = 0;
      membr_pot_nxt = 0;
      bram_ren = 0;
      bram_wren = 0;
      bram_raddr = 0;
      bram_wraddr = 0;
      accum_membr_calc_stage_nxt = 0;
      intermed_addr_nxt = 0;
      activ_membr_calc_stage_nxt = 0;
    end else begin
      fsm_state_nxt = fsm_state;
      post_syn_spk_nxt = post_syn_spk;
      membr_pot_nxt = membr_pot;
      bram_ren = 0;
      bram_wren = 0;
      accum_membr_calc_stage_nxt = accum_membr_calc_stage;
      activ_membr_calc_stage_nxt = activ_membr_calc_stage;
      intermed_addr_nxt = intermed_addr;
      case (fsm_state)
        0: begin
          accum_membr_calc_stage_nxt = 0;
          activ_membr_calc_stage_nxt = 0;
          if(en_accum) fsm_state_nxt = 1;   
          else if(en_activ) begin
            fsm_state_nxt = 3;
            bram_ren = 1;
            post_syn_spk_nxt = 0;
            bram_raddr = 0;
          end
        end
        1: begin 
            if(en_activ) begin
                fsm_state_nxt = 3;
                bram_ren = 1;
                post_syn_spk_nxt = 0;
                bram_raddr = 0;
                accum_membr_calc_stage_nxt = 0;
            end else if (neur_addr_invalid) begin 
                accum_membr_calc_stage_nxt = 0;
            end else if(en_accum) begin // if addr valid then do accum add and bram wr
                bram_raddr = affect_neur_addr_row*INPUT_FRAME_WIDTH + affect_neur_addr_col;
                intermed_addr_nxt = bram_raddr;
                bram_ren = 1;
                accum_membr_calc_stage_nxt = 1;
            end
           
           if(accum_membr_calc_stage) begin
                weight_addr = oc_phase * (IN_CHANNELS * KERNEL_SIZE * KERNEL_SIZE + 1) + ic * KERNEL_SIZE * KERNEL_SIZE + filter_phase;
                weight_data = weight_n_bias[weight_addr];
                intermed_pot = bram_rdat + (weight_data - w_zpt)*w_sfactor;
//                intermed_pot = bram_rdat + (weight_n_bias[oc_phase * (IN_CHANNELS * KERNEL_SIZE * KERNEL_SIZE + 1) + ic * KERNEL_SIZE * KERNEL_SIZE + filter_phase] - w_zpt)*w_sfactor;
                if(intermed_pot > 255) bram_wrdat = 255;
                else if(intermed_pot < -255) bram_wrdat = -255;
                else bram_wrdat = intermed_pot;
                bram_wraddr = intermed_addr;
                bram_wren = 1; 
           end

        end
        7: begin // next spike delay
            fsm_state_nxt = 0;
        end
        3: begin // data read, now do the bias addition
            if(bram_raddr < OUTPUT_FRAME_WIDTH*OUTPUT_FRAME_WIDTH - 1) begin
                intermed_addr_nxt = bram_raddr;
                bram_raddr = bram_raddr + 1;
                bram_ren = 1;
                activ_membr_calc_stage_nxt = 1;
            end else begin
                fsm_state_nxt = 7;
                bram_raddr = 0;
                activ_membr_calc_stage_nxt = 0;
            end
            bias_addr = (oc_phase+1) * IN_CHANNELS * KERNEL_SIZE * KERNEL_SIZE + oc_phase;
            bias_data = weight_n_bias[bias_addr];
            //membr_pot_nxt = bram_rdat + bias_data;  
            membr_pot_nxt = bias_data*b_sfactor  + bram_rdat;
//            membr_pot_nxt = (weight_n_bias[(oc_phase + 1) * IN_CHANNELS * KERNEL_SIZE * KERNEL_SIZE] - b_zpt)*b_sfactor  + bram_rdat;
            
            if(activ_membr_calc_stage) begin
                bram_wraddr = intermed_addr;
                bram_wren = 1; 
                if(membr_pot > signed_POSITIVE_THRESHOLD) begin
                    spk_ctr++; 
                    post_syn_spk_nxt[intermed_addr] = 1;
                    if(last_time_step) bram_wrdat = 0;
                    else 
                        bram_wrdat = (membr_pot - signed_POSITIVE_THRESHOLD)*BETA;
                end else begin
                    post_syn_spk_nxt[intermed_addr] = 0;
                    if(last_time_step) bram_wrdat = 0;
                    else bram_wrdat = membr_pot*BETA;
                end
            end
        end
        6: fsm_state_nxt = 0;
      endcase
    end // rst

  end // always

endmodule

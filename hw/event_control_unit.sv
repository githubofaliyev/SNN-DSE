`timescale 1ns / 1ps

module event_control#(parameter EC_UNIT_SIZE = 4, // total neural units managaed by EC                      
                      parameter LAYER_SIZE = 16, // total neurons in this layer 
                      // total number of spikes to this layer
                      parameter SPARSE_SIZE,  // initially set to LAYER_SIZE, e.g., if 784 neurons, avg 145 spikes, then 784/145 = 5.4, so 6 size
                      parameter PRE_SYN_LAYER_SIZE = 32,
                      parameter NEURAL_UNIT_SIZE = LAYER_SIZE/EC_UNIT_SIZE,
                      parameter NEURAL_LAT = 4,
                      parameter TIME_STEPS = 8
                      )
                     (input clk, rst, 
                      input pre_synp_avail,
                      input [PRE_SYN_LAYER_SIZE-1:0] pre_synpt_spk_train, // pre-synaptic layer spikes
                      output logic [EC_UNIT_SIZE-1:0][$clog2(PRE_SYN_LAYER_SIZE)-1:0] out_spk_addr_array,
                      output logic layer_avail,
                      output logic en_accum, en_activ);

  logic [$clog2(TIME_STEPS)-1:0] time_step, time_step_nxt;
  logic [PRE_SYN_LAYER_SIZE-1:0] penc_in, penc_in_nxt;  // takes entire spk train from pre synaptic layer
  logic [$clog2(PRE_SYN_LAYER_SIZE)-1:0] penc_spk_addr; // first spike address in the spk train
  logic [$clog2(SPARSE_SIZE)-1:0] spk_cnt, spk_cnt_nxt; // number of spikes in the spk train
  logic penc_done; 
  logic layer_avail_nxt;
  logic [$clog2(NEURAL_LAT*NEURAL_UNIT_SIZE)-1:0] neural_lat, neural_lat_nxt;
  logic [$clog2(SPARSE_SIZE)-1:0] shift_phase, shift_phase_nxt;
  logic en_accum_nxt, en_activ_nxt;

  logic [2:0] fsm_state, fsm_state_nxt;
  logic [SPARSE_SIZE-1:0][$clog2(PRE_SYN_LAYER_SIZE)-1:0] spk_addr_array, spk_addr_array_nxt;

  int i, j, k;

  penc#(PRE_SYN_LAYER_SIZE) p0 (.sparse_in(penc_in), .penc_spk_addr(penc_spk_addr), .penc_done(penc_done));
  
genvar idx;
generate
    for (idx = 0; idx < EC_UNIT_SIZE; idx = idx + 1) begin
        assign out_spk_addr_array[idx] = spk_addr_array[(idx + shift_phase >= spk_cnt) ? (idx + shift_phase - spk_cnt) : (idx + shift_phase)];
    end
endgenerate
  
  always_ff @(posedge clk) begin
    penc_in <= penc_in_nxt;
    fsm_state <= fsm_state_nxt;
    spk_cnt <= spk_cnt_nxt;
    shift_phase <= shift_phase_nxt;
    en_accum <= en_accum_nxt;
    neural_lat <= neural_lat_nxt;
    layer_avail <= layer_avail_nxt;
    en_activ <= en_activ_nxt;
    for (int i = 0; i < LAYER_SIZE; i = i + 1) begin
      spk_addr_array[i] <= spk_addr_array_nxt[i];
    end
  end

  always_comb begin : event_control
    if(rst) begin
      fsm_state_nxt = 0;
      penc_in_nxt = 0;
      spk_cnt_nxt = 0;
      shift_phase_nxt = 0;
      en_accum_nxt = 0;
      neural_lat_nxt = 0;
      en_activ_nxt = 0;
      layer_avail_nxt = 1;
      for (int i = 0; i < LAYER_SIZE; i = i + 1) begin
        spk_addr_array_nxt[i] = 0;
      end
    end else begin
      fsm_state_nxt = fsm_state;
      penc_in_nxt = penc_in;
      spk_cnt_nxt = spk_cnt;
      layer_avail_nxt = layer_avail;
      shift_phase_nxt = shift_phase;
      neural_lat_nxt = neural_lat;
      en_accum_nxt = en_accum;
      en_activ_nxt = en_activ;
      for (int i = 0; i < SPARSE_SIZE; i = i + 1) begin
        spk_addr_array_nxt[i] = spk_addr_array[i];
      end      
      case (fsm_state)
        /*********************************** SPIKE ENCODE*********************************************/
        0: begin // PENC_0: obtain original spike array from pre-syntaptic layer
          if(pre_synp_avail) begin
             layer_avail_nxt = 0;
            penc_in_nxt = pre_synpt_spk_train;
            fsm_state_nxt = 2;
            spk_cnt_nxt = 0;
          end
        end
        1: begin // PENC_1: reset current set/spike bit and encode next spike
          penc_in_nxt[penc_spk_addr] = 0;
          fsm_state_nxt = 2;
        end
        2: begin // PENC_2: push the spk_train address to array
          if(penc_done) begin
            en_accum_nxt = 1;
            fsm_state_nxt = 3; // if priority encode penc_done, meaning all bits reset/0
          end else begin
            spk_addr_array_nxt[spk_cnt] = penc_spk_addr;
            spk_cnt_nxt = spk_cnt + 1;
            fsm_state_nxt = 1;
          end
        end
        /*********************************** SHIFT & ACCUMULATE *********************************************/
        3: begin // ACCUM_0: NEURON: fixed number of cycles for all neural units
            if(neural_lat < NEURAL_LAT*NEURAL_UNIT_SIZE-1) // wait single neuron wght fetch and accum finish
              neural_lat_nxt = neural_lat + 1;
            else begin // move on to the next neuron wght fetch and accum within the neural unit
              neural_lat_nxt = 0;
              if(shift_phase < spk_cnt-1) begin
                shift_phase_nxt = shift_phase + 1;
              end else begin
                shift_phase_nxt = 0;
                fsm_state_nxt = 4;
              end
            end 
        end
        4: begin
            fsm_state_nxt = 5;  
            en_accum_nxt = 0;
            en_activ_nxt = 1;
        end
        5: begin // ACCUM_0: NEURON: fixed number of cycles for all neural units
            if(neural_lat < NEURAL_UNIT_SIZE-1) // wait single neuron wght fetch and accum finish
              neural_lat_nxt = neural_lat + 1;
            else begin // move on to the next neuron wght fetch and accum within the neural unit
              neural_lat_nxt = 0;
              en_activ_nxt = 0;
              layer_avail_nxt = 1;
              fsm_state_nxt = 0;  
            end 
        end
      endcase
    end // rst
  end // always
endmodule

// parametrize width
module penc#(parameter SIZE = 32)
            (input [SIZE-1:0] sparse_in, output logic [$clog2(SIZE)-1:0] penc_spk_addr, output logic penc_done);

  integer i;

  always_comb begin
    for(i=0; i<SIZE; i=i+1) begin
      if(sparse_in[i]) begin
        penc_spk_addr = i;
        penc_done = 0;
        break;
      end
      penc_done = 1;
    end
  end
endmodule
`timescale 1ns / 1ps

/* algo
for out_ch in out_channels (incr by out_channel_stride)
  for t in time_steps
    for in_ch in in_channels 

*/

module conv_ec#(parameter TIME_STEPS = 10,
                parameter INPUT_CHANNELS = 2,
                parameter OUTPUT_CHANNELS = 32,
                parameter KERNEL_SIZE = 3,
                parameter INPUT_FRAME_WIDTH = 28,
                parameter EC_SIZE = 4,
                parameter PENC_SIZE = 20,
                parameter INPUT_FRAME_SIZE = INPUT_FRAME_WIDTH*INPUT_FRAME_WIDTH,
                parameter OUTPUT_FRAME_WIDTH = INPUT_FRAME_WIDTH, 
                parameter OUTPUT_FRAME_SIZE = OUTPUT_FRAME_WIDTH*OUTPUT_FRAME_WIDTH,
                parameter SPARSE_SIZE = INPUT_FRAME_SIZE)
    (input clk, rst, 
    input logic pre_syn_RAM_loaded,
    output logic post_syn_RAM_loaded, 
    output logic [$clog2(INPUT_FRAME_WIDTH)-1:0] affect_neur_addr_row[EC_SIZE-1:0], // neuron address
    output logic [$clog2(INPUT_FRAME_WIDTH)-1:0] affect_neur_addr_col[EC_SIZE-1:0],
    output logic neur_addr_invalid,
    input [INPUT_FRAME_SIZE-1:0] spk_in_train, 
    output logic spk_in_ram_en,
    output logic [$clog2(INPUT_CHANNELS)+1:0] ic,
    output logic [$clog2(OUTPUT_CHANNELS)+1:0] oc_phase, oc_phase_shift,
    output logic [$clog2(TIME_STEPS)-1:0] time_step_out_spikes, // signal used to index into output spikes RAM, post-syn RAM
    output logic [$clog2(TIME_STEPS)-1:0] time_step_in_spikes, // signal used to index into input spikes RAM, pre-syn RAM
    output logic new_spk_train_ready,
    output logic [$clog2(KERNEL_SIZE)+1:0] filter_phase,
    output logic last_time_step, ic_done,
    output logic en_accum, en_activ,
    input [31:0] total_layer_spks_in,
    output logic [$clog2(8*SPARSE_SIZE)-1:0] cumm_spks,
    output logic [31:0] total_layer_spks_out); // total number of spikes in the spk train)

  logic [PENC_SIZE-1:0] penc_in, penc_in_nxt;  // takes entire spk train from pre synaptic layer
  logic [$clog2(PENC_SIZE)-1:0] penc_spk_addr; // first spike address in the spk train
  logic [$clog2(SPARSE_SIZE)-1:0] spk_cnt, spk_cnt_nxt, total_spks; // number of spikes in the spk train
  logic [$clog2(8*SPARSE_SIZE)-1:0] cumm_spks_nxt;
  logic penc_done; 
  logic post_syn_RAM_loaded_nxt;
  logic [$clog2(SPARSE_SIZE)-1:0] spk_phase, spk_phase_nxt;
  logic [$clog2(INPUT_FRAME_SIZE)-1:0] spk_addr_array [SPARSE_SIZE-1:0];
  logic [$clog2(INPUT_FRAME_SIZE)-1:0] spk_addr_array1 [SPARSE_SIZE-1:0];
  logic arr_copy_done;
  logic en_accum_nxt, en_activ_nxt, new_spk_train_ready_nxt, spk_in_ram_en_nxt;

  logic [$clog2(PENC_SIZE):0] chunk_index, chunk_index_nxt;
  logic [$clog2(INPUT_CHANNELS)+1:0] ic_nxt;
  logic [$clog2(OUTPUT_CHANNELS)+1:0] oc_phase_nxt, oc_phase_intermed;
  logic [$clog2(TIME_STEPS)-1:0] time_step_in_spikes_nxt, time_step_shift;
  logic [$clog2(KERNEL_SIZE)+1:0] filter_phase_nxt; 
  logic [$clog2(4*OUTPUT_FRAME_SIZE)+1:0] neural_lat, neural_lat_nxt;
  logic last_time_step_nxt, ic_done_nxt;
  logic spk_compr_done, spk_compr_done_nxt;
  logic spk_iter_avail;
  logic activate_once_flag;

  typedef enum logic [4:0] {IDLE, WAIT_SPK, OC_ITER, IC_ITER, PENC_CHUNK_LOAD, PENC_CHUNK_ITER, 
  PENC_ADDR_RESET, SPK_ITER, TRANSIT, TRANSIT_1, ACTIVATE, TIME_STEP_ITER, OC_SHIFT, DONE} fsm_state_t;
  fsm_state_t fsm_state, fsm_state_nxt, spk_iter_state;  

  //penc#(PENC_SIZE) p0 (.sparse_in(penc_in), .penc_spk_addr(penc_spk_addr), .penc_done(penc_done));
  penc#(PENC_SIZE) p0 (.sparse_in(penc_in), .penc_spk_addr(penc_spk_addr), .penc_done(penc_done));

  logic [$clog2(INPUT_FRAME_WIDTH)-1:0] affect_neur_addr_y_tmp;
  logic [$clog2(INPUT_FRAME_WIDTH)-1:0] affect_neur_addr_col_tmp;
  
  generate
    genvar i;
    for (i = 0; i < EC_SIZE; i = i + 1) begin
        assign affect_neur_addr_row[i] = affect_neur_addr_row_tmp;
        assign affect_neur_addr_col[i] = affect_neur_addr_col_tmp;
    end
  endgenerate

 logic [$clog2(INPUT_FRAME_SIZE)-1:0] spk_addr1;                                           

assign neur_addr_invalid = 
                      (filter_phase == 0) ? (spk_addr_array1[spk_phase]%INPUT_FRAME_WIDTH < 0) :
                      (filter_phase == 1) ? (spk_addr_array1[spk_phase]%INPUT_FRAME_WIDTH < 1) :
                      (filter_phase == 2) ? (spk_addr_array1[spk_phase]%INPUT_FRAME_WIDTH < 2) :
                      (filter_phase == 3) ? (spk_addr_array1[spk_phase]/INPUT_FRAME_WIDTH < 1) :
                      (filter_phase == 4) ? ((spk_addr_array1[spk_phase]/INPUT_FRAME_WIDTH < 1) || (spk_addr_array1[spk_phase]%INPUT_FRAME_WIDTH < 1)) :
                      (filter_phase == 5) ? ((spk_addr_array1[spk_phase]/INPUT_FRAME_WIDTH < 1) || (spk_addr_array[spk_phase]%INPUT_FRAME_WIDTH < 2)) :
                      (filter_phase == 6) ? (spk_addr_array1[spk_phase]/INPUT_FRAME_WIDTH < 2) :
                      (filter_phase == 7) ? ((spk_addr_array1[spk_phase]/INPUT_FRAME_WIDTH < 2) || (spk_addr_array1[spk_phase]%INPUT_FRAME_WIDTH < 1)) :
                                            ((spk_addr_array1[spk_phase]/INPUT_FRAME_WIDTH < 2) || (spk_addr_array1[spk_phase]%INPUT_FRAME_WIDTH < 2));

  assign affect_neur_addr_col_tmp = 
          (filter_phase == 0 || filter_phase == 3 || filter_phase == 6) ? spk_addr_array1[spk_phase]%INPUT_FRAME_WIDTH - 0 :
          (filter_phase == 1 || filter_phase == 4 || filter_phase == 7) ? spk_addr_array1[spk_phase]%INPUT_FRAME_WIDTH - 1 :
                                                                          spk_addr_array1[spk_phase]%INPUT_FRAME_WIDTH - 2 ;
                                                                          
  assign affect_neur_addr_row_tmp = 
          (filter_phase == 0 || filter_phase == 1 || filter_phase == 2) ? spk_addr_array1[spk_phase]/INPUT_FRAME_WIDTH - 0 :
          (filter_phase == 3 || filter_phase == 4 || filter_phase == 5) ? spk_addr_array1[spk_phase]/INPUT_FRAME_WIDTH - 1 :
                                                                          spk_addr_array1[spk_phase]/INPUT_FRAME_WIDTH - 2 ;
assign spk_addr1 = spk_addr_array1[spk_phase];

    always_ff @(posedge clk) begin
        if(rst) begin
            spk_iter_state <= IDLE;
            spk_phase <= 0;
            spk_iter_avail <= 1;
            neural_lat <= 0;
            filter_phase <= 0;
            en_accum <= 0;
            en_activ <= 0;
            total_spks <= 0;
            time_step_out_spikes <= 0;
            time_step_shift <= 0;
            activate_once_flag <= 1;
        end else begin
            if(time_step_out_spikes == TIME_STEPS - 1) last_time_step <= 1;
            else last_time_step <= 0;
            case(spk_iter_state)
                IDLE: begin
                    en_accum <= 0;
                    spk_iter_avail <= 1;
                    new_spk_train_ready = 0;
                    if (ic_done && activate_once_flag) begin
                        spk_iter_state <= ACTIVATE;
                    end else if(spk_compr_done) begin
                        activate_once_flag <= 1;
                        spk_iter_state <= SPK_ITER;
                        en_accum <= 1;
                        spk_addr_array1 <= spk_addr_array;
                        total_spks <= spk_cnt;
                        if(oc_phase == 0) total_layer_spks_out <= total_layer_spks_in + spk_cnt;
                    end
                end
                SPK_ITER: begin // bram membr pot write
                    spk_iter_avail = 0;
                    if(filter_phase < KERNEL_SIZE*KERNEL_SIZE - 1) begin
                        filter_phase <= filter_phase + 1;  
                    end else begin // if all filters are done, move on to next spk
                        filter_phase <= 0;
                        if(spk_phase < total_spks - 1) begin
                            spk_phase = spk_phase + 1;
                        end else begin
                            spk_phase <= 0;
                            en_accum <= 0;
                            if (ic_done) begin
                                spk_iter_state <= ACTIVATE;
                            end else spk_iter_state <= IDLE;
                        end
                    end
                end 
                ACTIVATE: begin
                    time_step_out_spikes <= time_step_shift;
                    activate_once_flag <= 0;
                    if(neural_lat < OUTPUT_FRAME_SIZE - 2) begin
                        neural_lat = neural_lat + 1;
                        en_activ <= 1;
                    end else begin // move on to the next neuron wght fetch and accum within the neural unit 
                        neural_lat <= 0;
                        en_activ <= 0;
                        new_spk_train_ready = 1;
                        spk_iter_state = IDLE;
                    end 
                end
                
            endcase
        end
    end    

  always_ff @(posedge clk) begin
     penc_in <= penc_in_nxt;
     fsm_state <= fsm_state_nxt;
     spk_cnt <= spk_cnt_nxt;
     post_syn_RAM_loaded <= post_syn_RAM_loaded_nxt;
     chunk_index <= chunk_index_nxt;
     ic <= ic_nxt;
     oc_phase <= oc_phase_nxt;
     time_step_in_spikes <= time_step_in_spikes_nxt;
     spk_compr_done <= spk_compr_done_nxt;
     ic_done <= ic_done_nxt;
     spk_in_ram_en <= spk_in_ram_en_nxt;
     cumm_spks <= cumm_spks_nxt;
  end

  always_comb begin : event_control
    if(rst) begin
      fsm_state_nxt = IDLE;
      penc_in_nxt = 0;
      spk_cnt_nxt = 0;
      en_activ_nxt = 0;
      post_syn_RAM_loaded_nxt = 0;
      chunk_index_nxt = 0;
      ic_nxt = 0;
      oc_phase_nxt = 0;
      time_step_in_spikes_nxt = 0;
      spk_in_ram_en_nxt = 0;
      neural_lat_nxt = 0;
      last_time_step_nxt = 0;
      spk_compr_done_nxt = 0;
      ic_done_nxt = 0;
      cumm_spks_nxt = 0;
      oc_phase_shift = 0;
      oc_phase_intermed = 0;
    end else begin
      fsm_state_nxt = fsm_state;
      penc_in_nxt = penc_in;
      spk_cnt_nxt = spk_cnt;
      post_syn_RAM_loaded_nxt = post_syn_RAM_loaded;
      en_activ_nxt = en_activ;
      chunk_index_nxt = chunk_index;
      ic_nxt = ic;
      spk_in_ram_en_nxt = 0;
      oc_phase_nxt = oc_phase;
      time_step_in_spikes_nxt = time_step_in_spikes;
      neural_lat_nxt = neural_lat;
      last_time_step_nxt = last_time_step;
      spk_compr_done_nxt = spk_compr_done;
      ic_done_nxt = ic_done;
      cumm_spks_nxt = cumm_spks;
      if(spk_iter_avail) ic_done_nxt = 0;
      case (fsm_state)
        IDLE: begin
          post_syn_RAM_loaded_nxt = 0;
          spk_compr_done_nxt = 0;
          if(pre_syn_RAM_loaded) // wait for pre synaptic layer to load spk RAM
            fsm_state_nxt = WAIT_SPK;
            spk_in_ram_en_nxt = 1;
        end
        WAIT_SPK: fsm_state_nxt = PENC_CHUNK_LOAD;
        PENC_CHUNK_LOAD: begin // FM chunks iteration
           for (int i = 0; i < PENC_SIZE; i = i + 1) begin
            if (chunk_index*PENC_SIZE + i < INPUT_FRAME_SIZE) 
              penc_in_nxt[i] = spk_in_train[chunk_index*PENC_SIZE + i];
            else 
              penc_in_nxt[i] = 0;
           end
           fsm_state_nxt = PENC_CHUNK_ITER;
        end
        PENC_CHUNK_ITER: begin
          if(penc_done) begin // a famp is compressed, move on to shifting
            if(chunk_index == (INPUT_FRAME_SIZE + PENC_SIZE - 1) / PENC_SIZE - 1) begin // Check if this is the last chunk
              chunk_index_nxt = 0;
              if(spk_cnt > 0) begin
                spk_compr_done_nxt = 1;
                fsm_state_nxt = TRANSIT; // If it's the last chunk, proceed to the next state
              end else 
                fsm_state_nxt = IC_ITER; // If it's the last chunk and there are no spikes, proceed to the next input channel
            end else begin
              chunk_index_nxt = chunk_index + 1;
              fsm_state_nxt = PENC_CHUNK_LOAD;
            end
          end else begin
            spk_addr_array[spk_cnt] = penc_spk_addr + chunk_index*PENC_SIZE;
            spk_cnt_nxt = spk_cnt + 1;
            fsm_state_nxt = PENC_ADDR_RESET;
          end
        end    
        PENC_ADDR_RESET: begin 
          penc_in_nxt[penc_spk_addr] = 0;
          fsm_state_nxt = PENC_CHUNK_ITER;
        end  
        // if spk_iter avail meaning all spikes in the arr iterated 
        // and if activ part is also done 
        TRANSIT: begin
            if(spk_iter_avail) fsm_state_nxt = IC_ITER;
        end            
        // if new fmap exist then load it, else go to next time step batch
        IC_ITER: begin // time step and in channel iteration
          // reset PENC variables
          spk_cnt_nxt = 0;
          spk_compr_done_nxt = 0;
          spk_addr_array = '{default:0};

          if(ic < INPUT_CHANNELS - 1) begin // process next input channel spikes
            spk_in_ram_en_nxt = 1; // req new spk train
            ic_nxt = ic + 1; // addr 
            fsm_state_nxt = WAIT_SPK;
            cumm_spks_nxt = cumm_spks + spk_cnt;
          end else begin
            ic_done_nxt = 1;
            ic_nxt = 0;
            fsm_state_nxt = TIME_STEP_ITER;
            cumm_spks_nxt = 0;
          end
        end
        TIME_STEP_ITER: begin
            time_step_shift = time_step_in_spikes;
            oc_phase_shift = oc_phase;
            
            if(time_step_in_spikes < TIME_STEPS - 1) begin 
                spk_in_ram_en_nxt = 1;
                time_step_in_spikes_nxt = time_step_in_spikes + 1;
                fsm_state_nxt = WAIT_SPK;
            end else begin // if all time steps are done, move on to next output channel batch
                time_step_in_spikes_nxt = 0;
                fsm_state_nxt = OC_ITER;
            end
        end
        OC_ITER: begin // striding through output channels
          if(oc_phase < (OUTPUT_CHANNELS - 1)/EC_SIZE) begin
            oc_phase_nxt = oc_phase + 1;
            fsm_state_nxt = WAIT_SPK;
            spk_in_ram_en_nxt = 1;
          end else begin // if all output channels are done, this image is done
            oc_phase_nxt = 0;
            fsm_state_nxt = DONE;
          end // done state will send the ready signal to net so next layer can process its spikes
        end
        OC_SHIFT: begin
            fsm_state_nxt = WAIT_SPK;
            oc_phase_intermed = oc_phase;
        end
        DONE: begin
          post_syn_RAM_loaded_nxt = 1;
          fsm_state_nxt = IDLE;
        end
      endcase
    end // rst
  end // always
endmodule

module penc#(parameter PENC_SIZE = 120)
            (input [PENC_SIZE-1:0] sparse_in,
             output logic [$clog2(PENC_SIZE)-1:0] penc_spk_addr,
             output logic penc_done);

  integer i;

  always_comb begin
    penc_done = 1;
    for(i=0; i<PENC_SIZE; i=i+1) begin
      if(sparse_in[i]) begin
        penc_spk_addr = i;
        penc_done = 0;
        break;
      end
    end
  end
endmodule



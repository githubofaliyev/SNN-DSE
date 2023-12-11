`timescale 1ns / 1ps

// for neuron in layer
//  for t in time_steps
//    for neuron in pre_syn_layer 

module fc_ec#(parameter TIME_STEPS = 10,
            parameter EC_SIZE = 4,
            parameter INPUT_CHANNELS = 2,
            parameter LAYER_SIZE = 32,
            parameter PENC_SIZE = 20,
            parameter INPUT_FRAME_SIZE = 120,
            parameter SPARSE_SIZE = INPUT_FRAME_SIZE*INPUT_CHANNELS/4,
            parameter BRAM_DEPTH = LAYER_SIZE*INPUT_CHANNELS*INPUT_FRAME_SIZE,
            parameter BRAM_ADDR_WIDTH = $clog2(BRAM_DEPTH))
    (input clk, rst, 
    input logic pre_syn_RAM_loaded,
    output logic post_syn_RAM_loaded, 
    input [INPUT_FRAME_SIZE-1:0] spk_in_train, 
    output logic spk_in_ram_en,
    output logic [$clog2(INPUT_CHANNELS)+1:0] ic,
    output logic [$clog2(TIME_STEPS)+1:0] penc_time_step,
    output logic [$clog2(TIME_STEPS)+1:0] spk_time_step,
    output logic [$clog2(INPUT_FRAME_SIZE):0] spk_addr,
    output logic [$clog2(LAYER_SIZE)+1:0] neuron,
    logic en_accum, en_activ,
    output logic new_spk_train_ready, last_time_step, post_syn_spk);

  logic [PENC_SIZE-1:0] penc_in, penc_in_nxt;  // takes entire spk train from pre synaptic layer
  logic [$clog2(PENC_SIZE)-1:0] penc_spk_addr; // first spike address in the spk train
  logic [$clog2(SPARSE_SIZE):0] spk_cnt, spk_cnt_nxt; // number of spikes in the spk train
  logic penc_done, post_syn_RAM_loaded_nxt; 
  logic [$clog2(SPARSE_SIZE):0] spk_iter, spk_iter_nxt;
  logic [$clog2(LAYER_SIZE*INPUT_FRAME_SIZE)-1:0] spk_addr_array [TIME_STEPS*SPARSE_SIZE-1:0];
  logic new_spk_train_ready_nxt, spk_in_ram_en_nxt, post_syn_spk_nxt;
  logic spk_concat_stage, spk_concat_stage_nxt;
  logic [8:0] total_spks [TIME_STEPS-1:0];
  logic [8:0] total_spks_nxt [25:0];
  logic spk_compr_done, spk_compr_done_nxt, last_time_step_nxt;
  logic en_accum_nxt, en_activ_nxt;

  logic [$clog2(PENC_SIZE):0] chunk_index, chunk_index_nxt;
  logic [$clog2(INPUT_CHANNELS)+1:0] ic_nxt;
  logic [$clog2(TIME_STEPS)+1:0] penc_time_step_nxt, spk_time_step_nxt;
  logic [$clog2(LAYER_SIZE)+1:0] neuron_nxt;
  logic [INPUT_CHANNELS*INPUT_FRAME_SIZE-1:0] concat_spk_train;
  logic [$clog2(INPUT_FRAME_SIZE):0] spk_addr_nxt;

  typedef enum logic [4:0] {IDLE, NEUR_ITER, IC_ITER, PENC_CHUNK_LOAD, PENC_CHUNK_ITER, 
  PENC_ADDR_RESET, CONCAT_SPK, TRANSIT, SPK_ITER, ACTIVATE, TIME_STEP_ITER, DONE} fsm_state_t;
  fsm_state_t penc_state, penc_state_nxt, spk_iter_state, spk_iter_state_nxt;  

  penc#(PENC_SIZE) p0 (.sparse_in(penc_in), .penc_spk_addr(penc_spk_addr), .penc_done(penc_done));
                                                                            
  always_ff @(posedge clk) begin
     penc_in <= penc_in_nxt;
     penc_state <= penc_state_nxt;
     spk_cnt <= spk_cnt_nxt;
     spk_iter <= spk_iter_nxt;
     post_syn_RAM_loaded <= post_syn_RAM_loaded_nxt;
     chunk_index <= chunk_index_nxt;
     ic <= ic_nxt;
     penc_time_step <= penc_time_step_nxt;
     spk_iter_state <= spk_iter_state_nxt;
     spk_time_step <= spk_time_step_nxt;
     neuron <= neuron_nxt;
     spk_in_ram_en <= spk_in_ram_en_nxt;
     new_spk_train_ready <= new_spk_train_ready_nxt;
     post_syn_spk <= post_syn_spk_nxt;
     last_time_step <= last_time_step_nxt;
     en_accum <= en_accum_nxt;
     en_activ <= en_activ_nxt;
     spk_concat_stage <= spk_concat_stage_nxt;
     spk_compr_done <= spk_compr_done_nxt;
     spk_addr <= spk_addr_nxt;
     for(int i=0; i<25; i++) total_spks[i] <= total_spks_nxt[i];
  end

  always_comb begin : event_control
    if(rst) begin
      penc_state_nxt = IDLE;
      penc_in_nxt = 0;
      spk_cnt_nxt = 0;
      chunk_index_nxt = 0;
      ic_nxt = 0;
      penc_time_step_nxt = 0;
      spk_in_ram_en_nxt = 0;
      spk_concat_stage_nxt = 0;
      spk_compr_done_nxt = 0;
      for(int i=0; i<25; i++) total_spks_nxt[i] = 0;
    end else begin
      penc_state_nxt = penc_state;
      penc_in_nxt = penc_in;
      spk_cnt_nxt = spk_cnt;
      chunk_index_nxt = chunk_index;
      ic_nxt = ic;
      penc_time_step_nxt = penc_time_step;
      spk_in_ram_en_nxt = 0;
      spk_concat_stage_nxt = spk_concat_stage;
      spk_compr_done_nxt = spk_compr_done;
      for(int i=0; i<25; i++) total_spks_nxt[i] = total_spks[i];
      case (penc_state)
        IDLE: begin 
          spk_compr_done_nxt = 0;
          if(pre_syn_RAM_loaded) // wait for pre synaptic layer to load spk RAM
            penc_state_nxt = CONCAT_SPK; 
            spk_in_ram_en_nxt = 1; // read first spk from RAM
            concat_spk_train = '{default:0};
        end
        CONCAT_SPK: begin
            if(spk_concat_stage) begin
                if(INPUT_CHANNELS == 1)
                    concat_spk_train = spk_in_train;
                else
                    concat_spk_train = {spk_in_train, concat_spk_train[INPUT_CHANNELS*INPUT_FRAME_SIZE-1:INPUT_FRAME_SIZE]};
            end
            if(ic < INPUT_CHANNELS) begin 
                spk_in_ram_en_nxt = 1;
                ic_nxt = ic + 1;
                spk_concat_stage_nxt = 1;
            end else begin 
                ic_nxt = 0;
                spk_concat_stage_nxt = 0;
                penc_state_nxt = PENC_CHUNK_LOAD;
            end
        end
        PENC_CHUNK_LOAD: begin 
           for (int i = 0; i < PENC_SIZE; i = i + 1) begin
            if (chunk_index*PENC_SIZE + i < INPUT_CHANNELS*INPUT_FRAME_SIZE) 
              penc_in_nxt[i] = concat_spk_train[chunk_index*PENC_SIZE + i];
            else 
              penc_in_nxt[i] = 0;
           end
           penc_state_nxt = PENC_CHUNK_ITER;
        end
        PENC_CHUNK_ITER: begin
          if(penc_done) begin // a famp is compressed, move onto shifting
            if(chunk_index == (INPUT_CHANNELS*INPUT_FRAME_SIZE + PENC_SIZE - 1) / PENC_SIZE - 1) begin // Check if this is the last chunk
              chunk_index_nxt = 0;
              penc_state_nxt = TIME_STEP_ITER; 
            end else begin
              chunk_index_nxt = chunk_index + 1;
              penc_state_nxt = PENC_CHUNK_LOAD;
            end
          end else begin
            spk_addr_array[penc_time_step*SPARSE_SIZE + spk_cnt] = penc_spk_addr + chunk_index*PENC_SIZE;
            spk_cnt_nxt = spk_cnt + 1;
            penc_state_nxt = PENC_ADDR_RESET;
          end
        end    
        PENC_ADDR_RESET: begin 
          penc_in_nxt[penc_spk_addr] = 0;
          penc_state_nxt = PENC_CHUNK_ITER;
        end    
        TIME_STEP_ITER: begin
            concat_spk_train = '{default:0};
            total_spks_nxt[penc_time_step] = spk_cnt;
            spk_cnt_nxt = 0;
            if(penc_time_step < TIME_STEPS - 1) begin 
                spk_in_ram_en_nxt = 1;
                penc_time_step_nxt = penc_time_step + 1;
                penc_state_nxt = CONCAT_SPK;
            end else begin // if all time steps are done, move on to next output channel batch
                penc_time_step_nxt = 0;
                penc_state_nxt = DONE;
            end
        end
        DONE: begin
          spk_compr_done_nxt = 1;
          //post_syn_RAM_loaded_nxt = 1;
          //penc_state_nxt = IDLE;
        end
      endcase
    end // rst
  end // always

  always_comb begin : spk_iter_block
    if(rst) begin
      spk_iter_state_nxt = IDLE;
      spk_iter_nxt = 0;
      post_syn_RAM_loaded_nxt = 0;
      spk_time_step_nxt = 0;
      neuron_nxt = 0;
      new_spk_train_ready_nxt = 0;
      last_time_step_nxt = 0;
      en_accum_nxt = 0;
      en_activ_nxt = 0;
      spk_addr_nxt = 0;
    end else begin
      spk_iter_state_nxt = spk_iter_state;
      post_syn_RAM_loaded_nxt = post_syn_RAM_loaded;
      spk_iter_nxt = spk_iter;
      spk_time_step_nxt = spk_time_step;
      neuron_nxt = neuron;
      new_spk_train_ready_nxt = 0;
      en_accum_nxt = 0;
      en_activ_nxt = 0;
      spk_addr_nxt = spk_addr;
      case (spk_iter_state)
        IDLE: begin 
          post_syn_RAM_loaded_nxt = 0;
          if(spk_compr_done) spk_iter_state_nxt = SPK_ITER; 
        end
        SPK_ITER: begin
            if(total_spks[spk_time_step] == 0) spk_iter_state_nxt = ACTIVATE;
            else if(spk_iter < total_spks[spk_time_step] - 1) begin
                spk_iter_nxt = spk_iter + 1;
                spk_addr_nxt = spk_addr_array[spk_time_step*SPARSE_SIZE + spk_iter];
                en_accum_nxt = 1;
            end else begin
                spk_iter_nxt = 0;
                en_activ_nxt = 1;
                spk_iter_state_nxt = ACTIVATE;
            end
        end      
        ACTIVATE: begin
            new_spk_train_ready_nxt = 1;
            spk_iter_state_nxt = TIME_STEP_ITER;
            if(spk_time_step == TIME_STEPS - 1) last_time_step_nxt = 1;
        end
        TIME_STEP_ITER: begin
            last_time_step_nxt = 0;
            if(spk_time_step < TIME_STEPS - 1) begin 
                spk_time_step_nxt = spk_time_step + 1;
                spk_iter_state_nxt = SPK_ITER;
            end else begin // if all time steps are done, move on to next output channel batch
                spk_time_step_nxt = 0;
                spk_iter_state_nxt = NEUR_ITER;
            end
        end
        NEUR_ITER: begin 
          if(neuron_nxt < LAYER_SIZE - EC_SIZE) begin
            neuron_nxt = neuron + EC_SIZE;
            spk_iter_state_nxt = SPK_ITER;
          end else begin // if all output channels are done, this image is done
            neuron_nxt = 0;
            spk_iter_state_nxt = DONE;
          end // done state will send the ready signal to net so next layer can process its spikes
        end
        DONE: begin
          post_syn_RAM_loaded_nxt = 1;
          //spk_iter_state_nxt = IDLE;
        end
      endcase
    end // rst
  end // always


endmodule




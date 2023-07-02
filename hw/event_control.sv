`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 04/12/2023 05:34:22 PM
// Design Name: 
// Module Name: event_control
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module event_control(input clk, rst, post_synp_avail,
                     input [31:0] pre_synpt_spk,
                     input [31:0] neuron_spk_in,
                     output logic [31:0] post_synp_spk_buffer,
                     output logic [4:0] shift_cnt,
                     output logic en_accum, en_activ);

  parameter EC_SIZE = 32;
  parameter NEURAL_SIZE = 2;

  logic [4:0] time_step, time_step_nxt;
  logic [31:0] penc_in, penc_in_nxt;
  logic [4:0] penc_spk_addr;
  logic [4:0] spk_cnt, spk_cnt_nxt;
  logic done;
  logic en_accum_nxt;
  logic en_activ_nxt;

  logic [2:0] fsm_state, fsm_state_nxt;
  logic [4:0] shift_cnt_nxt;
  logic [4:0] set_spk_array [31:0];
  logic [4:0] set_spk_array_nxt [31:0];
  logic [31:0] ec_buffer, ec_buffer_nxt;
  logic [31:0] post_synp_spk_buffer_nxt;
  logic [5:0] wait_cnt, wait_cnt_nxt;

  int i, j, k;
  int shifted_spk_addr;

  penc p0 (penc_in, penc_spk_addr, done);

  always_ff @(posedge clk) begin
    penc_in <= penc_in_nxt;
    fsm_state <= fsm_state_nxt;
    spk_cnt <= spk_cnt_nxt;
    shift_cnt <= shift_cnt_nxt;
    en_accum <= en_accum_nxt;
    en_activ <= en_activ_nxt;
    wait_cnt <= wait_cnt_nxt;
    post_synp_spk_buffer <= post_synp_spk_buffer_nxt;
  end

  always_comb begin : event_control
    if(rst) begin
      fsm_state_nxt = 0;
      penc_in_nxt = 0;
      spk_cnt_nxt = 0;
      shift_cnt_nxt = 0;
      en_accum_nxt = 0;
      en_activ_nxt = 0;
      post_synp_spk_buffer_nxt = 0;
      wait_cnt_nxt = 0;
    end else begin
      fsm_state_nxt = fsm_state;
      penc_in_nxt = penc_in;
      spk_cnt_nxt = spk_cnt;
      shift_cnt_nxt = shift_cnt;
      en_accum_nxt = en_accum;
      en_activ_nxt = en_activ;
      post_synp_spk_buffer_nxt = post_synp_spk_buffer;
      wait_cnt_nxt = wait_cnt;

      case (fsm_state)
        0: begin // PENC_0: original spike array 
          penc_in_nxt = pre_synpt_spk;
          fsm_state_nxt = 2;
        end
        1: begin // PENC_1: resetting set bit
          penc_in_nxt[penc_spk_addr] = 0;
          fsm_state_nxt = 2;
        end
        2: begin // PENC_2: filling PENC spk array with set bit addresses
          if(done) fsm_state_nxt = 3;
          else begin
            set_spk_array_nxt[spk_cnt] = penc_spk_addr;
            spk_cnt_nxt = spk_cnt + 1;
            fsm_state_nxt = 1;
          end
        end
        3: begin // ACCUM_1: shift phase update
          shift_cnt_nxt = shift_cnt + 1;
          fsm_state_nxt = 4;
          en_accum_nxt = 1;
//          for(i=0; i<EC_SIZE; i++) begin
//            shifted_spk_addr = i + shift_cnt;
//            if(shifted_spk_addr > spk_cnt) shifted_spk_addr = shifted_spk_addr - spk_cnt;
//            neuron_spk_addr_nxt[i] = set_spk_array[shifted_spk_addr];
//            $display("i=%d, shifted_neuron_no=%d", i, shifted_spk_addr);
//          end
        end
        4: begin // ACCUM_2: wait for neuron done: fixed number of cycles for each unit, move on with 
          if(wait_cnt < 2*NEURAL_SIZE) wait_cnt_nxt = wait_cnt + 1; // assumption: if 4 neuron within neural unit, and each neuron 2 cycle
          else begin
            wait_cnt_nxt = 0;
            if(shift_cnt > spk_cnt) begin
                shift_cnt_nxt = 0;
                fsm_state_nxt = 5;
                en_accum_nxt = 0;
            end else
                fsm_state_nxt = 3;
          end

          //for(i=0; i<EC_SIZE; i++) begin
          //  $display("i=%d, set_spk_array=%d, neuron_spk_addr=%d", i, set_spk_array[i], neuron_spk_addr[i]);
          //end
        end 
        5: begin
          if(post_synp_avail) begin
            post_synp_spk_buffer_nxt = neuron_spk_in;
            en_activ_nxt = 1;
            fsm_state_nxt = 0;
            time_step_nxt = time_step + 1;
            // buffer_aval_nxt = 0; in the next layer's ec
            // neuron_out_nxt = 0; in else statement of the threshold comparison
          end
        end
      endcase
    end // rst

    //$display("penc_spk_addr = %d, fsm_state = %d, spk_cnt = %d", penc_spk_addr, fsm_state, spk_cnt);
  end // always

endmodule


// parametrize width
module penc (input [31:0] sparse_in, output logic [4:0] penc_spk_addr, output logic done);
    always_comb begin
        done = 0;
        penc_spk_addr = 0;
        if(sparse_in[0]) penc_spk_addr = 0;
        else if(sparse_in[1]) penc_spk_addr = 1;
        else if(sparse_in[2]) penc_spk_addr = 2;
        else if(sparse_in[3]) penc_spk_addr = 3;
        else if(sparse_in[4]) penc_spk_addr = 4;
        else if(sparse_in[5]) penc_spk_addr = 5;
        else if(sparse_in[6]) penc_spk_addr = 6;
        else if(sparse_in[7]) penc_spk_addr = 7;
        else if(sparse_in[8]) penc_spk_addr = 8;
        else if(sparse_in[9]) penc_spk_addr = 9;
        else if(sparse_in[10]) penc_spk_addr = 10;
        else if(sparse_in[11]) penc_spk_addr = 11;
        else if(sparse_in[12]) penc_spk_addr = 12;
        else if(sparse_in[13]) penc_spk_addr = 13;
        else if(sparse_in[14]) penc_spk_addr = 14;
        else if(sparse_in[15]) penc_spk_addr = 15;
        else if(sparse_in[16]) penc_spk_addr = 16;
        else if(sparse_in[17]) penc_spk_addr = 17;
        else if(sparse_in[18]) penc_spk_addr = 18;
        else if(sparse_in[19]) penc_spk_addr = 19;
        else if(sparse_in[20]) penc_spk_addr = 20;
        else if(sparse_in[21]) penc_spk_addr = 21;
        else if(sparse_in[22]) penc_spk_addr = 22;
        else if(sparse_in[23]) penc_spk_addr = 23;
        else if(sparse_in[24]) penc_spk_addr = 24;
        else if(sparse_in[25]) penc_spk_addr = 25;
        else if(sparse_in[26]) penc_spk_addr = 26;
        else if(sparse_in[27]) penc_spk_addr = 27;
        else if(sparse_in[28]) penc_spk_addr = 28;
        else if(sparse_in[29]) penc_spk_addr = 29;
        else if(sparse_in[30]) penc_spk_addr = 30;
        else if(sparse_in[31]) penc_spk_addr = 31;
        else done = 1;
    end

 endmodule


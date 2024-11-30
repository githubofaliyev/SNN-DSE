`timescale 1ns / 1ps

module fc_nc #(
    parameter NEURON_OFFSET = 0, 
    parameter IN_CHANNELS = 2,
    parameter INPUT_FRAME_SIZE = 28,
    parameter LAYER_SIZE = 10,
    parameter BRAM_ADDR_WIDTH = 10,
    parameter BIT_WIDTH = 31,
    parameter w_sfactor = 0.24,
    parameter b_sfactor = 0.54,
    parameter w_zpt = 0.24,
    parameter b_zpt = 0.54
  )(
  input logic clk, rst,
  input en_accum, en_activ, last_time_step,
  input logic [$clog2(LAYER_SIZE)-1:0] neuron,
  input logic [$clog2(INPUT_FRAME_SIZE)-1:0] spk_addr,
  output logic post_syn_spk,

  input logic [BIT_WIDTH:0] bram_rdat,
   output logic [BRAM_ADDR_WIDTH-1:0] bram_raddr,
   output logic bram_ren
  );
  

  logic [31:0] signed_POSITIVE_THRESHOLD = 32'h3F800000; // 1.0 in IEEE 754 floating-point
  logic [31:0] membr_pot, membr_pot_nxt;
  logic [31:0] BETA = 32'h3F800000;

  logic [3:0] fsm_state, fsm_state_nxt;
  logic post_syn_spk_nxt;
 
  always_ff @(posedge clk) begin
    fsm_state <=  fsm_state_nxt;
    post_syn_spk <= post_syn_spk_nxt;
    membr_pot <= membr_pot_nxt;
  end

  always_comb begin : event_control
    if(rst) begin
      fsm_state_nxt = 0;
      post_syn_spk_nxt = 0;
      bram_ren = 0;
      bram_raddr = 0;
      membr_pot_nxt = 0;
    end else begin
      fsm_state_nxt = fsm_state;
      post_syn_spk_nxt = post_syn_spk;
      bram_ren = 0;
      membr_pot_nxt = membr_pot;
      case (fsm_state)
        0: begin
          if(en_accum) fsm_state_nxt = 1;   
        end
        1: begin // accum add
            bram_ren = 1;
            if(en_activ) begin
                fsm_state_nxt = 2;  
                bram_raddr = (neuron+1)*IN_CHANNELS*INPUT_FRAME_SIZE; 
            end else begin
                membr_pot_nxt = membr_pot + bram_rdat<<30 + bram_rdat<<24 + bram_rdat<<19; // scaling weight from int4 to fp32
                bram_raddr = (neuron + NEURON_OFFSET)*IN_CHANNELS*INPUT_FRAME_SIZE + spk_addr;
            end
        end
        2: begin
           if((membr_pot + (bram_rdat-b_zpt)) > signed_POSITIVE_THRESHOLD) begin 
                post_syn_spk_nxt = 1;
                membr_pot_nxt = (membr_pot + (bram_rdat-b_zpt) - signed_POSITIVE_THRESHOLD)*BETA;
            end else begin
                post_syn_spk_nxt = 0;
                membr_pot_nxt = (membr_pot + (bram_rdat-b_zpt))*BETA;
            end
            if(last_time_step) membr_pot_nxt = 0;
            fsm_state_nxt = 0; 
        end
      endcase
    end // rst

  end // always

endmodule

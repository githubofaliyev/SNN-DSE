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
    parameter BIT_WIDTH = 31,
    parameter w_sfactor = 0.24,
    parameter b_sfactor = 0.54,
    parameter w_zpt = 0.24,
    parameter b_zpt = 0.54,
    parameter string WEIGHT_FILENAME = "/sim_1/new/weight_file_0_3.txt"
  )(
  input logic clk, rst,
  input en_accum, en_activ,
  input last_time_step,
  input ic_done,
  input logic [$clog2(IN_CHANNELS)+1:0] ic,
  input logic [$clog2(KERNEL_SIZE)+1:0] filter_phase,
  input logic [$clog2(OUT_CHANNELS)+1:0] oc_phase,
  input logic [$clog2(INPUT_FRAME_WIDTH)-1:0] affect_neur_addr_y,
  input logic [$clog2(INPUT_FRAME_WIDTH)-1:0]affect_neur_addr_x,
  input logic neur_addr_invalid,

  output logic [OUTPUT_FRAME_WIDTH*OUTPUT_FRAME_WIDTH-1:0] post_syn_spk,
  input logic [31:0] bram_rdat,
  output logic [31:0] bram_wrdat,
  output logic [BRAM_ADDR_WIDTH-1:0] bram_raddr, 
  output logic bram_ren,
  output logic [BRAM_ADDR_WIDTH-1:0] bram_wraddr,
  output logic bram_wren,
  
  input logic [31:0] data_rd,
  output logic [20:0] addr_rd,
  output logic en_rd
  );
  
    logic [31:0] signed_POSITIVE_THRESHOLD = 32'h3F800000; // 1.0 in IEEE 754 floating-point
    logic [31:0] membr_pot, membr_pot_nxt;
    logic [31:0] BETA = 32'h3F800000;

  logic [3:0] fsm_state, fsm_state_nxt;
  logic [OUTPUT_FRAME_WIDTH*OUTPUT_FRAME_WIDTH-1:0] post_syn_spk_nxt;
  logic accum_membr_calc_stage, accum_membr_calc_stage_nxt;
  logic activ_membr_calc_stage, activ_membr_calc_stage_nxt;
  logic [BRAM_ADDR_WIDTH-1:0] intermed_addr, intermed_addr_nxt;

  //logic [BIT_WIDTH:0] weight_n_bias[(OUT_CHANNELS/EC_SIZE)*(IN_CHANNELS*KERNEL_SIZE*KERNEL_SIZE + 1) - 1:0]; // weight_n_bias and bias
  //logic [BIT_WIDTH:0] weight_n_bias[8*IN_CHANNELS*KERNEL_SIZE*KERNEL_SIZE:0]; // weight_n_bias and bias

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
            end else begin // if addr valid then do accum add and bram wr
                bram_raddr = affect_neur_addr_y*INPUT_FRAME_WIDTH +affect_neur_addr_x;
                intermed_addr_nxt = bram_raddr;
                bram_ren = 1;
                accum_membr_calc_stage_nxt = 1;
            end
           
           en_rd = 0;
           if(accum_membr_calc_stage) begin
            addr_rd = oc_phase + ic  + filter_phase;
            en_rd = 1;
            bram_wrdat = bram_rdat + {28'b0, data_rd}<<30 + {28'b0, data_rd}<<24 + {28'b0, data_rd}<<22; 
            bram_wraddr = intermed_addr;
            bram_wren = 1; 
           end

        end
        7: begin // next spike delay
            fsm_state_nxt = 0;
            en_rd = 0;
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
            addr_rd = KERNEL_SIZE * KERNEL_SIZE;
            en_rd = 1;
            membr_pot_nxt = {28'b0, data_rd}<<30 + {28'b0, data_rd}<<26 + {28'b0, data_rd}<<21  + {28'b0, data_rd};
            
            if(activ_membr_calc_stage) begin
                bram_wraddr = intermed_addr;
                bram_wren = 1; 
                if(membr_pot > signed_POSITIVE_THRESHOLD) begin 
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

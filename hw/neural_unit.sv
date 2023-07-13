module neural #(
    parameter NEURAL_SIZE = 4,
    parameter PRE_SYN_LAYER_SIZE = 16,
    parameter FIXED_POINT_WIDTH = 32, // Total width is 32 bits
    parameter INTEGER_WIDTH = 2, // We have 2 bits for the integer part
    parameter FRACTIONAL_WIDTH = 30, // And 30 bits for the fractional part
    parameter BRAM_ADDR_WIDTH = 10,
    parameter POSITIVE_THRESHOLD = 32'b00111001100110011001100110011010,
    parameter BIAS = 32'b00111001100110011001100110011010,
    parameter BETA = 32'b00111001100110011001100110011010 // Decay factor for the LIF neuron
  )(
  input logic clk, rst,
  input en_accum, en_activ,
  input logic [$clog2(PRE_SYN_LAYER_SIZE)-1:0] spk_addr,
  input logic signed [FIXED_POINT_WIDTH-1:0] bram_rdat, // Read data from BRAM in Q2.30 format
  output logic [BRAM_ADDR_WIDTH-1:0] bram_addr,
  output logic bram_en,
  output logic [NEURAL_SIZE-1:0] post_syn_spk
  );

  logic [2:0] fsm_state, fsm_state_nxt;
  logic signed [FIXED_POINT_WIDTH-1:0] accum_val[NEURAL_SIZE-1:0], accum_val_nxt[NEURAL_SIZE-1:0];
  logic signed [FIXED_POINT_WIDTH-1:0] pot[NEURAL_SIZE-1:0], pot_nxt[NEURAL_SIZE-1:0];
  logic bram_en_nxt;
  logic [BRAM_ADDR_WIDTH-1:0] bram_addr_nxt;
  logic [NEURAL_SIZE-1:0] unit_neuron_idx, unit_neuron_idx_nxt;
  logic [NEURAL_SIZE-1:0] post_syn_spk_nxt;

  always_ff @(posedge clk) begin
    fsm_state <= fsm_state_nxt;
    bram_addr <= bram_addr_nxt;
    bram_en <= bram_en_nxt;
    unit_neuron_idx <= unit_neuron_idx_nxt;
    post_syn_spk <= post_syn_spk_nxt;
    for (int i = 0; i < NEURAL_SIZE; i = i + 1) begin
        accum_val[i] <= accum_val_nxt[i];
        pot[i] <= pot_nxt[i];
      end 
  end

  always_comb begin : event_control
    if(rst) begin
      fsm_state_nxt = 0;
      bram_addr_nxt = 0;
      bram_en_nxt = 0;
      unit_neuron_idx_nxt = 0;
      post_syn_spk_nxt = 0;
      for (int i = 0; i < NEURAL_SIZE; i = i + 1) begin
        accum_val_nxt[i] = 0;
        pot_nxt[i] = 0;
      end 
    end else begin
      fsm_state_nxt = fsm_state;
      bram_addr_nxt = bram_addr;
      bram_en_nxt = bram_en;
      accum_val_nxt = accum_val;
      unit_neuron_idx_nxt = unit_neuron_idx;
      pot_nxt = pot;
      post_syn_spk_nxt = post_syn_spk;
      for (int i = 0; i < NEURAL_SIZE; i = i + 1) begin
        accum_val_nxt[i] = accum_val[i];
        pot_nxt[i] = pot[i];
      end 
      case (fsm_state)
        0: begin // next shift wait
          unit_neuron_idx_nxt = 0;
          if(en_accum) fsm_state_nxt = 1;
          else if(en_activ) fsm_state_nxt = 4;
        end
        1: begin
          if(unit_neuron_idx == NEURAL_SIZE-1) unit_neuron_idx_nxt = 0; // reset neuron idx
          else unit_neuron_idx_nxt = unit_neuron_idx + 1;
          
          bram_addr_nxt =  unit_neuron_idx*NEURAL_SIZE + spk_addr; 
          bram_en_nxt = 1;
          fsm_state_nxt = 2;

        end
        2: fsm_state_nxt = 3; // bram data read stage
        3: begin
          bram_en_nxt = 0;
          accum_val_nxt[unit_neuron_idx] = accum_val[unit_neuron_idx] + bram_rdat; // accumulate with the corresponding weight data
          if(en_accum) fsm_state_nxt = 1;
          else fsm_state_nxt = 0;
        end
        4: begin
          pot_nxt[unit_neuron_idx] = pot[unit_neuron_idx]*BETA + accum_val[unit_neuron_idx] + BIAS;
          fsm_state_nxt = 5;
        end
        5: begin
          if(pot[unit_neuron_idx] > POSITIVE_THRESHOLD) begin 
            post_syn_spk_nxt[unit_neuron_idx] = 1;
            pot_nxt[unit_neuron_idx] = accum_val[unit_neuron_idx] - POSITIVE_THRESHOLD;
          end else
            post_syn_spk_nxt[unit_neuron_idx] = 0;

          if(unit_neuron_idx == NEURAL_SIZE-1) fsm_state_nxt = 6; // reset neuron idx
          else begin
            fsm_state_nxt = 4;
            unit_neuron_idx_nxt = unit_neuron_idx + 1;
          end 

          accum_val_nxt[unit_neuron_idx] = 0; // clear the accumulator
        end
        6: fsm_state_nxt = 0;
      endcase
    end // rst

  end // always

endmodule

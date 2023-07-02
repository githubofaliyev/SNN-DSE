module neural #(parameter UNIT_IDX=5, EC_SIZE=32)
  (input logic clk,
   input logic rst,
   input logic [4:0] shift_phase,
   input logic activ_en, layer_activ,
   output logic post_synpt_spk
   );

  parameter NEURON_UNIT_SIZE = 2;
  parameter LAYER_SIZE = 10;
  parameter BETA = 2;
  parameter POSITIVE_THRESHOLD = 1;
  parameter bias = 3;

  logic [2:0] fsm_state, fsm_state_nxt;
  logic signed [31:0] accum_val, accum_val_nxt;
  logic signed [31:0] pot_val, pot_val_nxt;
  logic post_synpt_spk_nxt;
  
  logic [31:0] wdata, wdata1;
  logic bram_en, bram_en_nxt;
  logic [9:0] addr;
  logic [9:0] addr_nxt;

  logic [9:0] unit_neuron_idx, unit_neuron_idx_nxt;
  int layer_neuron_idx;
  
  (* dont_touch = "true" *) my_bram B0(clk, addr, wdata1, bram_en, wdata);

  always_ff @(posedge clk) begin
    fsm_state <= fsm_state_nxt;
    addr <= addr_nxt;
    bram_en <= bram_en_nxt;
    accum_val <= accum_val_nxt;
    unit_neuron_idx <= unit_neuron_idx_nxt;
    post_synpt_spk <= post_synpt_spk_nxt;
    pot_val <= pot_val_nxt;
  end

  always_comb begin : event_control
    if(rst) begin
      fsm_state_nxt = 0;
      addr_nxt = 0;
      bram_en_nxt = 0;
      accum_val_nxt = 0;
      unit_neuron_idx_nxt = 0;
      pot_val_nxt = 0;
      post_synpt_spk_nxt = 0;
    end else begin
      fsm_state_nxt = fsm_state;
      addr_nxt = addr;
      bram_en_nxt = 0;
      accum_val_nxt = accum_val;
      unit_neuron_idx_nxt = 0;
      pot_val_nxt = pot_val;
      post_synpt_spk_nxt = post_synpt_spk;

      case (fsm_state)
        0: begin
          if(activ_en) fsm_state_nxt = 1;
          else if(layer_activ) fsm_state_nxt = 3;
        end
        1: begin
          // 
          if(unit_neuron_idx < NEURON_UNIT_SIZE) begin // serially go through each neuron within the neural unit
            // now to addr into pre-synapt neuron, we need that shift array
            layer_neuron_idx =  UNIT_IDX + unit_neuron_idx; // layer neuron id
            unit_neuron_idx_nxt = unit_neuron_idx + 1;
            addr_nxt = shift_phase + layer_neuron_idx; // this actually needs to address into shift reg array to fetch the actual neuron addr of the pre-synapt layer
            bram_en_nxt = 1;
            fsm_state_nxt = 2;
          end else // done iterating unit neurons, now get the new shifted spk set for this unit
            fsm_state_nxt = 0;
        // reading shifted spk addr will be handled in top-level connection phase
        // for now we assume that an input signal gives us that
        end
        2: begin
          accum_val_nxt = accum_val + wdata; // accumulate with the corresponding weight data
          fsm_state_nxt = 1;
        end
        3: begin
          if(unit_neuron_idx < NEURON_UNIT_SIZE) begin // serially go through each neuron within the neural unit
                layer_neuron_idx = UNIT_IDX*NEURON_UNIT_SIZE + unit_neuron_idx; // layer neuron id
                pot_val_nxt = pot_val + accum_val + bias;
                unit_neuron_idx_nxt = unit_neuron_idx + 1;
                fsm_state_nxt = 4;
          end else // done iterating unit neurons, done activation
            fsm_state_nxt = 0;
        end
        4: begin
          if(pot_val > POSITIVE_THRESHOLD) begin
            post_synpt_spk_nxt = 1;
            pot_val_nxt = pot_val - POSITIVE_THRESHOLD;
          end
          fsm_state_nxt = 1;
        end
      endcase
    end // rst

  end // always

endmodule


module my_bram(
  input  logic         clk,
  input  logic [9:0]   addr,
  input logic signed [31:0]  data_in,
  input  logic         wr_en,
  output logic signed [31:0]  data_out
);

  // Create a 10-bit wide by 32-bit deep BRAM
  logic signed [31:0] mem [1023:0];

  // Instantiate Block RAM primitive
  reg [31:0] bram_out;
  reg [9:0] bram_addr;
  reg signed [31:0] bram_data;
  wire [31:0] bram_we;

  (* ram_style = "block" *)
  (* synthesis_primitive = "MEMORY_PRIMITIVE" *)
  (* implementation = "memory" *)
  (* mem_gen_type = "block" *)
  (* mem_style = "block_ram" *)
  reg [31:0] my_bram [0:1023];

  // Assign signals to BRAM primitive inputs
  assign bram_we = wr_en;
  assign bram_addr = addr;
  assign bram_data = data_in;

  // Read or write data to the BRAM based on address and control signals
  always_ff @(posedge clk) begin
    if (wr_en) begin
      my_bram[addr] <= data_in;
    end else begin
      data_out <= my_bram[addr];
    end
  end

endmodule

/*
module BlockRAM(input logic clk, rst, en,
                (* dont_touch = "true" *) input logic [9:0] addr,
                (* dont_touch = "true" *)output logic [31:0] wdata
                );
        
        (* ram_style = "block" *) reg [31
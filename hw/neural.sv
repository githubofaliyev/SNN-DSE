/* - Handicap: accum_val/pot_val can't be adjusted for neural size. 
	 in SystemC, this is easily done by decling those vars as arry in global_vars
     so we'll remain as single var for all unit neurons, will impact area, maybe check when have 3 instance for each of those vars, how single unit FF/LUT changes
   - the only issue is when mapping 4-1 non-increasing FF number for Acuum and Pot values
   - but let's compensate this with the fact that ivado will do tons of optimization to decrease area
   - so our hand calculated number even could be more than full synthesis one with the neglected FFs
*/

// connect spk address generated in event control into here, add from unit idx into somewhat addressing into that spk array
// some waiting protocol needed to be done for single shifting vs accum for all unit neurons 
// 	appropriate number of cycles to be waited for event control so that neural unit is done depends on unit size 
// 	for neural, wait cycle is fixed since time for a single shift is always fixed so add this protocol shit insteaf od neural anding op
// add activation part also 
// accum and pot variables also need to be adjusted to unit size, e.g., an array of 5 for size=5
// how to fetch bias?
// how to use layer_neuron_idx for pot_val access?
// Block RAM unit creation 

/* - Handicap: accum_val/pot_val can't be adjusted for neural size. 
	 in SystemC, this is easily done by decling those vars as arry in global_vars
     so we'll remain as single var for all unit neurons, will impact area, maybe check when 	 have 3 instance for each of those vars, how single unit FF/LUT changes
   - 
*/

// connect spk address generated in event control into here, add from unit idx into somewhat addressing into that spk array
// some waiting protocol needed to be done for single shifting vs accum for all unit neurons 
// 	appropriate number of cycles to be waited for event control so that neural unit is done depends on unit size 
// 	for neural, wait cycle is fixed since time for a single shift is always fixed so add this protocol shit insteaf od neural anding op
// how to fetch bias?
// how to use layer_neuron_idx for pot_val access?

module neural #(parameter UNIT_IDX=0, EC_SIZE=2)
  (input logic clk, 
   input logic rst, 
   input logic layer_acc, layer_act,
   input logic [4:0] base_spk_addr,
   input logic [31:0] wdata, 
   output logic [9:0] addr);
  
  parameter NEURON_UNIT_SIZE = 2;
  parameter LAYER_SIZE = 10;
  parameter BETA = 2;
  parameter POSITIVE_THRESHOLD = 1;
  parameter bias = 3;
  
  logic [2:0] neuron_st, neuron_st_nxt;
  logic [9:0] addr_nxt;
  logic signed [31:0] accum_val, accum_val_nxt;
  logic signed [31:0] pot_val, pot_val_nxt;
  
  logic [9:0] unit_neuron_idx, unit_neuron_idx_nxt;
  int layer_neuron_idx;
        
  always_ff @(posedge clk) begin
	neuron_st <= neuron_st_nxt;
    addr <= addr_nxt;
    accum_val <= accum_val_nxt;
    unit_neuron_idx <= unit_neuron_idx_nxt;
  end
  
  always_comb begin : event_control
    if(rst) begin
      neuron_st_nxt = 0;    
      addr_nxt = 0;
      accum_val_nxt = 0;
      unit_neuron_idx_nxt = 0;
      pot_val_nxt = 0;
    end else begin
      neuron_st_nxt = neuron_st;
      addr_nxt = addr;
      accum_val_nxt = accum_val;
      unit_neuron_idx_nxt = 0;
      pot_val_nxt = pot_val;
      
      case (neuron_st)
        0: begin
          if(layer_acc) neuron_st_nxt = 1;
          else if(layer_act) neuron_st_nxt = 3;
        end
        1: begin // ACCUM: addr
          // 
          if(unit_neuron_idx < NEURON_UNIT_SIZE) begin // serially go through each neuron within the neural unit
          	// check if this mult here translates to area growth, e.g., in FPGA or is it handled in synthesis time by generating the datapath
            // consider 5 units in layer and 1:4 case, UNIT_IDX 2, iter 1. so neuron idx is 2*4+1=9, 
            // now to addr into pre-synapt neuron, we need that shift array
            // case 1: EC_SIZE = 4, UNIT_IDX = 2, 
            layer_neuron_idx =  UNIT_IDX*EC_SIZE + unit_neuron_idx; // layer neuron id
          	addr_nxt = 
            unit_neuron_idx_nxt = unit_neuron_idx + 1;
          	neuron_st_nxt = 2;
          end else // done iterating unit neurons, now get the new shifted spk set for this unit
            neuron_st_nxt = 0;
        // reading shifted spk addr will be handled in top-level connection phase
        // for now we assume that an input signal gives us that
        end
        2: begin
          accum_val_nxt = accum_val + wdata; // accumulate with the corresponding weight data
          neuron_st_nxt = 1;
        end
        3: begin
          if(unit_neuron_idx < NEURON_UNIT_SIZE) begin // serially go through each neuron within the neural unit
          	layer_neuron_idx = base_spk_addr + UNIT_IDX*EC_SIZE + unit_neuron_idx; // layer neuron id
          	pot_val_nxt = pot_val*BETA + accum_val + bias;
            unit_neuron_idx_nxt = unit_neuron_idx + 1;
          	neuron_st_nxt = 4;
          end else // done iterating unit neurons, done activation
            neuron_st_nxt = 0;
        end
        4: begin
          if(pot_val > POSITIVE_THRESHOLD) begin
            // layer_out = 1;
            pot_val_nxt = pot_val - POSITIVE_THRESHOLD;
          end
          neuron_st_nxt = 1;
        end
      endcase
    end // rst
        
  end // always
  
endmodule

module tb;
  
  reg rst;
  reg clk;
  reg layer_acc, layer_act;
  reg [9:0] addr;
  reg [31:0] data_in;
  reg [4:0] base_spk_addr;
  
  neural n(clk, rst, layer_acc, layer_act, base_spk_addr, data_in, addr);
    
  initial begin   
    clk = 0;
    forever #5 clk = ~clk;
  end
  
  initial begin
    rst = 1;
    
    #15;
    
    rst = 0;
    
    layer_acc = 1;
    data_in = 12;    
    
    #10;
    
    #10;
  end
  
endmodule
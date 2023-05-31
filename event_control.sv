module event_control(input clk, rst, post_synp_avail, // tied to post-syn layer, tells if post-layer is ready for new spikes
                     input [31:0] pre_synpt_spk,    // tied to pre-syn layer event control
                     input [31:0] post_synpt_spk,   // tied to neurons, e.g., 32 this case
                     output reg [31:0] post_synp_buffer, //tied to post-syn layer EC
                     output reg en_accum, en_activ    // tied to neurons
                     );
  
  parameter EC_SIZE = 32;
  parameter NEURAL_SIZE = 2;
  
  reg [31:0] penc_in, penc_in_nxt;
  reg [4:0] spk_addr;
  reg [4:0] spk_cnt, spk_cnt_nxt;
  reg done;
  reg en_accum_nxt;
  reg en_activ_nxt;
  
  reg [2:0] event_st, event_st_nxt;
  reg [4:0] shift_cnt, shift_cnt_nxt;
  reg [4:0] shift_regs [31:0];
  reg [4:0] shift_regs_nxt [31:0];
  reg [4:0] neuron_spk_addr [31:0];
  reg [4:0] neuron_spk_addr_nxt [31:0];
  reg [31:0] ec_buffer, ec_buffer_nxt;
  reg [31:0] post_synp_buffer_nxt;
  reg [5:0] wait_cnt, wait_cnt_nxt;
  
  int i, j, k;
  int shifted_spk_addr;
    
  penc p0 (penc_in, spk_addr, done);
      
  always_ff @(posedge clk) begin
    penc_in <= 
    penc_in_nxt;
    event_st <= event_st_nxt;
    spk_cnt <= spk_cnt_nxt;
    shift_cnt <= shift_cnt_nxt;
    en_accum <= en_accum_nxt;
    en_activ <= en_activ_nxt;
    wait_cnt <= wait_cnt_nxt;
    post_synp_buffer <= post_synp_buffer_nxt;
    for(k=0; k<EC_SIZE; k++) begin
      shift_regs[k] <= shift_regs_nxt[k];
      neuron_spk_addr[k] <= neuron_spk_addr_nxt[k];
    end
  end
  
  always_comb begin : event_control
    if(rst) begin
      event_st_nxt = 0;
      penc_in_nxt = 0;
      spk_cnt_nxt = 0;
      shift_cnt_nxt = 0;
      en_accum_nxt = 0;
      en_activ_nxt = 0;
      post_synp_buffer_nxt = 0;
      wait_cnt_nxt = 0;
      for(j=0; j<EC_SIZE; j++) begin
        shift_regs_nxt[j] = 0;
        neuron_spk_addr_nxt[j] = 0;
      end      
    end else begin
      event_st_nxt = event_st;
      penc_in_nxt = penc_in;
      spk_cnt_nxt = spk_cnt;  
      shift_cnt_nxt = shift_cnt;
      en_accum_nxt = en_accum;
      en_activ_nxt = en_activ;
      post_synp_buffer_nxt = post_synp_buffer;
      wait_cnt_nxt = wait_cnt_nxt;
      for(j=0; j<EC_SIZE; j++) begin
        shift_regs_nxt[j] = shift_regs[j];
        neuron_spk_addr_nxt[j] = neuron_spk_addr[j];
      end
      
      case (event_st)
        0: begin
          penc_in_nxt = pre_synpt_spk;
          event_st_nxt = 2;
        end
        1: begin // PENC_1
          penc_in_nxt[spk_addr] = 0;
          event_st_nxt = 2;
        end
        2: begin // PENC_2
          if(done) event_st_nxt = 3;
          else begin
            shift_regs_nxt[spk_cnt] = spk_addr;
            spk_cnt_nxt = spk_cnt + 1;
            event_st_nxt = 1;
          end
        end
        3: begin // ACCUM_1: address gen for the EC neurons
          shift_cnt_nxt = shift_cnt + 1; 
          event_st_nxt = 4;
          en_accum_nxt = 1;
          for(i=0; i<EC_SIZE; i++) begin
            shifted_spk_addr = i + shift_cnt;
            if(shifted_spk_addr > spk_cnt) shifted_spk_addr = shifted_spk_addr - spk_cnt;
            neuron_spk_addr_nxt[i] = shift_regs[shifted_spk_addr];
            $display("i=%d, shifted_neuron_no=%d", i, shifted_spk_addr);
          end
        end
        4: begin // ACCUM_2: wait for neuron done: fixed number of cycles for each unit, move on with 
          if(wait_cnt < NEURAL_SIZE) wait_cnt_nxt = wait_cnt + 1;
          else begin
            wait_cnt_nxt = 0;
            if(shift_cnt > spk_cnt) begin
            	shift_cnt_nxt = 0;
              	event_st_nxt = 5;
              	en_accum_nxt = 0;
            end else 
                event_st_nxt = 3;
          end
          
          //for(i=0; i<EC_SIZE; i++) begin
          //  $display("i=%d, shift_regs=%d, neuron_spk_addr=%d", i, shift_regs[i], neuron_spk_addr[i]);
          //end
        end
        5: begin
          if(post_synp_avail) begin
            post_synp_buffer_nxt = post_synpt_spk;
            en_activ_nxt = 1;
            event_st = 0;
            //time_step = time_step + 1;
            // buffer_aval_nxt = 0; in the next layer's ec
            // neuron_out_nxt = 0; in else statement of the threshold comparison
          end
        end
      endcase
    end // rst
        
    //$display("spk_addr = %d, event_st = %d, spk_cnt = %d", spk_addr, event_st, spk_cnt);
  end // always
  
endmodule

// parametrize width
module penc (input [31:0] sparse_in, output reg [4:0] spk_addr, output reg done);
    always_comb begin
        done = 0;
        if(sparse_in[0]) spk_addr = 0;
        else if(sparse_in[1]) spk_addr = 1;
        else if(sparse_in[2]) spk_addr = 2;
        else if(sparse_in[3]) spk_addr = 3;
        else if(sparse_in[4]) spk_addr = 4;
        else if(sparse_in[5]) spk_addr = 5;
        else if(sparse_in[6]) spk_addr = 6;
        else if(sparse_in[7]) spk_addr = 7;
        else if(sparse_in[8]) spk_addr = 8;
        else if(sparse_in[9]) spk_addr = 9;
        else if(sparse_in[10]) spk_addr = 10;
        else if(sparse_in[11]) spk_addr = 11;
        else if(sparse_in[12]) spk_addr = 12;
        else if(sparse_in[13]) spk_addr = 13;
        else if(sparse_in[14]) spk_addr = 14;
        else if(sparse_in[15]) spk_addr = 15;
        else if(sparse_in[16]) spk_addr = 16;
        else if(sparse_in[17]) spk_addr = 17;
        else if(sparse_in[18]) spk_addr = 18;
        else if(sparse_in[19]) spk_addr = 19;
        else if(sparse_in[20]) spk_addr = 20;
        else if(sparse_in[21]) spk_addr = 21;
        else if(sparse_in[22]) spk_addr = 22;
        else if(sparse_in[23]) spk_addr = 23;
        else if(sparse_in[24]) spk_addr = 24;
        else if(sparse_in[25]) spk_addr = 25;
        else if(sparse_in[26]) spk_addr = 26;
        else if(sparse_in[27]) spk_addr = 27;
        else if(sparse_in[28]) spk_addr = 28;
        else if(sparse_in[29]) spk_addr = 29;
        else if(sparse_in[30]) spk_addr = 30;
        else if(sparse_in[31]) spk_addr = 31;
        else done = 1;
    end

 endmodule

 module tb;
  
  reg rst;
  reg clk;
  reg [31:0] pre_synpt_spk, post_synpt_spk;
  reg post_synp_avail;
  wire [31:0] post_synp_buffer;
  wire en_accum, en_activ;
  
   event_control ec(clk, rst, post_synp_avail, pre_synpt_spk, post_synpt_spk, post_synp_buffer, en_accum, en_activ);
    
  initial begin   
    clk = 0;
    forever #5 clk = ~clk;
  end
  
  initial begin
    rst = 1;
    
    #15;
    
    rst = 0;
    
    pre_synpt_spk = 32'b10010000001110000100000100010010;
    
    #10;
    
    #10;
  end
  
endmodule
  
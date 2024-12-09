`include "path to macros file"

module top_wrapper #(
    parameter CONV_1_1_INPUT_CHANNELS = 3,
    parameter CONV_1_1_OUTPUT_CHANNELS = 64,
    parameter CONV_1_1_KERNEL_SIZE = 3,
    parameter CONV_1_1_INPUT_FRAME_WIDTH = 32,
    parameter CONV_1_1_INPUT_FRAME_SIZE = CONV_1_1_INPUT_FRAME_WIDTH*CONV_1_1_INPUT_FRAME_WIDTH,
    parameter model_dir = `model_directory
) (
    input clk, rst,
    input input_avail,
    output logic conv_1_1_avail
);

parameter TIME_STEPS = `time_steps;

parameter USER_SET_CONV_1_2_SIZE = 112;
parameter USER_SET_CONV_2_1_SIZE = 128;
parameter USER_SET_CONV_2_2_SIZE = 216;
parameter USER_SET_CONV_3_1_SIZE = 480;
parameter USER_SET_CONV_3_2_SIZE = 504;
parameter USER_SET_CONV_3_3_SIZE = 560;
parameter USER_SET_FC_1_SIZE = 1064;
parameter USER_SET_FC_2_SIZE = 1000;

parameter USER_SET_CONV_1_1_EC_SIZE = `conv_1_1_ec_size;
parameter USER_SET_CONV_1_2_EC_SIZE = `conv_1_2_ec_size;
parameter USER_SET_CONV_2_1_EC_SIZE = `conv_2_1_ec_size;
parameter USER_SET_CONV_2_2_EC_SIZE = `conv_2_2_ec_size;
parameter USER_SET_CONV_3_1_EC_SIZE = `conv_3_1_ec_size;
parameter USER_SET_CONV_3_2_EC_SIZE = `conv_3_2_ec_size;
parameter USER_SET_CONV_3_3_EC_SIZE = `conv_3_3_ec_size;
parameter USER_SET_FC_1_EC_SIZE = `fc1_ec_size;
parameter USER_SET_FC_2_EC_SIZE = `fc2_ec_size;


/***************************************** CONV_1_1 params ***********************************************/  
//  localparam CONV_1_1_INPUT_CHANNELS = INPUT_OUTPUT_CHANNELS;
//  localparam CONV_1_1_OUTPUT_CHANNELS = USER_SET_CONV_1_1_SIZE; // Change this as per your design
//  localparam CONV_1_1_KERNEL_SIZE = 3; // Change this as per your design
//  localparam CONV_1_1_INPUT_FRAME_WIDTH = INPUT_OUTPUT_FRAME_WIDTH/2; // maxpooling 2x2
//  localparam CONV_1_1_INPUT_FRAME_SIZE = CONV_1_1_INPUT_FRAME_WIDTH*CONV_1_1_INPUT_FRAME_WIDTH;
  localparam CONV_1_1_OUTPUT_FRAME_WIDTH = CONV_1_1_INPUT_FRAME_WIDTH;
  localparam CONV_1_1_OUTPUT_FRAME_SIZE = CONV_1_1_OUTPUT_FRAME_WIDTH * CONV_1_1_OUTPUT_FRAME_WIDTH;
  // localparam CONV_1_1_OUTPUT_FRAME_SIZE_MP = CONV_1_1_OUTPUT_FRAME_SIZE/4;
  localparam CONV_1_1_EC_SIZE = USER_SET_CONV_1_1_EC_SIZE; // Change this as per your design
  localparam CONV_1_1_SPARSE_SIZE = CONV_1_1_INPUT_FRAME_SIZE>>1;
  localparam CONV_1_1_PENC_SIZE = CONV_1_1_INPUT_FRAME_SIZE>>2;
  localparam CONV_1_1_POT_BRAM_ADDR_WIDTH = $clog2(CONV_1_1_OUTPUT_FRAME_SIZE); 
  localparam CONV_1_1_SPK_BRAM_DEPTH = TIME_STEPS * CONV_1_1_OUTPUT_CHANNELS;
  localparam INPUT_SPK_BRAM_DEPTH = TIME_STEPS * CONV_1_1_INPUT_CHANNELS;
/***************************************** CONV_1_1 params ***********************************************/  

/***************************************** INPUT layer ***********************************************/    
 (* DONT_TOUCH = "yes" *)
  bram_inp_spk #(
    .RAM_DEPTH(INPUT_SPK_BRAM_DEPTH), 
    .RAM_WIDTH(CONV_1_1_INPUT_FRAME_SIZE), 
    .FILENAME($sformatf("%s/spk_in.txt", model_dir)))
 input_spk_ram (
    .clk(clk), .rst(rst),
    .rdat(input_spk_bram_rdat),
    .raddr(input_spk_bram_raddr),
    .ren(input_spk_bram_ren),
    .wrdat(0), .wraddr(0), .wren(0)
 );
/***************************************** INPUT layer ***********************************************/  

/***************************************** CONV_1_1 layer ***********************************************/  
  logic [$clog2(INPUT_SPK_BRAM_DEPTH)-1:0] input_spk_bram_raddr;
  logic [CONV_1_1_INPUT_FRAME_SIZE-1:0] input_spk_bram_rdat;
  logic input_spk_bram_ren;
  logic [CONV_1_1_OUTPUT_FRAME_SIZE-1:0] CONV_1_1_spk_bram_wrdat, CONV_1_1_spk_bram_wrdat_nxt;
  logic [$clog2(CONV_1_1_SPK_BRAM_DEPTH)-1:0] CONV_1_1_spk_bram_wraddr, CONV_1_1_spk_bram_wraddr_nxt;
  logic CONV_1_1_spk_bram_wren, CONV_1_1_spk_bram_wren_nxt;
  logic [CONV_1_1_OUTPUT_FRAME_SIZE-1:0] CONV_1_1_spk_bram_rdat;
  logic [$clog2(CONV_1_1_SPK_BRAM_DEPTH)-1:0] CONV_1_1_spk_bram_raddr;
  logic CONV_1_1_spk_bram_ren;
  logic [$clog2(CONV_1_1_INPUT_FRAME_WIDTH)-1:0] CONV_1_1_affect_neur_addr_row[CONV_1_1_EC_SIZE-1:0], CONV_1_1_affect_neur_addr_col[CONV_1_1_EC_SIZE-1:0];
  logic [$clog2(CONV_1_1_INPUT_CHANNELS)+1:0] CONV_1_1_channel;
  logic [$clog2(TIME_STEPS):0] CONV_1_1_time_step_out_spikes, CONV_1_1_time_step_in_spikes;
  logic CONV_1_1_neur_addr_invalid;
  assign input_spk_bram_raddr = CONV_1_1_channel +  CONV_1_1_time_step_in_spikes*CONV_1_1_INPUT_CHANNELS;
  
  int CONV_1_1_input_spks = 0;
  logic [$clog2(8*CONV_1_1_SPARSE_SIZE)-1:0] CONV_1_1_cumm_spks;

  logic CONV_1_1_en_accum, CONV_1_1_en_activ;
  logic CONV_1_1_ram_clk;

  `ifdef SIM
  shortreal CONV_1_1_pot_bram_rdat [CONV_1_1_EC_SIZE-1:0];
  shortreal CONV_1_1_pot_bram_wrdat [CONV_1_1_EC_SIZE-1:0];
  `else
  logic [31:0] CONV_1_1_pot_bram_rdat [CONV_1_1_EC_SIZE-1:0];
  logic [31:0] CONV_1_1_pot_bram_wrdat [CONV_1_1_EC_SIZE-1:0];
  `endif

  logic [CONV_1_1_POT_BRAM_ADDR_WIDTH-1:0] CONV_1_1_pot_bram_raddr [CONV_1_1_EC_SIZE-1:0], CONV_1_1_pot_bram_wraddr [CONV_1_1_EC_SIZE-1:0];
  logic CONV_1_1_pot_bram_ren [CONV_1_1_EC_SIZE-1:0], CONV_1_1_pot_bram_wren [CONV_1_1_EC_SIZE-1:0];
  logic [CONV_1_1_OUTPUT_FRAME_SIZE-1:0] CONV_1_1_post_syn_spk [CONV_1_1_EC_SIZE-1:0]; 
  // logic [CONV_1_1_OUTPUT_FRAME_SIZE-1:0] CONV_1_1_post_syn_spk_ored [CONV_1_1_EC_SIZE-1:0]; 
  logic [$clog2(CONV_1_1_KERNEL_SIZE)+1:0] CONV_1_1_filter_phase;
  logic CONV_1_1_new_spk_train, CONV_1_1_last_time_step, CONV_1_1_ic_done;
  logic [$clog2(CONV_1_1_OUTPUT_CHANNELS)+1:0] CONV_1_1_oc_phase, CONV_1_1_oc_phase_shifted;

    (* DONT_TOUCH = "yes" *)
    conv_ec 
    #(.TIME_STEPS(TIME_STEPS),
    .INPUT_CHANNELS(CONV_1_1_INPUT_CHANNELS),
    .OUTPUT_CHANNELS(CONV_1_1_OUTPUT_CHANNELS),
    .KERNEL_SIZE(CONV_1_1_KERNEL_SIZE),
    .INPUT_FRAME_WIDTH(CONV_1_1_INPUT_FRAME_WIDTH),
    .INPUT_FRAME_SIZE(CONV_1_1_INPUT_FRAME_SIZE),
    .OUTPUT_FRAME_WIDTH(CONV_1_1_OUTPUT_FRAME_WIDTH),
    .OUTPUT_FRAME_SIZE(CONV_1_1_OUTPUT_FRAME_SIZE),
    .EC_SIZE(CONV_1_1_EC_SIZE),
    .SPARSE_SIZE(CONV_1_1_SPARSE_SIZE), 
    .PENC_SIZE(CONV_1_1_PENC_SIZE))
    CONV_1_1_ec (
    .clk(clk), .rst(rst),
    .pre_syn_RAM_loaded(input_avail), // Connect to output of CONV_1_2 layer
    .post_syn_RAM_loaded(CONV_1_1_spk_RAM_loaded),
    .new_spk_train_ready(CONV_1_1_new_spk_train),
    .last_time_step(CONV_1_1_last_time_step), // Add this line
    .ic_done(CONV_1_1_ic_done), // Add this line
    .spk_in_train(input_spk_bram_rdat),
    .spk_in_ram_en(input_spk_bram_ren),
    .ic(CONV_1_1_channel),
    .oc_phase(CONV_1_1_oc_phase),
    .oc_phase_shift(CONV_1_1_oc_phase_shifted),
    .time_step_out_spikes(CONV_1_1_time_step_out_spikes),
    .time_step_in_spikes(CONV_1_1_time_step_in_spikes),
    .affect_neur_addr_row(CONV_1_1_affect_neur_addr_row),
    .affect_neur_addr_col(CONV_1_1_affect_neur_addr_col),
    .neur_addr_invalid(CONV_1_1_neur_addr_invalid),
    .filter_phase(CONV_1_1_filter_phase),
    .en_accum(CONV_1_1_en_accum),
    .en_activ(CONV_1_1_en_activ),
    .cumm_spks(CONV_1_1_cumm_spks),
    .total_layer_spks_in(CONV_1_1_input_spks),
    .total_layer_spks_out(CONV_1_1_input_spks)
    );

 generate
    for (genvar i=0; i<CONV_1_1_EC_SIZE; i=i+1) begin : gen_1
    conv_nc #(
        .NEURON_OFFSET(i),
        .IN_CHANNELS(CONV_1_1_INPUT_CHANNELS),
        .OUT_CHANNELS(CONV_1_1_OUTPUT_CHANNELS),
        .EC_SIZE(CONV_1_1_EC_SIZE),
        .KERNEL_SIZE(CONV_1_1_KERNEL_SIZE),
        .INPUT_FRAME_WIDTH(CONV_1_1_INPUT_FRAME_WIDTH),
        .OUTPUT_FRAME_WIDTH(CONV_1_1_OUTPUT_FRAME_WIDTH),
        .BRAM_ADDR_WIDTH(CONV_1_1_POT_BRAM_ADDR_WIDTH),
        .w_sfactor(`w_sfactor_2_1),
        .b_sfactor(`b_sfactor_2_1),
        .w_zpt(`w_zpt_2_1),
        .b_zpt(`b_zpt_2_1),
        .WEIGHT_FILENAME($sformatf("%s/weights/conv1_1_nc%0d.txt", model_dir, i))
    ) CONV_1_1_nc_i (
        .clk(clk), .rst(rst),
        .en_accum(CONV_1_1_en_accum),
        .en_activ(CONV_1_1_en_activ),
        .ic(CONV_1_1_channel),
        .oc_phase(CONV_1_1_oc_phase),
        .filter_phase(CONV_1_1_filter_phase),
        .affect_neur_addr_row(CONV_1_1_affect_neur_addr_row[i]),
        .affect_neur_addr_col(CONV_1_1_affect_neur_addr_col[i]),
        .neur_addr_invalid(CONV_1_1_neur_addr_invalid),
        .last_time_step(CONV_1_1_last_time_step), // Add this line
        .ic_done(CONV_1_1_ic_done), // Add this line
        .post_syn_spk(CONV_1_1_post_syn_spk[i]),
        .bram_rdat(CONV_1_1_pot_bram_rdat[i]),
        .bram_raddr(CONV_1_1_pot_bram_raddr[i]),
        .bram_ren(CONV_1_1_pot_bram_ren[i]),
        .bram_wrdat(CONV_1_1_pot_bram_wrdat[i]),
        .bram_wraddr(CONV_1_1_pot_bram_wraddr[i]),
        .bram_wren(CONV_1_1_pot_bram_wren[i])
    );

    (* DONT_TOUCH = "yes" *)
    bram_pot #(
        .RAM_DEPTH(CONV_1_1_OUTPUT_FRAME_SIZE))
    CONV_1_1_pot_ram (
        .clk(clk), .rst(rst),
        .rdat(CONV_1_1_pot_bram_rdat[i]),
        .raddr(CONV_1_1_pot_bram_raddr[i]),
        .ren(CONV_1_1_pot_bram_ren[i]),
        .wrdat(CONV_1_1_pot_bram_wrdat[i]),
        .wraddr(CONV_1_1_pot_bram_wraddr[i]),
        .wren(CONV_1_1_pot_bram_wren[i])
    );
    end
 endgenerate

  (* DONT_TOUCH = "yes" *)
  bram_spk #(
    .RAM_DEPTH(CONV_1_1_SPK_BRAM_DEPTH), 
    .RAM_WIDTH(CONV_1_1_OUTPUT_FRAME_SIZE))
 CONV_1_1_spk_ram (
    .clk(clk), .rst(rst),
    .rdat(CONV_1_1_spk_bram_rdat),
    .raddr(CONV_1_1_spk_bram_raddr),
    .ren(CONV_1_1_spk_bram_ren),
    .wrdat(CONV_1_1_spk_bram_wrdat), 
    .wraddr(CONV_1_1_spk_bram_wraddr), 
    .wren(CONV_1_1_spk_bram_wren)
 );



  logic [1:0] CONV_1_1_state, CONV_1_1_state_nxt;
  logic [CONV_1_1_EC_SIZE-1:0] CONV_1_1_nc_iter, CONV_1_1_nc_iter_nxt;

  always_ff @(posedge clk) begin
    CONV_1_1_state <= CONV_1_1_state_nxt;
    CONV_1_1_nc_iter <= CONV_1_1_nc_iter_nxt;
    CONV_1_1_spk_bram_wraddr <= CONV_1_1_spk_bram_wraddr_nxt;
    CONV_1_1_spk_bram_wrdat <= CONV_1_1_spk_bram_wrdat_nxt;
    CONV_1_1_spk_bram_wren <= CONV_1_1_spk_bram_wren_nxt;
  end
  
  always_comb begin
    if(rst) begin
        CONV_1_1_state_nxt = 0;
        CONV_1_1_nc_iter_nxt = 0;
        CONV_1_1_spk_bram_wraddr_nxt = 0;
        CONV_1_1_spk_bram_wrdat_nxt = 0;
        CONV_1_1_spk_bram_wren_nxt = 0;
    end else begin 
        CONV_1_1_state_nxt = CONV_1_1_state;
        CONV_1_1_nc_iter_nxt = CONV_1_1_nc_iter;
        CONV_1_1_spk_bram_wraddr_nxt = CONV_1_1_spk_bram_wraddr;
        CONV_1_1_spk_bram_wrdat_nxt = CONV_1_1_spk_bram_wrdat;
        CONV_1_1_spk_bram_wren_nxt = CONV_1_1_spk_bram_wren;
        case(CONV_1_1_state)
            0: begin
                if(CONV_1_1_new_spk_train) CONV_1_1_state_nxt = 1;
            end
            1:begin
                CONV_1_1_spk_bram_wraddr_nxt = (CONV_1_1_time_step_out_spikes)*CONV_1_1_OUTPUT_CHANNELS + CONV_1_1_oc_phase_shifted*CONV_1_1_EC_SIZE + CONV_1_1_nc_iter;
                CONV_1_1_spk_bram_wrdat_nxt = CONV_1_1_post_syn_spk[CONV_1_1_nc_iter];
                
                CONV_1_1_spk_bram_wren_nxt = 1;
                CONV_1_1_nc_iter_nxt = CONV_1_1_nc_iter + 1;
                CONV_1_1_state_nxt = 2;
            end
            2: begin
                CONV_1_1_state_nxt = 3;
            end
            3: begin
                CONV_1_1_spk_bram_wren_nxt = 0;
                if(CONV_1_1_nc_iter == CONV_1_1_EC_SIZE) begin
                    CONV_1_1_state_nxt = 0;
                    CONV_1_1_nc_iter_nxt = 0;
                end else CONV_1_1_state_nxt = 1;
            end
        endcase
    end  
  end
/*************************************** CONV_1_1 Spike R/W ********************************************/  

  

  localparam CONV_1_2_INPUT_CHANNELS = CONV_1_1_OUTPUT_CHANNELS;
  localparam CONV_1_2_OUTPUT_CHANNELS = USER_SET_CONV_1_2_SIZE; // Change this as per your design
  localparam CONV_1_2_KERNEL_SIZE = 3; // Change this as per your design
  localparam CONV_1_2_INPUT_FRAME_WIDTH = CONV_1_1_OUTPUT_FRAME_WIDTH; 
  localparam CONV_1_2_INPUT_FRAME_SIZE = CONV_1_2_INPUT_FRAME_WIDTH*CONV_1_2_INPUT_FRAME_WIDTH;
  localparam CONV_1_2_OUTPUT_FRAME_WIDTH = CONV_1_2_INPUT_FRAME_WIDTH;
  localparam CONV_1_2_OUTPUT_FRAME_SIZE = CONV_1_2_OUTPUT_FRAME_WIDTH * CONV_1_2_OUTPUT_FRAME_WIDTH; // ?
  localparam CONV_1_2_OUTPUT_FRAME_SIZE_MP = CONV_1_2_OUTPUT_FRAME_SIZE/4;
  localparam CONV_1_2_EC_SIZE = USER_SET_CONV_1_2_EC_SIZE; // Change this as per your design
  localparam CONV_1_2_SPARSE_SIZE = CONV_1_2_INPUT_FRAME_SIZE>>1;
  localparam CONV_1_2_PENC_SIZE = CONV_1_2_INPUT_FRAME_SIZE>>2;
  localparam CONV_1_2_POT_BRAM_ADDR_WIDTH = $clog2(CONV_1_2_OUTPUT_FRAME_SIZE); 
  localparam CONV_1_2_SPK_BRAM_DEPTH = TIME_STEPS * CONV_1_2_OUTPUT_CHANNELS;


  logic [CONV_1_2_OUTPUT_FRAME_SIZE_MP-1:0] CONV_1_2_spk_bram_wrdat, CONV_1_2_spk_bram_wrdat_nxt;
  logic [$clog2(CONV_1_2_SPK_BRAM_DEPTH)-1:0] CONV_1_2_spk_bram_wraddr, CONV_1_2_spk_bram_wraddr_nxt;
  logic CONV_1_2_spk_bram_wren, CONV_1_2_spk_bram_wren_nxt;
  logic [CONV_1_2_OUTPUT_FRAME_SIZE_MP-1:0] CONV_1_2_spk_bram_rdat;
  logic [$clog2(CONV_1_2_SPK_BRAM_DEPTH)-1:0] CONV_1_2_spk_bram_raddr;
  logic CONV_1_2_spk_bram_ren;
  logic [$clog2(CONV_1_2_INPUT_FRAME_WIDTH)-1:0] CONV_1_2_affect_neur_addr_row[CONV_1_2_EC_SIZE-1:0], CONV_1_2_affect_neur_addr_col[CONV_1_2_EC_SIZE-1:0];
  logic [$clog2(CONV_1_2_INPUT_CHANNELS)+1:0] CONV_1_2_channel;
  logic [$clog2(TIME_STEPS):0] CONV_1_2_time_step_out_spikes, CONV_1_2_time_step_in_spikes;
  logic CONV_1_2_neur_addr_invalid;
  assign CONV_1_1_spk_bram_raddr = CONV_1_2_channel + CONV_1_2_time_step_in_spikes*CONV_1_1_OUTPUT_CHANNELS;

  logic CONV_1_2_en_accum, CONV_1_2_en_activ;
  logic CONV_1_2_ram_clk;

  int CONV_1_2_input_spks = 0; // layer spk counter
  logic [$clog2(8*CONV_1_2_SPARSE_SIZE)-1:0] CONV_1_2_cumm_spks;

  shortreal CONV_1_2_pot_bram_rdat [CONV_1_2_EC_SIZE-1:0];
  shortreal CONV_1_2_pot_bram_wrdat [CONV_1_2_EC_SIZE-1:0];

  logic [CONV_1_2_POT_BRAM_ADDR_WIDTH-1:0] CONV_1_2_pot_bram_raddr [CONV_1_2_EC_SIZE-1:0], CONV_1_2_pot_bram_wraddr [CONV_1_2_EC_SIZE-1:0];
  logic CONV_1_2_pot_bram_ren [CONV_1_2_EC_SIZE-1:0], CONV_1_2_pot_bram_wren [CONV_1_2_EC_SIZE-1:0];
  logic [CONV_1_2_OUTPUT_FRAME_SIZE-1:0] CONV_1_2_post_syn_spk [CONV_1_2_EC_SIZE-1:0]; 
  logic [CONV_1_2_OUTPUT_FRAME_SIZE/4-1:0] CONV_1_2_post_syn_spk_ored [CONV_1_2_EC_SIZE-1:0]; 
  logic [$clog2(CONV_1_2_KERNEL_SIZE)+1:0] CONV_1_2_filter_phase;
  logic CONV_1_2_new_spk_train, CONV_1_2_last_time_step, CONV_1_2_ic_done;
  logic [$clog2(CONV_1_2_OUTPUT_CHANNELS)+1:0] CONV_1_2_oc_phase, CONV_1_2_oc_phase_shifted;

 
    (* DONT_TOUCH = "yes" *)
    conv_ec 
    #(.TIME_STEPS(TIME_STEPS),
    .INPUT_CHANNELS(CONV_1_2_INPUT_CHANNELS),
    .OUTPUT_CHANNELS(CONV_1_2_OUTPUT_CHANNELS),
    .KERNEL_SIZE(CONV_1_2_KERNEL_SIZE),
    .INPUT_FRAME_WIDTH(CONV_1_2_INPUT_FRAME_WIDTH),
    .INPUT_FRAME_SIZE(CONV_1_2_INPUT_FRAME_SIZE),
    .OUTPUT_FRAME_WIDTH(CONV_1_2_OUTPUT_FRAME_WIDTH),
    .OUTPUT_FRAME_SIZE(CONV_1_2_OUTPUT_FRAME_SIZE),
    .EC_SIZE(CONV_1_2_EC_SIZE),
    .SPARSE_SIZE(CONV_1_2_SPARSE_SIZE), 
    .PENC_SIZE(CONV_1_2_PENC_SIZE))
    CONV_1_2_ec (
    .clk(clk), .rst(rst),
    .pre_syn_RAM_loaded(CONV_1_1_spk_RAM_loaded), // Connect to output of CONV_1_1 layer
    .post_syn_RAM_loaded(CONV_1_2_spk_RAM_loaded),
    .new_spk_train_ready(CONV_1_2_new_spk_train),
    .last_time_step(CONV_1_2_last_time_step), // Add this line
    .ic_done(CONV_1_2_ic_done), // Add this line
    .spk_in_train(CONV_1_1_spk_bram_rdat),
    .spk_in_ram_en(CONV_1_1_spk_bram_ren),
    .ic(CONV_1_2_channel),
    .oc_phase(CONV_1_2_oc_phase),
    .oc_phase_shift(CONV_1_2_oc_phase_shifted),
    .time_step_out_spikes(CONV_1_2_time_step_out_spikes),
    .time_step_in_spikes(CONV_1_2_time_step_in_spikes),
    .affect_neur_addr_row(CONV_1_2_affect_neur_addr_row),
    .affect_neur_addr_col(CONV_1_2_affect_neur_addr_col),
    .neur_addr_invalid(CONV_1_2_neur_addr_invalid),
    .filter_phase(CONV_1_2_filter_phase),
    .en_accum(CONV_1_2_en_accum),
    .en_activ(CONV_1_2_en_activ),
    .cumm_spks(CONV_1_2_cumm_spks),
    .total_layer_spks_in(CONV_1_2_input_spks),
    .total_layer_spks_out(CONV_1_2_input_spks)
    );

 generate
    for (genvar i=0; i<CONV_1_2_EC_SIZE; i=i+1) begin : gen_2
    conv_nc #(
        .NEURON_OFFSET(i),
        .IN_CHANNELS(CONV_1_2_INPUT_CHANNELS),
        .OUT_CHANNELS(CONV_1_2_OUTPUT_CHANNELS),
        .EC_SIZE(CONV_1_2_EC_SIZE),
        .KERNEL_SIZE(CONV_1_2_KERNEL_SIZE),
        .INPUT_FRAME_WIDTH(CONV_1_2_INPUT_FRAME_WIDTH),
        .OUTPUT_FRAME_WIDTH(CONV_1_2_OUTPUT_FRAME_WIDTH),
        .BRAM_ADDR_WIDTH(CONV_1_2_POT_BRAM_ADDR_WIDTH),
        .w_sfactor(`w_sfactor_1_2),
        .b_sfactor(`b_sfactor_1_2),
        .w_zpt(`w_zpt_1_2),
        .b_zpt(`b_zpt_1_2),
        .WEIGHT_FILENAME($sformatf("%s/weights/conv1_2_nc%0d.txt", model_dir, i))
    ) CONV_1_2_nc_i (
        .clk(clk), .rst(rst),
        .en_accum(CONV_1_2_en_accum),
        .en_activ(CONV_1_2_en_activ),
        .ic(CONV_1_2_channel),
        .oc_phase(CONV_1_2_oc_phase),
        .filter_phase(CONV_1_2_filter_phase),
        .affect_neur_addr_row(CONV_1_2_affect_neur_addr_row[i]),
        .affect_neur_addr_col(CONV_1_2_affect_neur_addr_col[i]),
        .neur_addr_invalid(CONV_1_2_neur_addr_invalid),
        .last_time_step(CONV_1_2_last_time_step), // Add this line
        .ic_done(CONV_1_2_ic_done), // Add this line
        .post_syn_spk(CONV_1_2_post_syn_spk[i]),
        .bram_rdat(CONV_1_2_pot_bram_rdat[i]),
        .bram_raddr(CONV_1_2_pot_bram_raddr[i]),
        .bram_ren(CONV_1_2_pot_bram_ren[i]),
        .bram_wrdat(CONV_1_2_pot_bram_wrdat[i]),
        .bram_wraddr(CONV_1_2_pot_bram_wraddr[i]),
        .bram_wren(CONV_1_2_pot_bram_wren[i])
    );

    (* DONT_TOUCH = "yes" *)
    bram_pot #(
        .RAM_DEPTH(CONV_1_2_OUTPUT_FRAME_SIZE))
    CONV_1_2_pot_ram (
        .clk(clk), .rst(rst),
        .rdat(CONV_1_2_pot_bram_rdat[i]),
        .raddr(CONV_1_2_pot_bram_raddr[i]),
        .ren(CONV_1_2_pot_bram_ren[i]),
        .wrdat(CONV_1_2_pot_bram_wrdat[i]),
        .wraddr(CONV_1_2_pot_bram_wraddr[i]),
        .wren(CONV_1_2_pot_bram_wren[i])
    );
    end
 endgenerate

  (* DONT_TOUCH = "yes" *)
  bram_spk #(
    .RAM_DEPTH(CONV_1_2_SPK_BRAM_DEPTH), 
    .RAM_WIDTH(CONV_1_2_OUTPUT_FRAME_SIZE_MP))
 CONV_1_2_spk_ram (
    .clk(clk), .rst(rst),
    .rdat(CONV_1_2_spk_bram_rdat),
    .raddr(CONV_1_2_spk_bram_raddr),
    .ren(CONV_1_2_spk_bram_ren),
    .wrdat(CONV_1_2_spk_bram_wrdat), 
    .wraddr(CONV_1_2_spk_bram_wraddr), 
    .wren(CONV_1_2_spk_bram_wren)
 );



  logic [1:0] CONV_1_2_state, CONV_1_2_state_nxt;
  logic [CONV_1_2_EC_SIZE-1:0] CONV_1_2_nc_iter, CONV_1_2_nc_iter_nxt;

  always_ff @(posedge clk) begin
    CONV_1_2_state <= CONV_1_2_state_nxt;
    CONV_1_2_nc_iter <= CONV_1_2_nc_iter_nxt;
    CONV_1_2_spk_bram_wraddr <= CONV_1_2_spk_bram_wraddr_nxt;
    CONV_1_2_spk_bram_wrdat <= CONV_1_2_spk_bram_wrdat_nxt;
    CONV_1_2_spk_bram_wren <= CONV_1_2_spk_bram_wren_nxt;
  end
  
  always_comb begin
    if(rst) begin
        CONV_1_2_state_nxt = 0;
        CONV_1_2_nc_iter_nxt = 0;
        CONV_1_2_spk_bram_wraddr_nxt = 0;
        CONV_1_2_spk_bram_wrdat_nxt = 0;
        CONV_1_2_spk_bram_wren_nxt = 0;
    end else begin 
        CONV_1_2_state_nxt = CONV_1_2_state;
        CONV_1_2_nc_iter_nxt = CONV_1_2_nc_iter;
        CONV_1_2_spk_bram_wraddr_nxt = CONV_1_2_spk_bram_wraddr;
        CONV_1_2_spk_bram_wrdat_nxt = CONV_1_2_spk_bram_wrdat;
        CONV_1_2_spk_bram_wren_nxt = CONV_1_2_spk_bram_wren;
        case(CONV_1_2_state)
            0: begin
                if(CONV_1_2_new_spk_train) CONV_1_2_state_nxt = 1;
            end
            1:begin
                CONV_1_2_spk_bram_wraddr_nxt = (CONV_1_2_time_step_out_spikes)*CONV_1_2_OUTPUT_CHANNELS + CONV_1_2_oc_phase_shifted*CONV_1_2_EC_SIZE + CONV_1_2_nc_iter;
                //CONV_1_2_spk_bram_wrdat_nxt = CONV_1_2_post_syn_spk[CONV_1_2_nc_iter];
                for (int j = 0; j < CONV_1_2_OUTPUT_FRAME_SIZE_MP; j++) begin // assuming 2x2 maxpool
                   CONV_1_2_spk_bram_wrdat_nxt[j] = CONV_1_2_post_syn_spk[CONV_1_2_nc_iter][4*j]
                                                 | CONV_1_2_post_syn_spk[CONV_1_2_nc_iter][4*j + 1] 
                                                 | CONV_1_2_post_syn_spk[CONV_1_2_nc_iter][4*j + 2] 
                                                 | CONV_1_2_post_syn_spk[CONV_1_2_nc_iter][4*j + 3];
                end
                CONV_1_2_spk_bram_wren_nxt = 1;
                CONV_1_2_nc_iter_nxt = CONV_1_2_nc_iter + 1;
                CONV_1_2_state_nxt = 2;
            end
            2: begin
                CONV_1_2_state_nxt = 3;
            end
            3: begin
                CONV_1_2_spk_bram_wren_nxt = 0;
                if(CONV_1_2_nc_iter == CONV_1_2_EC_SIZE) begin
                    CONV_1_2_state_nxt = 0;
                    CONV_1_2_nc_iter_nxt = 0;
                end else CONV_1_2_state_nxt = 1;
            end
        endcase
    end  
  end




  localparam CONV_2_1_INPUT_CHANNELS = CONV_1_2_OUTPUT_CHANNELS;
  localparam CONV_2_1_OUTPUT_CHANNELS = USER_SET_CONV_2_1_SIZE; // Change this as per your design
  localparam CONV_2_1_KERNEL_SIZE = 3; // Change this as per your design
  localparam CONV_2_1_INPUT_FRAME_WIDTH = CONV_1_2_OUTPUT_FRAME_WIDTH/2; // maxpooling 2x2
  localparam CONV_2_1_INPUT_FRAME_SIZE = CONV_2_1_INPUT_FRAME_WIDTH*CONV_2_1_INPUT_FRAME_WIDTH;
  localparam CONV_2_1_OUTPUT_FRAME_WIDTH = CONV_2_1_INPUT_FRAME_WIDTH;
  localparam CONV_2_1_OUTPUT_FRAME_SIZE = CONV_2_1_OUTPUT_FRAME_WIDTH * CONV_2_1_OUTPUT_FRAME_WIDTH;
  // localparam CONV_2_1_OUTPUT_FRAME_SIZE_MP = CONV_2_1_OUTPUT_FRAME_SIZE/4;
  localparam CONV_2_1_EC_SIZE = USER_SET_CONV_2_1_EC_SIZE; // Change this as per your design
  localparam CONV_2_1_SPARSE_SIZE = CONV_2_1_INPUT_FRAME_SIZE>>1;
  localparam CONV_2_1_PENC_SIZE = CONV_2_1_INPUT_FRAME_SIZE>>2;
  localparam CONV_2_1_POT_BRAM_ADDR_WIDTH = $clog2(CONV_2_1_OUTPUT_FRAME_SIZE); 
  localparam CONV_2_1_SPK_BRAM_DEPTH = TIME_STEPS * CONV_2_1_OUTPUT_CHANNELS;



  logic [CONV_2_1_OUTPUT_FRAME_SIZE-1:0] CONV_2_1_spk_bram_wrdat, CONV_2_1_spk_bram_wrdat_nxt;
  logic [$clog2(CONV_2_1_SPK_BRAM_DEPTH)-1:0] CONV_2_1_spk_bram_wraddr, CONV_2_1_spk_bram_wraddr_nxt;
  logic CONV_2_1_spk_bram_wren, CONV_2_1_spk_bram_wren_nxt;
  logic [CONV_2_1_OUTPUT_FRAME_SIZE-1:0] CONV_2_1_spk_bram_rdat;
  logic [$clog2(CONV_2_1_SPK_BRAM_DEPTH)-1:0] CONV_2_1_spk_bram_raddr;
  logic CONV_2_1_spk_bram_ren;
  logic [$clog2(CONV_2_1_INPUT_FRAME_WIDTH)-1:0] CONV_2_1_affect_neur_addr_row[CONV_2_1_EC_SIZE-1:0], CONV_2_1_affect_neur_addr_col[CONV_2_1_EC_SIZE-1:0];
  logic [$clog2(CONV_2_1_INPUT_CHANNELS)+1:0] CONV_2_1_channel;
  logic [$clog2(TIME_STEPS):0] CONV_2_1_time_step_out_spikes, CONV_2_1_time_step_in_spikes;
  logic CONV_2_1_neur_addr_invalid;
  assign CONV_1_2_spk_bram_raddr = CONV_2_1_channel +  CONV_2_1_time_step_in_spikes*CONV_1_2_OUTPUT_CHANNELS;
  
  int CONV_2_1_input_spks = 0;
  logic [$clog2(8*CONV_2_1_SPARSE_SIZE)-1:0] CONV_2_1_cumm_spks;

  logic CONV_2_1_en_accum, CONV_2_1_en_activ;
  logic CONV_2_1_ram_clk;

  `ifdef SIM
  shortreal CONV_2_1_pot_bram_rdat [CONV_2_1_EC_SIZE-1:0];
  shortreal CONV_2_1_pot_bram_wrdat [CONV_2_1_EC_SIZE-1:0];
  `else
  logic [31:0] CONV_2_1_pot_bram_rdat [CONV_2_1_EC_SIZE-1:0];
  logic [31:0] CONV_2_1_pot_bram_wrdat [CONV_2_1_EC_SIZE-1:0];
  `endif

  logic [CONV_2_1_POT_BRAM_ADDR_WIDTH-1:0] CONV_2_1_pot_bram_raddr [CONV_2_1_EC_SIZE-1:0], CONV_2_1_pot_bram_wraddr [CONV_2_1_EC_SIZE-1:0];
  logic CONV_2_1_pot_bram_ren [CONV_2_1_EC_SIZE-1:0], CONV_2_1_pot_bram_wren [CONV_2_1_EC_SIZE-1:0];
  logic [CONV_2_1_OUTPUT_FRAME_SIZE-1:0] CONV_2_1_post_syn_spk [CONV_2_1_EC_SIZE-1:0]; 
  // logic [CONV_2_1_OUTPUT_FRAME_SIZE-1:0] CONV_2_1_post_syn_spk_ored [CONV_2_1_EC_SIZE-1:0]; 
  logic [$clog2(CONV_2_1_KERNEL_SIZE)+1:0] CONV_2_1_filter_phase;
  logic CONV_2_1_new_spk_train, CONV_2_1_last_time_step, CONV_2_1_ic_done;
  logic [$clog2(CONV_2_1_OUTPUT_CHANNELS)+1:0] CONV_2_1_oc_phase, CONV_2_1_oc_phase_shifted;

    (* DONT_TOUCH = "yes" *)
    conv_ec 
    #(.TIME_STEPS(TIME_STEPS),
    .INPUT_CHANNELS(CONV_2_1_INPUT_CHANNELS),
    .OUTPUT_CHANNELS(CONV_2_1_OUTPUT_CHANNELS),
    .KERNEL_SIZE(CONV_2_1_KERNEL_SIZE),
    .INPUT_FRAME_WIDTH(CONV_2_1_INPUT_FRAME_WIDTH),
    .INPUT_FRAME_SIZE(CONV_2_1_INPUT_FRAME_SIZE),
    .OUTPUT_FRAME_WIDTH(CONV_2_1_OUTPUT_FRAME_WIDTH),
    .OUTPUT_FRAME_SIZE(CONV_2_1_OUTPUT_FRAME_SIZE),
    .EC_SIZE(CONV_2_1_EC_SIZE),
    .SPARSE_SIZE(CONV_2_1_SPARSE_SIZE), 
    .PENC_SIZE(CONV_2_1_PENC_SIZE))
    CONV_2_1_ec (
    .clk(clk), .rst(rst),
    .pre_syn_RAM_loaded(CONV_1_2_spk_RAM_loaded), // Connect to output of CONV_1_2 layer
    .post_syn_RAM_loaded(CONV_2_1_spk_RAM_loaded),
    .new_spk_train_ready(CONV_2_1_new_spk_train),
    .last_time_step(CONV_2_1_last_time_step), // Add this line
    .ic_done(CONV_2_1_ic_done), // Add this line
    .spk_in_train(CONV_1_2_spk_bram_rdat),
    .spk_in_ram_en(CONV_1_2_spk_bram_ren),
    .ic(CONV_2_1_channel),
    .oc_phase(CONV_2_1_oc_phase),
    .oc_phase_shift(CONV_2_1_oc_phase_shifted),
    .time_step_out_spikes(CONV_2_1_time_step_out_spikes),
    .time_step_in_spikes(CONV_2_1_time_step_in_spikes),
    .affect_neur_addr_row(CONV_2_1_affect_neur_addr_row),
    .affect_neur_addr_col(CONV_2_1_affect_neur_addr_col),
    .neur_addr_invalid(CONV_2_1_neur_addr_invalid),
    .filter_phase(CONV_2_1_filter_phase),
    .en_accum(CONV_2_1_en_accum),
    .en_activ(CONV_2_1_en_activ),
    .cumm_spks(CONV_2_1_cumm_spks),
    .total_layer_spks_in(CONV_2_1_input_spks),
    .total_layer_spks_out(CONV_2_1_input_spks)
    );

 generate
    for (genvar i=0; i<CONV_2_1_EC_SIZE; i=i+1) begin : gen_3
    conv_nc #(
        .NEURON_OFFSET(i),
        .IN_CHANNELS(CONV_2_1_INPUT_CHANNELS),
        .OUT_CHANNELS(CONV_2_1_OUTPUT_CHANNELS),
        .EC_SIZE(CONV_2_1_EC_SIZE),
        .KERNEL_SIZE(CONV_2_1_KERNEL_SIZE),
        .INPUT_FRAME_WIDTH(CONV_2_1_INPUT_FRAME_WIDTH),
        .OUTPUT_FRAME_WIDTH(CONV_2_1_OUTPUT_FRAME_WIDTH),
        .BRAM_ADDR_WIDTH(CONV_2_1_POT_BRAM_ADDR_WIDTH),
        .w_sfactor(`w_sfactor_2_1),
        .b_sfactor(`b_sfactor_2_1),
        .w_zpt(`w_zpt_2_1),
        .b_zpt(`b_zpt_2_1),
        .WEIGHT_FILENAME($sformatf("%s/weights/conv2_1_nc%0d.txt", model_dir, i))
    ) CONV_2_1_nc_i (
        .clk(clk), .rst(rst),
        .en_accum(CONV_2_1_en_accum),
        .en_activ(CONV_2_1_en_activ),
        .ic(CONV_2_1_channel),
        .oc_phase(CONV_2_1_oc_phase),
        .filter_phase(CONV_2_1_filter_phase),
        .affect_neur_addr_row(CONV_2_1_affect_neur_addr_row[i]),
        .affect_neur_addr_col(CONV_2_1_affect_neur_addr_col[i]),
        .neur_addr_invalid(CONV_2_1_neur_addr_invalid),
        .last_time_step(CONV_2_1_last_time_step), // Add this line
        .ic_done(CONV_2_1_ic_done), // Add this line
        .post_syn_spk(CONV_2_1_post_syn_spk[i]),
        .bram_rdat(CONV_2_1_pot_bram_rdat[i]),
        .bram_raddr(CONV_2_1_pot_bram_raddr[i]),
        .bram_ren(CONV_2_1_pot_bram_ren[i]),
        .bram_wrdat(CONV_2_1_pot_bram_wrdat[i]),
        .bram_wraddr(CONV_2_1_pot_bram_wraddr[i]),
        .bram_wren(CONV_2_1_pot_bram_wren[i])
    );

    (* DONT_TOUCH = "yes" *)
    bram_pot #(
        .RAM_DEPTH(CONV_2_1_OUTPUT_FRAME_SIZE))
    CONV_2_1_pot_ram (
        .clk(clk), .rst(rst),
        .rdat(CONV_2_1_pot_bram_rdat[i]),
        .raddr(CONV_2_1_pot_bram_raddr[i]),
        .ren(CONV_2_1_pot_bram_ren[i]),
        .wrdat(CONV_2_1_pot_bram_wrdat[i]),
        .wraddr(CONV_2_1_pot_bram_wraddr[i]),
        .wren(CONV_2_1_pot_bram_wren[i])
    );
    end
 endgenerate

  (* DONT_TOUCH = "yes" *)
  bram_spk #(
    .RAM_DEPTH(CONV_2_1_SPK_BRAM_DEPTH), 
    .RAM_WIDTH(CONV_2_1_OUTPUT_FRAME_SIZE))
 CONV_2_1_spk_ram (
    .clk(clk), .rst(rst),
    .rdat(CONV_2_1_spk_bram_rdat),
    .raddr(CONV_2_1_spk_bram_raddr),
    .ren(CONV_2_1_spk_bram_ren),
    .wrdat(CONV_2_1_spk_bram_wrdat), 
    .wraddr(CONV_2_1_spk_bram_wraddr), 
    .wren(CONV_2_1_spk_bram_wren)
 );



  logic [1:0] CONV_2_1_state, CONV_2_1_state_nxt;
  logic [CONV_2_1_EC_SIZE-1:0] CONV_2_1_nc_iter, CONV_2_1_nc_iter_nxt;

  always_ff @(posedge clk) begin
    CONV_2_1_state <= CONV_2_1_state_nxt;
    CONV_2_1_nc_iter <= CONV_2_1_nc_iter_nxt;
    CONV_2_1_spk_bram_wraddr <= CONV_2_1_spk_bram_wraddr_nxt;
    CONV_2_1_spk_bram_wrdat <= CONV_2_1_spk_bram_wrdat_nxt;
    CONV_2_1_spk_bram_wren <= CONV_2_1_spk_bram_wren_nxt;
  end
  
  always_comb begin
    if(rst) begin
        CONV_2_1_state_nxt = 0;
        CONV_2_1_nc_iter_nxt = 0;
        CONV_2_1_spk_bram_wraddr_nxt = 0;
        CONV_2_1_spk_bram_wrdat_nxt = 0;
        CONV_2_1_spk_bram_wren_nxt = 0;
    end else begin 
        CONV_2_1_state_nxt = CONV_2_1_state;
        CONV_2_1_nc_iter_nxt = CONV_2_1_nc_iter;
        CONV_2_1_spk_bram_wraddr_nxt = CONV_2_1_spk_bram_wraddr;
        CONV_2_1_spk_bram_wrdat_nxt = CONV_2_1_spk_bram_wrdat;
        CONV_2_1_spk_bram_wren_nxt = CONV_2_1_spk_bram_wren;
        case(CONV_2_1_state)
            0: begin
                if(CONV_2_1_new_spk_train) CONV_2_1_state_nxt = 1;
            end
            1:begin
                CONV_2_1_spk_bram_wraddr_nxt = (CONV_2_1_time_step_out_spikes)*CONV_2_1_OUTPUT_CHANNELS + CONV_2_1_oc_phase_shifted*CONV_2_1_EC_SIZE + CONV_2_1_nc_iter;
                CONV_2_1_spk_bram_wrdat_nxt = CONV_2_1_post_syn_spk[CONV_2_1_nc_iter];
                
                CONV_2_1_spk_bram_wren_nxt = 1;
                CONV_2_1_nc_iter_nxt = CONV_2_1_nc_iter + 1;
                CONV_2_1_state_nxt = 2;
            end
            2: begin
                CONV_2_1_state_nxt = 3;
            end
            3: begin
                CONV_2_1_spk_bram_wren_nxt = 0;
                if(CONV_2_1_nc_iter == CONV_2_1_EC_SIZE) begin
                    CONV_2_1_state_nxt = 0;
                    CONV_2_1_nc_iter_nxt = 0;
                end else CONV_2_1_state_nxt = 1;
            end
        endcase
    end  
  end





  localparam CONV_2_2_INPUT_CHANNELS = CONV_2_1_OUTPUT_CHANNELS;
  localparam CONV_2_2_OUTPUT_CHANNELS = USER_SET_CONV_2_2_SIZE; // Change this as per your design
  localparam CONV_2_2_KERNEL_SIZE = 3; // Change this as per your design
  localparam CONV_2_2_INPUT_FRAME_WIDTH = CONV_2_1_OUTPUT_FRAME_WIDTH; 
  localparam CONV_2_2_INPUT_FRAME_SIZE = CONV_2_2_INPUT_FRAME_WIDTH*CONV_2_2_INPUT_FRAME_WIDTH;
  localparam CONV_2_2_OUTPUT_FRAME_WIDTH = CONV_2_2_INPUT_FRAME_WIDTH;
  localparam CONV_2_2_OUTPUT_FRAME_SIZE = CONV_2_2_OUTPUT_FRAME_WIDTH * CONV_2_2_OUTPUT_FRAME_WIDTH;
  localparam CONV_2_2_OUTPUT_FRAME_SIZE_MP = CONV_2_2_OUTPUT_FRAME_SIZE/4;
  localparam CONV_2_2_EC_SIZE = USER_SET_CONV_2_2_EC_SIZE; // Change this as per your design
  localparam CONV_2_2_SPARSE_SIZE = CONV_2_2_INPUT_FRAME_SIZE>>1;
  localparam CONV_2_2_PENC_SIZE = CONV_2_2_INPUT_FRAME_SIZE>>2;
  localparam CONV_2_2_POT_BRAM_ADDR_WIDTH = $clog2(CONV_2_2_OUTPUT_FRAME_SIZE); 
  localparam CONV_2_2_SPK_BRAM_DEPTH = TIME_STEPS * CONV_2_2_OUTPUT_CHANNELS;



  logic [CONV_2_2_OUTPUT_FRAME_SIZE_MP-1:0] CONV_2_2_spk_bram_wrdat, CONV_2_2_spk_bram_wrdat_nxt;
  logic [$clog2(CONV_2_2_SPK_BRAM_DEPTH)-1:0] CONV_2_2_spk_bram_wraddr, CONV_2_2_spk_bram_wraddr_nxt;
  logic CONV_2_2_spk_bram_wren, CONV_2_2_spk_bram_wren_nxt;
  logic [CONV_2_2_OUTPUT_FRAME_SIZE_MP-1:0] CONV_2_2_spk_bram_rdat;
  logic [$clog2(CONV_2_2_SPK_BRAM_DEPTH)-1:0] CONV_2_2_spk_bram_raddr;
  logic CONV_2_2_spk_bram_ren;
  logic [$clog2(CONV_2_2_INPUT_FRAME_WIDTH)-1:0] CONV_2_2_affect_neur_addr_row[CONV_2_2_EC_SIZE-1:0], CONV_2_2_affect_neur_addr_col[CONV_2_2_EC_SIZE-1:0];
  logic [$clog2(CONV_2_2_INPUT_CHANNELS)+1:0] CONV_2_2_channel;
  logic [$clog2(TIME_STEPS):0] CONV_2_2_time_step_out_spikes, CONV_2_2_time_step_in_spikes;
  logic CONV_2_2_neur_addr_invalid;
  assign CONV_2_1_spk_bram_raddr = CONV_2_2_channel +  CONV_2_2_time_step_in_spikes*CONV_2_1_OUTPUT_CHANNELS;
  
  int CONV_2_2_input_spks = 0;
  logic [$clog2(8*CONV_2_2_SPARSE_SIZE)-1:0] CONV_2_2_cumm_spks;

  logic CONV_2_2_en_accum, CONV_2_2_en_activ;
  logic CONV_2_2_ram_clk;

  `ifdef SIM
  shortreal CONV_2_2_pot_bram_rdat [CONV_2_2_EC_SIZE-1:0];
  shortreal CONV_2_2_pot_bram_wrdat [CONV_2_2_EC_SIZE-1:0];
  `else
  logic [31:0] CONV_2_2_pot_bram_rdat [CONV_2_2_EC_SIZE-1:0];
  logic [31:0] CONV_2_2_pot_bram_wrdat [CONV_2_2_EC_SIZE-1:0];
  `endif

  logic [CONV_2_2_POT_BRAM_ADDR_WIDTH-1:0] CONV_2_2_pot_bram_raddr [CONV_2_2_EC_SIZE-1:0], CONV_2_2_pot_bram_wraddr [CONV_2_2_EC_SIZE-1:0];
  logic CONV_2_2_pot_bram_ren [CONV_2_2_EC_SIZE-1:0], CONV_2_2_pot_bram_wren [CONV_2_2_EC_SIZE-1:0];
  logic [CONV_2_2_OUTPUT_FRAME_SIZE-1:0] CONV_2_2_post_syn_spk [CONV_2_2_EC_SIZE-1:0]; 
  logic [CONV_2_2_OUTPUT_FRAME_SIZE/4-1:0] CONV_2_2_post_syn_spk_ored [CONV_2_2_EC_SIZE-1:0]; 
  logic [$clog2(CONV_2_2_KERNEL_SIZE)+1:0] CONV_2_2_filter_phase;
  logic CONV_2_2_new_spk_train, CONV_2_2_last_time_step, CONV_2_2_ic_done;
  logic [$clog2(CONV_2_2_OUTPUT_CHANNELS)+1:0] CONV_2_2_oc_phase, CONV_2_2_oc_phase_shifted;

    (* DONT_TOUCH = "yes" *)
    conv_ec 
    #(.TIME_STEPS(TIME_STEPS),
    .INPUT_CHANNELS(CONV_2_2_INPUT_CHANNELS),
    .OUTPUT_CHANNELS(CONV_2_2_OUTPUT_CHANNELS),
    .KERNEL_SIZE(CONV_2_2_KERNEL_SIZE),
    .INPUT_FRAME_WIDTH(CONV_2_2_INPUT_FRAME_WIDTH),
    .INPUT_FRAME_SIZE(CONV_2_2_INPUT_FRAME_SIZE),
    .OUTPUT_FRAME_WIDTH(CONV_2_2_OUTPUT_FRAME_WIDTH),
    .OUTPUT_FRAME_SIZE(CONV_2_2_OUTPUT_FRAME_SIZE),
    .EC_SIZE(CONV_2_2_EC_SIZE),
    .SPARSE_SIZE(CONV_2_2_SPARSE_SIZE), 
    .PENC_SIZE(CONV_2_2_PENC_SIZE))
    CONV_2_2_ec (
    .clk(clk), .rst(rst),
    .pre_syn_RAM_loaded(CONV_2_1_spk_RAM_loaded), // Connect to output of CONV_2_1 layer
    .post_syn_RAM_loaded(CONV_2_2_spk_RAM_loaded),
    .new_spk_train_ready(CONV_2_2_new_spk_train),
    .last_time_step(CONV_2_2_last_time_step), // Add this line
    .ic_done(CONV_2_2_ic_done), // Add this line
    .spk_in_train(CONV_2_1_spk_bram_rdat),
    .spk_in_ram_en(CONV_2_1_spk_bram_ren),
    .ic(CONV_2_2_channel),
    .oc_phase(CONV_2_2_oc_phase),
    .oc_phase_shift(CONV_2_2_oc_phase_shifted),
    .time_step_out_spikes(CONV_2_2_time_step_out_spikes),
    .time_step_in_spikes(CONV_2_2_time_step_in_spikes),
    .affect_neur_addr_row(CONV_2_2_affect_neur_addr_row),
    .affect_neur_addr_col(CONV_2_2_affect_neur_addr_col),
    .neur_addr_invalid(CONV_2_2_neur_addr_invalid),
    .filter_phase(CONV_2_2_filter_phase),
    .en_accum(CONV_2_2_en_accum),
    .en_activ(CONV_2_2_en_activ),
    .cumm_spks(CONV_2_2_cumm_spks),
    .total_layer_spks_in(CONV_2_2_input_spks),
    .total_layer_spks_out(CONV_2_2_input_spks)
    );

 generate
    for (genvar i=0; i<CONV_2_2_EC_SIZE; i=i+1) begin : gen_4
    conv_nc #(
        .NEURON_OFFSET(i),
        .IN_CHANNELS(CONV_2_2_INPUT_CHANNELS),
        .OUT_CHANNELS(CONV_2_2_OUTPUT_CHANNELS),
        .EC_SIZE(CONV_2_2_EC_SIZE),
        .KERNEL_SIZE(CONV_2_2_KERNEL_SIZE),
        .INPUT_FRAME_WIDTH(CONV_2_2_INPUT_FRAME_WIDTH),
        .OUTPUT_FRAME_WIDTH(CONV_2_2_OUTPUT_FRAME_WIDTH),
        .BRAM_ADDR_WIDTH(CONV_2_2_POT_BRAM_ADDR_WIDTH),
        .w_sfactor(`w_sfactor_2_2),
        .b_sfactor(`b_sfactor_2_2),
        .w_zpt(`w_zpt_2_2),
        .b_zpt(`b_zpt_2_2),
        .WEIGHT_FILENAME($sformatf("%s/weights/conv2_2_nc%0d.txt", model_dir, i))
    ) CONV_2_2_nc_i (
        .clk(clk), .rst(rst),
        .en_accum(CONV_2_2_en_accum),
        .en_activ(CONV_2_2_en_activ),
        .ic(CONV_2_2_channel),
        .oc_phase(CONV_2_2_oc_phase),
        .filter_phase(CONV_2_2_filter_phase),
        .affect_neur_addr_row(CONV_2_2_affect_neur_addr_row[i]),
        .affect_neur_addr_col(CONV_2_2_affect_neur_addr_col[i]),
        .neur_addr_invalid(CONV_2_2_neur_addr_invalid),
        .last_time_step(CONV_2_2_last_time_step), // Add this line
        .ic_done(CONV_2_2_ic_done), // Add this line
        .post_syn_spk(CONV_2_2_post_syn_spk[i]), // ?
        .bram_rdat(CONV_2_2_pot_bram_rdat[i]),
        .bram_raddr(CONV_2_2_pot_bram_raddr[i]),
        .bram_ren(CONV_2_2_pot_bram_ren[i]),
        .bram_wrdat(CONV_2_2_pot_bram_wrdat[i]),
        .bram_wraddr(CONV_2_2_pot_bram_wraddr[i]),
        .bram_wren(CONV_2_2_pot_bram_wren[i])
    );

    (* DONT_TOUCH = "yes" *)
    bram_pot #(
        .RAM_DEPTH(CONV_2_2_OUTPUT_FRAME_SIZE))
    CONV_2_2_pot_ram (
        .clk(clk), .rst(rst),
        .rdat(CONV_2_2_pot_bram_rdat[i]),
        .raddr(CONV_2_2_pot_bram_raddr[i]),
        .ren(CONV_2_2_pot_bram_ren[i]),
        .wrdat(CONV_2_2_pot_bram_wrdat[i]),
        .wraddr(CONV_2_2_pot_bram_wraddr[i]),
        .wren(CONV_2_2_pot_bram_wren[i])
    );
    end
 endgenerate

  (* DONT_TOUCH = "yes" *)
  bram_spk #(
    .RAM_DEPTH(CONV_2_2_SPK_BRAM_DEPTH), 
    .RAM_WIDTH(CONV_2_2_OUTPUT_FRAME_SIZE_MP))
 CONV_2_2_spk_ram (
    .clk(clk), .rst(rst),
    .rdat(CONV_2_2_spk_bram_rdat),
    .raddr(CONV_2_2_spk_bram_raddr),
    .ren(CONV_2_2_spk_bram_ren),
    .wrdat(CONV_2_2_spk_bram_wrdat), 
    .wraddr(CONV_2_2_spk_bram_wraddr), 
    .wren(CONV_2_2_spk_bram_wren)
 );



  logic [1:0] CONV_2_2_state, CONV_2_2_state_nxt;
  logic [CONV_2_2_EC_SIZE-1:0] CONV_2_2_nc_iter, CONV_2_2_nc_iter_nxt;

  always_ff @(posedge clk) begin
    CONV_2_2_state <= CONV_2_2_state_nxt;
    CONV_2_2_nc_iter <= CONV_2_2_nc_iter_nxt;
    CONV_2_2_spk_bram_wraddr <= CONV_2_2_spk_bram_wraddr_nxt;
    CONV_2_2_spk_bram_wrdat <= CONV_2_2_spk_bram_wrdat_nxt;
    CONV_2_2_spk_bram_wren <= CONV_2_2_spk_bram_wren_nxt;
  end
  
  always_comb begin
    if(rst) begin
        CONV_2_2_state_nxt = 0;
        CONV_2_2_nc_iter_nxt = 0;
        CONV_2_2_spk_bram_wraddr_nxt = 0;
        CONV_2_2_spk_bram_wrdat_nxt = 0;
        CONV_2_2_spk_bram_wren_nxt = 0;
    end else begin 
        CONV_2_2_state_nxt = CONV_2_2_state;
        CONV_2_2_nc_iter_nxt = CONV_2_2_nc_iter;
        CONV_2_2_spk_bram_wraddr_nxt = CONV_2_2_spk_bram_wraddr;
        CONV_2_2_spk_bram_wrdat_nxt = CONV_2_2_spk_bram_wrdat;
        CONV_2_2_spk_bram_wren_nxt = CONV_2_2_spk_bram_wren;
        case(CONV_2_2_state)
            0: begin
                if(CONV_2_2_new_spk_train) CONV_2_2_state_nxt = 1;
            end
            1:begin
                CONV_2_2_spk_bram_wraddr_nxt = (CONV_2_2_time_step_out_spikes)*CONV_2_2_OUTPUT_CHANNELS + CONV_2_2_oc_phase_shifted*CONV_2_2_EC_SIZE + CONV_2_2_nc_iter;
                //CONV_2_2_spk_bram_wrdat_nxt = CONV_2_2_post_syn_spk[CONV_2_2_nc_iter];
                for (int j = 0; j < CONV_2_2_OUTPUT_FRAME_SIZE_MP; j++) begin // assuming 2x2 maxpool
                   CONV_2_2_spk_bram_wrdat_nxt[j] = CONV_2_2_post_syn_spk[CONV_2_2_nc_iter][4*j]  // ?
                                                 | CONV_2_2_post_syn_spk[CONV_2_2_nc_iter][4*j + 1] 
                                                 | CONV_2_2_post_syn_spk[CONV_2_2_nc_iter][4*j + 2] 
                                                 | CONV_2_2_post_syn_spk[CONV_2_2_nc_iter][4*j + 3];
                end
                
                CONV_2_2_spk_bram_wren_nxt = 1;
                CONV_2_2_nc_iter_nxt = CONV_2_2_nc_iter + 1;
                CONV_2_2_state_nxt = 2;
            end
            2: begin
                CONV_2_2_state_nxt = 3;
            end
            3: begin
                CONV_2_2_spk_bram_wren_nxt = 0;
                if(CONV_2_2_nc_iter == CONV_2_2_EC_SIZE) begin
                    CONV_2_2_state_nxt = 0;
                    CONV_2_2_nc_iter_nxt = 0;
                end else CONV_2_2_state_nxt = 1;
            end
        endcase
    end  
  end




  localparam CONV_3_1_INPUT_CHANNELS = CONV_2_2_OUTPUT_CHANNELS;
  localparam CONV_3_1_OUTPUT_CHANNELS = USER_SET_CONV_3_1_SIZE; // Change this as per your design
  localparam CONV_3_1_KERNEL_SIZE = 3; // Change this as per your design
  localparam CONV_3_1_INPUT_FRAME_WIDTH = CONV_2_2_OUTPUT_FRAME_WIDTH/2; // maxpooling 2x2
  localparam CONV_3_1_INPUT_FRAME_SIZE = CONV_3_1_INPUT_FRAME_WIDTH*CONV_3_1_INPUT_FRAME_WIDTH;
  localparam CONV_3_1_OUTPUT_FRAME_WIDTH = CONV_3_1_INPUT_FRAME_WIDTH;
  localparam CONV_3_1_OUTPUT_FRAME_SIZE = CONV_3_1_OUTPUT_FRAME_WIDTH * CONV_3_1_OUTPUT_FRAME_WIDTH;
  // localparam CONV_3_1_OUTPUT_FRAME_SIZE_MP = CONV_3_1_OUTPUT_FRAME_SIZE/4;
  localparam CONV_3_1_EC_SIZE = USER_SET_CONV_3_1_EC_SIZE; // Change this as per your design
  localparam CONV_3_1_SPARSE_SIZE = CONV_3_1_INPUT_FRAME_SIZE>>1;
  localparam CONV_3_1_PENC_SIZE = CONV_3_1_INPUT_FRAME_SIZE>>2;
  localparam CONV_3_1_POT_BRAM_ADDR_WIDTH = $clog2(CONV_3_1_OUTPUT_FRAME_SIZE); 
  localparam CONV_3_1_SPK_BRAM_DEPTH = TIME_STEPS * CONV_3_1_OUTPUT_CHANNELS;



  logic [CONV_3_1_OUTPUT_FRAME_SIZE-1:0] CONV_3_1_spk_bram_wrdat, CONV_3_1_spk_bram_wrdat_nxt;
  logic [$clog2(CONV_3_1_SPK_BRAM_DEPTH)-1:0] CONV_3_1_spk_bram_wraddr, CONV_3_1_spk_bram_wraddr_nxt;
  logic CONV_3_1_spk_bram_wren, CONV_3_1_spk_bram_wren_nxt;
  logic [CONV_3_1_OUTPUT_FRAME_SIZE-1:0] CONV_3_1_spk_bram_rdat;
  logic [$clog2(CONV_3_1_SPK_BRAM_DEPTH)-1:0] CONV_3_1_spk_bram_raddr;
  logic CONV_3_1_spk_bram_ren;
  logic [$clog2(CONV_3_1_INPUT_FRAME_WIDTH)-1:0] CONV_3_1_affect_neur_addr_row[CONV_3_1_EC_SIZE-1:0], CONV_3_1_affect_neur_addr_col[CONV_3_1_EC_SIZE-1:0];
  logic [$clog2(CONV_3_1_INPUT_CHANNELS)+1:0] CONV_3_1_channel;
  logic [$clog2(TIME_STEPS):0] CONV_3_1_time_step_out_spikes, CONV_3_1_time_step_in_spikes;
  logic CONV_3_1_neur_addr_invalid;
  assign CONV_2_2_spk_bram_raddr = CONV_3_1_channel +  CONV_3_1_time_step_in_spikes*CONV_2_2_OUTPUT_CHANNELS;
  
  int CONV_3_1_input_spks = 0;
  logic [$clog2(8*CONV_3_1_SPARSE_SIZE)-1:0] CONV_3_1_cumm_spks;

  logic CONV_3_1_en_accum, CONV_3_1_en_activ;
  logic CONV_3_1_ram_clk;

  `ifdef SIM
  shortreal CONV_3_1_pot_bram_rdat [CONV_3_1_EC_SIZE-1:0];
  shortreal CONV_3_1_pot_bram_wrdat [CONV_3_1_EC_SIZE-1:0];
  `else
  logic [31:0] CONV_3_1_pot_bram_rdat [CONV_3_1_EC_SIZE-1:0];
  logic [31:0] CONV_3_1_pot_bram_wrdat [CONV_3_1_EC_SIZE-1:0];
  `endif

  logic [CONV_3_1_POT_BRAM_ADDR_WIDTH-1:0] CONV_3_1_pot_bram_raddr [CONV_3_1_EC_SIZE-1:0], CONV_3_1_pot_bram_wraddr [CONV_3_1_EC_SIZE-1:0];
  logic CONV_3_1_pot_bram_ren [CONV_3_1_EC_SIZE-1:0], CONV_3_1_pot_bram_wren [CONV_3_1_EC_SIZE-1:0];
  logic [CONV_3_1_OUTPUT_FRAME_SIZE-1:0] CONV_3_1_post_syn_spk [CONV_3_1_EC_SIZE-1:0]; 
  // logic [CONV_3_1_OUTPUT_FRAME_SIZE/4-1:0] CONV_3_1_post_syn_spk_ored [CONV_3_1_EC_SIZE-1:0]; 
  logic [$clog2(CONV_3_1_KERNEL_SIZE)+1:0] CONV_3_1_filter_phase;
  logic CONV_3_1_new_spk_train, CONV_3_1_last_time_step, CONV_3_1_ic_done;
  logic [$clog2(CONV_3_1_OUTPUT_CHANNELS)+1:0] CONV_3_1_oc_phase, CONV_3_1_oc_phase_shifted;

    (* DONT_TOUCH = "yes" *)
    conv_ec 
    #(.TIME_STEPS(TIME_STEPS),
    .INPUT_CHANNELS(CONV_3_1_INPUT_CHANNELS),
    .OUTPUT_CHANNELS(CONV_3_1_OUTPUT_CHANNELS),
    .KERNEL_SIZE(CONV_3_1_KERNEL_SIZE),
    .INPUT_FRAME_WIDTH(CONV_3_1_INPUT_FRAME_WIDTH),
    .INPUT_FRAME_SIZE(CONV_3_1_INPUT_FRAME_SIZE),
    .OUTPUT_FRAME_WIDTH(CONV_3_1_OUTPUT_FRAME_WIDTH),
    .OUTPUT_FRAME_SIZE(CONV_3_1_OUTPUT_FRAME_SIZE),
    .EC_SIZE(CONV_3_1_EC_SIZE),
    .SPARSE_SIZE(CONV_3_1_SPARSE_SIZE), 
    .PENC_SIZE(CONV_3_1_PENC_SIZE))
    CONV_3_1_ec (
    .clk(clk), .rst(rst),
    .pre_syn_RAM_loaded(CONV_2_2_spk_RAM_loaded), // Connect to output of CONV_2_2 layer
    .post_syn_RAM_loaded(CONV_3_1_spk_RAM_loaded),
    .new_spk_train_ready(CONV_3_1_new_spk_train),
    .last_time_step(CONV_3_1_last_time_step), // Add this line
    .ic_done(CONV_3_1_ic_done), // Add this line
    .spk_in_train(CONV_2_2_spk_bram_rdat),
    .spk_in_ram_en(CONV_2_2_spk_bram_ren),
    .ic(CONV_3_1_channel),
    .oc_phase(CONV_3_1_oc_phase),
    .oc_phase_shift(CONV_3_1_oc_phase_shifted),
    .time_step_out_spikes(CONV_3_1_time_step_out_spikes),
    .time_step_in_spikes(CONV_3_1_time_step_in_spikes),
    .affect_neur_addr_row(CONV_3_1_affect_neur_addr_row),
    .affect_neur_addr_col(CONV_3_1_affect_neur_addr_col),
    .neur_addr_invalid(CONV_3_1_neur_addr_invalid),
    .filter_phase(CONV_3_1_filter_phase),
    .en_accum(CONV_3_1_en_accum),
    .en_activ(CONV_3_1_en_activ),
    .cumm_spks(CONV_3_1_cumm_spks),
    .total_layer_spks_in(CONV_3_1_input_spks),
    .total_layer_spks_out(CONV_3_1_input_spks)
    );

 generate
    for (genvar i=0; i<CONV_3_1_EC_SIZE; i=i+1) begin : gen_5
    conv_nc #(
        .NEURON_OFFSET(i),
        .IN_CHANNELS(CONV_3_1_INPUT_CHANNELS),
        .OUT_CHANNELS(CONV_3_1_OUTPUT_CHANNELS),
        .EC_SIZE(CONV_3_1_EC_SIZE),
        .KERNEL_SIZE(CONV_3_1_KERNEL_SIZE),
        .INPUT_FRAME_WIDTH(CONV_3_1_INPUT_FRAME_WIDTH),
        .OUTPUT_FRAME_WIDTH(CONV_3_1_OUTPUT_FRAME_WIDTH),
        .BRAM_ADDR_WIDTH(CONV_3_1_POT_BRAM_ADDR_WIDTH),
        .w_sfactor(`w_sfactor_3_1),
        .b_sfactor(`b_sfactor_3_1),
        .w_zpt(`w_zpt_3_1),
        .b_zpt(`b_zpt_3_1),
        .WEIGHT_FILENAME($sformatf("%s/weights/conv3_1_nc%0d.txt", model_dir, i))
    ) CONV_3_1_nc_i (
        .clk(clk), .rst(rst),
        .en_accum(CONV_3_1_en_accum),
        .en_activ(CONV_3_1_en_activ),
        .ic(CONV_3_1_channel),
        .oc_phase(CONV_3_1_oc_phase),
        .filter_phase(CONV_3_1_filter_phase),
        .affect_neur_addr_row(CONV_3_1_affect_neur_addr_row[i]),
        .affect_neur_addr_col(CONV_3_1_affect_neur_addr_col[i]),
        .neur_addr_invalid(CONV_3_1_neur_addr_invalid),
        .last_time_step(CONV_3_1_last_time_step), // Add this line
        .ic_done(CONV_3_1_ic_done), // Add this line
        .post_syn_spk(CONV_3_1_post_syn_spk[i]),
        .bram_rdat(CONV_3_1_pot_bram_rdat[i]),
        .bram_raddr(CONV_3_1_pot_bram_raddr[i]),
        .bram_ren(CONV_3_1_pot_bram_ren[i]),
        .bram_wrdat(CONV_3_1_pot_bram_wrdat[i]),
        .bram_wraddr(CONV_3_1_pot_bram_wraddr[i]),
        .bram_wren(CONV_3_1_pot_bram_wren[i])
    );

    (* DONT_TOUCH = "yes" *)
    bram_pot #(
        .RAM_DEPTH(CONV_3_1_OUTPUT_FRAME_SIZE))
    CONV_3_1_pot_ram (
        .clk(clk), .rst(rst),
        .rdat(CONV_3_1_pot_bram_rdat[i]),
        .raddr(CONV_3_1_pot_bram_raddr[i]),
        .ren(CONV_3_1_pot_bram_ren[i]),
        .wrdat(CONV_3_1_pot_bram_wrdat[i]),
        .wraddr(CONV_3_1_pot_bram_wraddr[i]),
        .wren(CONV_3_1_pot_bram_wren[i])
    );
    end
 endgenerate

  (* DONT_TOUCH = "yes" *)
  bram_spk #(
    .RAM_DEPTH(CONV_3_1_SPK_BRAM_DEPTH), 
    .RAM_WIDTH(CONV_3_1_OUTPUT_FRAME_SIZE))
 CONV_3_1_spk_ram (
    .clk(clk), .rst(rst),
    .rdat(CONV_3_1_spk_bram_rdat),
    .raddr(CONV_3_1_spk_bram_raddr),
    .ren(CONV_3_1_spk_bram_ren),
    .wrdat(CONV_3_1_spk_bram_wrdat), 
    .wraddr(CONV_3_1_spk_bram_wraddr), 
    .wren(CONV_3_1_spk_bram_wren)
 );



  logic [1:0] CONV_3_1_state, CONV_3_1_state_nxt;
  logic [CONV_3_1_EC_SIZE-1:0] CONV_3_1_nc_iter, CONV_3_1_nc_iter_nxt;

  always_ff @(posedge clk) begin
    CONV_3_1_state <= CONV_3_1_state_nxt;
    CONV_3_1_nc_iter <= CONV_3_1_nc_iter_nxt;
    CONV_3_1_spk_bram_wraddr <= CONV_3_1_spk_bram_wraddr_nxt;
    CONV_3_1_spk_bram_wrdat <= CONV_3_1_spk_bram_wrdat_nxt;
    CONV_3_1_spk_bram_wren <= CONV_3_1_spk_bram_wren_nxt;
  end
  
  always_comb begin
    if(rst) begin
        CONV_3_1_state_nxt = 0;
        CONV_3_1_nc_iter_nxt = 0;
        CONV_3_1_spk_bram_wraddr_nxt = 0;
        CONV_3_1_spk_bram_wrdat_nxt = 0;
        CONV_3_1_spk_bram_wren_nxt = 0;
    end else begin 
        CONV_3_1_state_nxt = CONV_3_1_state;
        CONV_3_1_nc_iter_nxt = CONV_3_1_nc_iter;
        CONV_3_1_spk_bram_wraddr_nxt = CONV_3_1_spk_bram_wraddr;
        CONV_3_1_spk_bram_wrdat_nxt = CONV_3_1_spk_bram_wrdat;
        CONV_3_1_spk_bram_wren_nxt = CONV_3_1_spk_bram_wren;
        case(CONV_3_1_state)
            0: begin
                if(CONV_3_1_new_spk_train) CONV_3_1_state_nxt = 1;
            end
            1:begin
                CONV_3_1_spk_bram_wraddr_nxt = (CONV_3_1_time_step_out_spikes)*CONV_3_1_OUTPUT_CHANNELS + CONV_3_1_oc_phase_shifted*CONV_3_1_EC_SIZE + CONV_3_1_nc_iter;
                CONV_3_1_spk_bram_wrdat_nxt = CONV_3_1_post_syn_spk[CONV_3_1_nc_iter];
                
                CONV_3_1_spk_bram_wren_nxt = 1;
                CONV_3_1_nc_iter_nxt = CONV_3_1_nc_iter + 1;
                CONV_3_1_state_nxt = 2;
            end
            2: begin
                CONV_3_1_state_nxt = 3;
            end
            3: begin
                CONV_3_1_spk_bram_wren_nxt = 0;
                if(CONV_3_1_nc_iter == CONV_3_1_EC_SIZE) begin
                    CONV_3_1_state_nxt = 0;
                    CONV_3_1_nc_iter_nxt = 0;
                end else CONV_3_1_state_nxt = 1;
            end
        endcase
    end  
  end



  localparam CONV_3_2_INPUT_CHANNELS = CONV_3_1_OUTPUT_CHANNELS;
  localparam CONV_3_2_OUTPUT_CHANNELS = USER_SET_CONV_3_2_SIZE; // Change this as per your design
  localparam CONV_3_2_KERNEL_SIZE = 3; // Change this as per your design
  localparam CONV_3_2_INPUT_FRAME_WIDTH = CONV_3_1_OUTPUT_FRAME_WIDTH;
  localparam CONV_3_2_INPUT_FRAME_SIZE = CONV_3_2_INPUT_FRAME_WIDTH*CONV_3_2_INPUT_FRAME_WIDTH;
  localparam CONV_3_2_OUTPUT_FRAME_WIDTH = CONV_3_2_INPUT_FRAME_WIDTH;
  localparam CONV_3_2_OUTPUT_FRAME_SIZE = CONV_3_2_OUTPUT_FRAME_WIDTH * CONV_3_2_OUTPUT_FRAME_WIDTH;
  // localparam CONV_3_2_OUTPUT_FRAME_SIZE_MP = CONV_3_2_OUTPUT_FRAME_SIZE/4;
  localparam CONV_3_2_EC_SIZE = USER_SET_CONV_3_2_EC_SIZE; // Change this as per your design
  localparam CONV_3_2_SPARSE_SIZE = CONV_3_2_INPUT_FRAME_SIZE;
  localparam CONV_3_2_PENC_SIZE = CONV_3_2_INPUT_FRAME_SIZE>>2;
  localparam CONV_3_2_POT_BRAM_ADDR_WIDTH = $clog2(CONV_3_2_OUTPUT_FRAME_SIZE); 
  localparam CONV_3_2_SPK_BRAM_DEPTH = TIME_STEPS * CONV_3_2_OUTPUT_CHANNELS;



  logic [CONV_3_2_OUTPUT_FRAME_SIZE-1:0] CONV_3_2_spk_bram_wrdat, CONV_3_2_spk_bram_wrdat_nxt;
  logic [$clog2(CONV_3_2_SPK_BRAM_DEPTH)-1:0] CONV_3_2_spk_bram_wraddr, CONV_3_2_spk_bram_wraddr_nxt;
  logic CONV_3_2_spk_bram_wren, CONV_3_2_spk_bram_wren_nxt;
  logic [CONV_3_2_OUTPUT_FRAME_SIZE-1:0] CONV_3_2_spk_bram_rdat;
  logic [$clog2(CONV_3_2_SPK_BRAM_DEPTH)-1:0] CONV_3_2_spk_bram_raddr;
  logic CONV_3_2_spk_bram_ren;
  logic [$clog2(CONV_3_2_INPUT_FRAME_WIDTH)-1:0] CONV_3_2_affect_neur_addr_row[CONV_3_2_EC_SIZE-1:0], CONV_3_2_affect_neur_addr_col[CONV_3_2_EC_SIZE-1:0];
  logic [$clog2(CONV_3_2_INPUT_CHANNELS)+1:0] CONV_3_2_channel;
  logic [$clog2(TIME_STEPS):0] CONV_3_2_time_step_out_spikes, CONV_3_2_time_step_in_spikes;
  logic CONV_3_2_neur_addr_invalid;
  assign CONV_3_1_spk_bram_raddr = CONV_3_2_channel +  CONV_3_2_time_step_in_spikes*CONV_3_1_OUTPUT_CHANNELS;
  
  int CONV_3_2_input_spks = 0;
  logic [$clog2(8*CONV_3_2_SPARSE_SIZE)-1:0] CONV_3_2_cumm_spks;

  logic CONV_3_2_en_accum, CONV_3_2_en_activ;
  logic CONV_3_2_ram_clk;

  `ifdef SIM
  shortreal CONV_3_2_pot_bram_rdat [CONV_3_2_EC_SIZE-1:0];
  shortreal CONV_3_2_pot_bram_wrdat [CONV_3_2_EC_SIZE-1:0];
  `else
  logic [31:0] CONV_3_2_pot_bram_rdat [CONV_3_2_EC_SIZE-1:0];
  logic [31:0] CONV_3_2_pot_bram_wrdat [CONV_3_2_EC_SIZE-1:0];
  `endif

  logic [CONV_3_2_POT_BRAM_ADDR_WIDTH-1:0] CONV_3_2_pot_bram_raddr [CONV_3_2_EC_SIZE-1:0], CONV_3_2_pot_bram_wraddr [CONV_3_2_EC_SIZE-1:0];
  logic CONV_3_2_pot_bram_ren [CONV_3_2_EC_SIZE-1:0], CONV_3_2_pot_bram_wren [CONV_3_2_EC_SIZE-1:0];
  logic [CONV_3_2_OUTPUT_FRAME_SIZE-1:0] CONV_3_2_post_syn_spk [CONV_3_2_EC_SIZE-1:0]; 
  // logic [CONV_3_2_OUTPUT_FRAME_SIZE/4-1:0] CONV_3_2_post_syn_spk_ored [CONV_3_2_EC_SIZE-1:0]; 
  logic [$clog2(CONV_3_2_KERNEL_SIZE)+1:0] CONV_3_2_filter_phase;
  logic CONV_3_2_new_spk_train, CONV_3_2_last_time_step, CONV_3_2_ic_done;
  logic [$clog2(CONV_3_2_OUTPUT_CHANNELS)+1:0] CONV_3_2_oc_phase, CONV_3_2_oc_phase_shifted;

    (* DONT_TOUCH = "yes" *)
    conv_ec 
    #(.TIME_STEPS(TIME_STEPS),
    .INPUT_CHANNELS(CONV_3_2_INPUT_CHANNELS),
    .OUTPUT_CHANNELS(CONV_3_2_OUTPUT_CHANNELS),
    .KERNEL_SIZE(CONV_3_2_KERNEL_SIZE),
    .INPUT_FRAME_WIDTH(CONV_3_2_INPUT_FRAME_WIDTH),
    .INPUT_FRAME_SIZE(CONV_3_2_INPUT_FRAME_SIZE),
    .OUTPUT_FRAME_WIDTH(CONV_3_2_OUTPUT_FRAME_WIDTH),
    .OUTPUT_FRAME_SIZE(CONV_3_2_OUTPUT_FRAME_SIZE),
    .EC_SIZE(CONV_3_2_EC_SIZE),
    .SPARSE_SIZE(CONV_3_2_SPARSE_SIZE), 
    .PENC_SIZE(CONV_3_2_PENC_SIZE))
    CONV_3_2_ec (
    .clk(clk), .rst(rst),
    .pre_syn_RAM_loaded(CONV_3_1_spk_RAM_loaded), // Connect to output of CONV_3_1 layer
    .post_syn_RAM_loaded(CONV_3_2_spk_RAM_loaded),
    .new_spk_train_ready(CONV_3_2_new_spk_train),
    .last_time_step(CONV_3_2_last_time_step), // Add this line
    .ic_done(CONV_3_2_ic_done), // Add this line
    .spk_in_train(CONV_3_1_spk_bram_rdat),
    .spk_in_ram_en(CONV_3_1_spk_bram_ren),
    .ic(CONV_3_2_channel),
    .oc_phase(CONV_3_2_oc_phase),
    .oc_phase_shift(CONV_3_2_oc_phase_shifted),
    .time_step_out_spikes(CONV_3_2_time_step_out_spikes),
    .time_step_in_spikes(CONV_3_2_time_step_in_spikes),
    .affect_neur_addr_row(CONV_3_2_affect_neur_addr_row),
    .affect_neur_addr_col(CONV_3_2_affect_neur_addr_col),
    .neur_addr_invalid(CONV_3_2_neur_addr_invalid),
    .filter_phase(CONV_3_2_filter_phase),
    .en_accum(CONV_3_2_en_accum),
    .en_activ(CONV_3_2_en_activ),
    .cumm_spks(CONV_3_2_cumm_spks),
    .total_layer_spks_in(CONV_3_2_input_spks),
    .total_layer_spks_out(CONV_3_2_input_spks)
    );

 generate
    for (genvar i=0; i<CONV_3_2_EC_SIZE; i=i+1) begin : gen_6
    conv_nc #(
        .NEURON_OFFSET(i),
        .IN_CHANNELS(CONV_3_2_INPUT_CHANNELS),
        .OUT_CHANNELS(CONV_3_2_OUTPUT_CHANNELS),
        .EC_SIZE(CONV_3_2_EC_SIZE),
        .KERNEL_SIZE(CONV_3_2_KERNEL_SIZE),
        .INPUT_FRAME_WIDTH(CONV_3_2_INPUT_FRAME_WIDTH),
        .OUTPUT_FRAME_WIDTH(CONV_3_2_OUTPUT_FRAME_WIDTH),
        .BRAM_ADDR_WIDTH(CONV_3_2_POT_BRAM_ADDR_WIDTH),
        .w_sfactor(`w_sfactor_3_2),
        .b_sfactor(`b_sfactor_3_2),
        .w_zpt(`w_zpt_3_2),
        .b_zpt(`b_zpt_3_2),
        .WEIGHT_FILENAME($sformatf("%s/weights/conv3_2_nc%0d.txt", model_dir, i))
    ) CONV_3_2_nc_i (
        .clk(clk), .rst(rst),
        .en_accum(CONV_3_2_en_accum),
        .en_activ(CONV_3_2_en_activ),
        .ic(CONV_3_2_channel),
        .oc_phase(CONV_3_2_oc_phase),
        .filter_phase(CONV_3_2_filter_phase),
        .affect_neur_addr_row(CONV_3_2_affect_neur_addr_row[i]),
        .affect_neur_addr_col(CONV_3_2_affect_neur_addr_col[i]),
        .neur_addr_invalid(CONV_3_2_neur_addr_invalid),
        .last_time_step(CONV_3_2_last_time_step), // Add this line
        .ic_done(CONV_3_2_ic_done), // Add this line
        .post_syn_spk(CONV_3_2_post_syn_spk[i]),
        .bram_rdat(CONV_3_2_pot_bram_rdat[i]),
        .bram_raddr(CONV_3_2_pot_bram_raddr[i]),
        .bram_ren(CONV_3_2_pot_bram_ren[i]),
        .bram_wrdat(CONV_3_2_pot_bram_wrdat[i]),
        .bram_wraddr(CONV_3_2_pot_bram_wraddr[i]),
        .bram_wren(CONV_3_2_pot_bram_wren[i])
    );

    (* DONT_TOUCH = "yes" *)
    bram_pot #(
        .RAM_DEPTH(CONV_3_2_OUTPUT_FRAME_SIZE))
    CONV_3_2_pot_ram (
        .clk(clk), .rst(rst),
        .rdat(CONV_3_2_pot_bram_rdat[i]),
        .raddr(CONV_3_2_pot_bram_raddr[i]),
        .ren(CONV_3_2_pot_bram_ren[i]),
        .wrdat(CONV_3_2_pot_bram_wrdat[i]),
        .wraddr(CONV_3_2_pot_bram_wraddr[i]),
        .wren(CONV_3_2_pot_bram_wren[i])
    );
    end
 endgenerate

  (* DONT_TOUCH = "yes" *)
  bram_spk #(
    .RAM_DEPTH(CONV_3_2_SPK_BRAM_DEPTH), 
    .RAM_WIDTH(CONV_3_2_OUTPUT_FRAME_SIZE))
 CONV_3_2_spk_ram (
    .clk(clk), .rst(rst),
    .rdat(CONV_3_2_spk_bram_rdat),
    .raddr(CONV_3_2_spk_bram_raddr),
    .ren(CONV_3_2_spk_bram_ren),
    .wrdat(CONV_3_2_spk_bram_wrdat), 
    .wraddr(CONV_3_2_spk_bram_wraddr), 
    .wren(CONV_3_2_spk_bram_wren)
 );



  logic [1:0] CONV_3_2_state, CONV_3_2_state_nxt;
  logic [CONV_3_2_EC_SIZE-1:0] CONV_3_2_nc_iter, CONV_3_2_nc_iter_nxt;

  always_ff @(posedge clk) begin
    CONV_3_2_state <= CONV_3_2_state_nxt;
    CONV_3_2_nc_iter <= CONV_3_2_nc_iter_nxt;
    CONV_3_2_spk_bram_wraddr <= CONV_3_2_spk_bram_wraddr_nxt;
    CONV_3_2_spk_bram_wrdat <= CONV_3_2_spk_bram_wrdat_nxt;
    CONV_3_2_spk_bram_wren <= CONV_3_2_spk_bram_wren_nxt;
  end
  
  always_comb begin
    if(rst) begin
        CONV_3_2_state_nxt = 0;
        CONV_3_2_nc_iter_nxt = 0;
        CONV_3_2_spk_bram_wraddr_nxt = 0;
        CONV_3_2_spk_bram_wrdat_nxt = 0;
        CONV_3_2_spk_bram_wren_nxt = 0;
    end else begin 
        CONV_3_2_state_nxt = CONV_3_2_state;
        CONV_3_2_nc_iter_nxt = CONV_3_2_nc_iter;
        CONV_3_2_spk_bram_wraddr_nxt = CONV_3_2_spk_bram_wraddr;
        CONV_3_2_spk_bram_wrdat_nxt = CONV_3_2_spk_bram_wrdat;
        CONV_3_2_spk_bram_wren_nxt = CONV_3_2_spk_bram_wren;
        case(CONV_3_2_state)
            0: begin
                if(CONV_3_2_new_spk_train) CONV_3_2_state_nxt = 1;
            end
            1:begin
                CONV_3_2_spk_bram_wraddr_nxt = (CONV_3_2_time_step_out_spikes)*CONV_3_2_OUTPUT_CHANNELS + CONV_3_2_oc_phase_shifted*CONV_3_2_EC_SIZE + CONV_3_2_nc_iter;
                CONV_3_2_spk_bram_wrdat_nxt = CONV_3_2_post_syn_spk[CONV_3_2_nc_iter];
                
                CONV_3_2_spk_bram_wren_nxt = 1;
                CONV_3_2_nc_iter_nxt = CONV_3_2_nc_iter + 1;
                CONV_3_2_state_nxt = 2;
            end
            2: begin
                CONV_3_2_state_nxt = 3;
            end
            3: begin
                CONV_3_2_spk_bram_wren_nxt = 0;
                if(CONV_3_2_nc_iter == CONV_3_2_EC_SIZE) begin
                    CONV_3_2_state_nxt = 0;
                    CONV_3_2_nc_iter_nxt = 0;
                end else CONV_3_2_state_nxt = 1;
            end
        endcase
    end  
  end




  localparam CONV_3_3_INPUT_CHANNELS = CONV_3_2_OUTPUT_CHANNELS;
  localparam CONV_3_3_OUTPUT_CHANNELS = USER_SET_CONV_3_3_SIZE; // Change this as per your design
  localparam CONV_3_3_KERNEL_SIZE = 3; // Change this as per your design
  localparam CONV_3_3_INPUT_FRAME_WIDTH = CONV_3_2_OUTPUT_FRAME_WIDTH;
  localparam CONV_3_3_INPUT_FRAME_SIZE = CONV_3_3_INPUT_FRAME_WIDTH*CONV_3_3_INPUT_FRAME_WIDTH;
  localparam CONV_3_3_OUTPUT_FRAME_WIDTH = CONV_3_3_INPUT_FRAME_WIDTH;
  localparam CONV_3_3_OUTPUT_FRAME_SIZE = CONV_3_3_OUTPUT_FRAME_WIDTH * CONV_3_3_OUTPUT_FRAME_WIDTH;
  localparam CONV_3_3_OUTPUT_FRAME_SIZE_MP = CONV_3_3_OUTPUT_FRAME_SIZE/16;
  localparam CONV_3_3_EC_SIZE = USER_SET_CONV_3_3_EC_SIZE; // Change this as per your design
  localparam CONV_3_3_SPARSE_SIZE = CONV_3_3_INPUT_FRAME_SIZE>>1;
  localparam CONV_3_3_PENC_SIZE = CONV_3_3_INPUT_FRAME_SIZE>>2;
  localparam CONV_3_3_POT_BRAM_ADDR_WIDTH = $clog2(CONV_3_3_OUTPUT_FRAME_SIZE); 
  localparam CONV_3_3_SPK_BRAM_DEPTH = TIME_STEPS * CONV_3_3_OUTPUT_CHANNELS;


  logic [CONV_3_3_OUTPUT_FRAME_SIZE_MP-1:0] CONV_3_3_spk_bram_wrdat, CONV_3_3_spk_bram_wrdat_nxt;
  logic [$clog2(CONV_3_3_SPK_BRAM_DEPTH)-1:0] CONV_3_3_spk_bram_wraddr, CONV_3_3_spk_bram_wraddr_nxt;
  logic CONV_3_3_spk_bram_wren, CONV_3_3_spk_bram_wren_nxt;
  logic [CONV_3_3_OUTPUT_FRAME_SIZE_MP-1:0] CONV_3_3_spk_bram_rdat;
  logic [$clog2(CONV_3_3_SPK_BRAM_DEPTH)-1:0] CONV_3_3_spk_bram_raddr;
  logic CONV_3_3_spk_bram_ren;
  logic [$clog2(CONV_3_3_INPUT_FRAME_WIDTH)-1:0] CONV_3_3_affect_neur_addr_row[CONV_3_3_EC_SIZE-1:0], CONV_3_3_affect_neur_addr_col[CONV_3_3_EC_SIZE-1:0];
  logic [$clog2(CONV_3_3_INPUT_CHANNELS)+1:0] CONV_3_3_channel;
  logic [$clog2(TIME_STEPS):0] CONV_3_3_time_step_out_spikes, CONV_3_3_time_step_in_spikes;
  logic CONV_3_3_neur_addr_invalid;
  assign CONV_3_2_spk_bram_raddr = CONV_3_3_channel +  CONV_3_3_time_step_in_spikes*CONV_3_2_OUTPUT_CHANNELS;
  
  int CONV_3_3_input_spks = 0;
  logic [$clog2(8*CONV_3_3_SPARSE_SIZE)-1:0] CONV_3_3_cumm_spks;

  logic CONV_3_3_en_accum, CONV_3_3_en_activ;
  logic CONV_3_3_ram_clk;

  `ifdef SIM
  shortreal CONV_3_3_pot_bram_rdat [CONV_3_3_EC_SIZE-1:0];
  shortreal CONV_3_3_pot_bram_wrdat [CONV_3_3_EC_SIZE-1:0];
  `else
  logic [31:0] CONV_3_3_pot_bram_rdat [CONV_3_3_EC_SIZE-1:0];
  logic [31:0] CONV_3_3_pot_bram_wrdat [CONV_3_3_EC_SIZE-1:0];
  `endif

  logic [CONV_3_3_POT_BRAM_ADDR_WIDTH-1:0] CONV_3_3_pot_bram_raddr [CONV_3_3_EC_SIZE-1:0], CONV_3_3_pot_bram_wraddr [CONV_3_3_EC_SIZE-1:0];
  logic CONV_3_3_pot_bram_ren [CONV_3_3_EC_SIZE-1:0], CONV_3_3_pot_bram_wren [CONV_3_3_EC_SIZE-1:0];
  logic [CONV_3_3_OUTPUT_FRAME_SIZE-1:0] CONV_3_3_post_syn_spk [CONV_3_3_EC_SIZE-1:0]; 
  logic [CONV_3_3_OUTPUT_FRAME_SIZE/4-1:0] CONV_3_3_post_syn_spk_ored [CONV_3_3_EC_SIZE-1:0]; 
  logic [$clog2(CONV_3_3_KERNEL_SIZE)+1:0] CONV_3_3_filter_phase;
  logic CONV_3_3_new_spk_train, CONV_3_3_last_time_step, CONV_3_3_ic_done;
  logic [$clog2(CONV_3_3_OUTPUT_CHANNELS)+1:0] CONV_3_3_oc_phase, CONV_3_3_oc_phase_shifted;

    (* DONT_TOUCH = "yes" *)
    conv_ec 
    #(.TIME_STEPS(TIME_STEPS),
    .INPUT_CHANNELS(CONV_3_3_INPUT_CHANNELS),
    .OUTPUT_CHANNELS(CONV_3_3_OUTPUT_CHANNELS),
    .KERNEL_SIZE(CONV_3_3_KERNEL_SIZE),
    .INPUT_FRAME_WIDTH(CONV_3_3_INPUT_FRAME_WIDTH),
    .INPUT_FRAME_SIZE(CONV_3_3_INPUT_FRAME_SIZE),
    .OUTPUT_FRAME_WIDTH(CONV_3_3_OUTPUT_FRAME_WIDTH),
    .OUTPUT_FRAME_SIZE(CONV_3_3_OUTPUT_FRAME_SIZE),
    .EC_SIZE(CONV_3_3_EC_SIZE),
    .SPARSE_SIZE(CONV_3_3_SPARSE_SIZE), 
    .PENC_SIZE(CONV_3_3_PENC_SIZE))
    CONV_3_3_ec (
    .clk(clk), .rst(rst),
    .pre_syn_RAM_loaded(CONV_3_2_spk_RAM_loaded), // Connect to output of CONV_3_2 layer
    .post_syn_RAM_loaded(CONV_3_3_spk_RAM_loaded),
    .new_spk_train_ready(CONV_3_3_new_spk_train),
    .last_time_step(CONV_3_3_last_time_step), // Add this line
    .ic_done(CONV_3_3_ic_done), // Add this line
    .spk_in_train(CONV_3_2_spk_bram_rdat),
    .spk_in_ram_en(CONV_3_2_spk_bram_ren),
    .ic(CONV_3_3_channel),
    .oc_phase(CONV_3_3_oc_phase),
    .oc_phase_shift(CONV_3_3_oc_phase_shifted),
    .time_step_out_spikes(CONV_3_3_time_step_out_spikes),
    .time_step_in_spikes(CONV_3_3_time_step_in_spikes),
    .affect_neur_addr_row(CONV_3_3_affect_neur_addr_row),
    .affect_neur_addr_col(CONV_3_3_affect_neur_addr_col),
    .neur_addr_invalid(CONV_3_3_neur_addr_invalid),
    .filter_phase(CONV_3_3_filter_phase),
    .en_accum(CONV_3_3_en_accum),
    .en_activ(CONV_3_3_en_activ),
    .total_layer_spks_in(CONV_3_3_input_spks),
    .cumm_spks(CONV_3_3_cumm_spks),
    .total_layer_spks_out(CONV_3_3_input_spks)
    );

 generate
    for (genvar i=0; i<CONV_3_3_EC_SIZE; i=i+1) begin : gen_7
    conv_nc #(
        .NEURON_OFFSET(i),
        .IN_CHANNELS(CONV_3_3_INPUT_CHANNELS),
        .OUT_CHANNELS(CONV_3_3_OUTPUT_CHANNELS),
        .EC_SIZE(CONV_3_3_EC_SIZE),
        .KERNEL_SIZE(CONV_3_3_KERNEL_SIZE),
        .INPUT_FRAME_WIDTH(CONV_3_3_INPUT_FRAME_WIDTH),
        .OUTPUT_FRAME_WIDTH(CONV_3_3_OUTPUT_FRAME_WIDTH),
        .BRAM_ADDR_WIDTH(CONV_3_3_POT_BRAM_ADDR_WIDTH),
        .w_sfactor(`w_sfactor_3_3),
        .b_sfactor(`b_sfactor_3_3),
        .w_zpt(`w_zpt_3_3),
        .b_zpt(`b_zpt_3_3),
        .WEIGHT_FILENAME($sformatf("%s/weights/conv3_3_nc%0d.txt", model_dir, i))
    ) CONV_3_3_nc_i (
        .clk(clk), .rst(rst),
        .en_accum(CONV_3_3_en_accum),
        .en_activ(CONV_3_3_en_activ),
        .ic(CONV_3_3_channel),
        .oc_phase(CONV_3_3_oc_phase),
        .filter_phase(CONV_3_3_filter_phase),
        .affect_neur_addr_row(CONV_3_3_affect_neur_addr_row[i]),
        .affect_neur_addr_col(CONV_3_3_affect_neur_addr_col[i]),
        .neur_addr_invalid(CONV_3_3_neur_addr_invalid),
        .last_time_step(CONV_3_3_last_time_step), // Add this line
        .ic_done(CONV_3_3_ic_done), // Add this line
        .post_syn_spk(CONV_3_3_post_syn_spk[i]),
        .bram_rdat(CONV_3_3_pot_bram_rdat[i]),
        .bram_raddr(CONV_3_3_pot_bram_raddr[i]),
        .bram_ren(CONV_3_3_pot_bram_ren[i]),
        .bram_wrdat(CONV_3_3_pot_bram_wrdat[i]),
        .bram_wraddr(CONV_3_3_pot_bram_wraddr[i]),
        .bram_wren(CONV_3_3_pot_bram_wren[i])
    );

    (* DONT_TOUCH = "yes" *)
    bram_pot #(
        .RAM_DEPTH(CONV_3_3_OUTPUT_FRAME_SIZE))
    CONV_3_3_pot_ram (
        .clk(clk), .rst(rst),
        .rdat(CONV_3_3_pot_bram_rdat[i]),
        .raddr(CONV_3_3_pot_bram_raddr[i]),
        .ren(CONV_3_3_pot_bram_ren[i]),
        .wrdat(CONV_3_3_pot_bram_wrdat[i]),
        .wraddr(CONV_3_3_pot_bram_wraddr[i]),
        .wren(CONV_3_3_pot_bram_wren[i])
    );
    end
 endgenerate

  (* DONT_TOUCH = "yes" *)
  bram_spk #(
    .RAM_DEPTH(CONV_3_3_SPK_BRAM_DEPTH), 
    .RAM_WIDTH(CONV_3_3_OUTPUT_FRAME_SIZE_MP))
 CONV_3_3_spk_ram (
    .clk(clk), .rst(rst),
    .rdat(CONV_3_3_spk_bram_rdat),
    .raddr(CONV_3_3_spk_bram_raddr),
    .ren(CONV_3_3_spk_bram_ren),
    .wrdat(CONV_3_3_spk_bram_wrdat), 
    .wraddr(CONV_3_3_spk_bram_wraddr), 
    .wren(CONV_3_3_spk_bram_wren)
 );



  logic [1:0] CONV_3_3_state, CONV_3_3_state_nxt;
  logic [CONV_3_3_EC_SIZE-1:0] CONV_3_3_nc_iter, CONV_3_3_nc_iter_nxt;

  always_ff @(posedge clk) begin
    CONV_3_3_state <= CONV_3_3_state_nxt;
    CONV_3_3_nc_iter <= CONV_3_3_nc_iter_nxt;
    CONV_3_3_spk_bram_wraddr <= CONV_3_3_spk_bram_wraddr_nxt;
    CONV_3_3_spk_bram_wrdat <= CONV_3_3_spk_bram_wrdat_nxt;
    CONV_3_3_spk_bram_wren <= CONV_3_3_spk_bram_wren_nxt;
  end
  
  always_comb begin
    if(rst) begin
        CONV_3_3_state_nxt = 0;
        CONV_3_3_nc_iter_nxt = 0;
        CONV_3_3_spk_bram_wraddr_nxt = 0;
        CONV_3_3_spk_bram_wrdat_nxt = 0;
        CONV_3_3_spk_bram_wren_nxt = 0;
    end else begin 
        CONV_3_3_state_nxt = CONV_3_3_state;
        CONV_3_3_nc_iter_nxt = CONV_3_3_nc_iter;
        CONV_3_3_spk_bram_wraddr_nxt = CONV_3_3_spk_bram_wraddr;
        CONV_3_3_spk_bram_wrdat_nxt = CONV_3_3_spk_bram_wrdat;
        CONV_3_3_spk_bram_wren_nxt = CONV_3_3_spk_bram_wren;
        case(CONV_3_3_state)
            0: begin
                if(CONV_3_3_new_spk_train) CONV_3_3_state_nxt = 1;
            end
            1: begin
                CONV_3_3_spk_bram_wraddr_nxt = (CONV_3_3_time_step_out_spikes)*CONV_3_3_OUTPUT_CHANNELS + CONV_3_3_oc_phase_shifted*CONV_3_3_EC_SIZE + CONV_3_3_nc_iter;
                //CONV_3_3_spk_bram_wrdat_nxt = CONV_3_3_post_syn_spk[CONV_3_3_nc_iter];
                for (int j = 0; j < CONV_3_3_OUTPUT_FRAME_SIZE_MP; j++) begin // assuming 2x2 maxpool
                   CONV_3_3_spk_bram_wrdat_nxt[j] = CONV_3_3_post_syn_spk[CONV_3_3_nc_iter][16*j] 
                                                 | CONV_3_3_post_syn_spk[CONV_3_3_nc_iter][16*j + 1] 
                                                 | CONV_3_3_post_syn_spk[CONV_3_3_nc_iter][16*j + 2] 
                                                 | CONV_3_3_post_syn_spk[CONV_3_3_nc_iter][16*j + 3]
                                                 | CONV_3_3_post_syn_spk[CONV_3_3_nc_iter][16*j + 4] 
                                                 | CONV_3_3_post_syn_spk[CONV_3_3_nc_iter][16*j + 5] 
                                                 | CONV_3_3_post_syn_spk[CONV_3_3_nc_iter][16*j + 6] 
                                                 | CONV_3_3_post_syn_spk[CONV_3_3_nc_iter][16*j + 7]
                                                 | CONV_3_3_post_syn_spk[CONV_3_3_nc_iter][16*j + 8] 
                                                 | CONV_3_3_post_syn_spk[CONV_3_3_nc_iter][16*j + 9] 
                                                 | CONV_3_3_post_syn_spk[CONV_3_3_nc_iter][16*j + 10] 
                                                 | CONV_3_3_post_syn_spk[CONV_3_3_nc_iter][16*j + 11]
                                                 | CONV_3_3_post_syn_spk[CONV_3_3_nc_iter][16*j + 12] 
                                                 | CONV_3_3_post_syn_spk[CONV_3_3_nc_iter][16*j + 13] 
                                                 | CONV_3_3_post_syn_spk[CONV_3_3_nc_iter][16*j + 14] 
                                                 | CONV_3_3_post_syn_spk[CONV_3_3_nc_iter][16*j + 15];
                end
                
                CONV_3_3_spk_bram_wren_nxt = 1;
                CONV_3_3_nc_iter_nxt = CONV_3_3_nc_iter + 1;
                CONV_3_3_state_nxt = 2;
            end
            2: begin
                CONV_3_3_state_nxt = 3;
            end
            3: begin
                CONV_3_3_spk_bram_wren_nxt = 0;
                if(CONV_3_3_nc_iter == CONV_3_3_EC_SIZE) begin
                    CONV_3_3_state_nxt = 0;
                    CONV_3_3_nc_iter_nxt = 0;
                end else CONV_3_3_state_nxt = 1;
            end
        endcase
    end  
  end



    localparam FC1_INPUT_CHANNELS = CONV_3_3_OUTPUT_CHANNELS;
    localparam FC1_INPUT_FRAME_SIZE = CONV_3_3_OUTPUT_FRAME_SIZE_MP;
    localparam FC1_LAYER_SIZE = USER_SET_FC_1_SIZE; 
    localparam FC1_EC_SIZE = USER_SET_FC_1_EC_SIZE;
    localparam FC1_PENC_SIZE = 200;
    localparam FC1_BRAM_DEPTH = FC1_INPUT_CHANNELS*FC1_INPUT_FRAME_SIZE*FC1_LAYER_SIZE/FC1_EC_SIZE;
    localparam FC1_BRAM_ADDR_WIDTH = $clog2(FC1_BRAM_DEPTH);

    logic [FC1_LAYER_SIZE-1:0] fc1_spk_set [TIME_STEPS-1:0];
    logic fc_1_spk_RAM_loaded;
    logic [FC1_LAYER_SIZE-1:0] fc_1_spk_bram_rdat;
    logic [$clog2(TIME_STEPS)+1:0] fc1_time_step, fc1_time_step1;
    logic [$clog2(FC1_LAYER_SIZE)-1:0] fc1_neuron; // ?
    logic [$clog2(FC1_INPUT_CHANNELS*FC1_INPUT_FRAME_SIZE)-1:0] fc1_spk_addr;
    logic [$clog2(FC1_INPUT_CHANNELS)-1:0] fc1_channel;
    logic fc1_last_time_step;
    
    logic [$clog2(FC1_INPUT_FRAME_SIZE*FC1_INPUT_CHANNELS):0] fc1_total_spks [TIME_STEPS-1:0];
    
    shortreal fc_1_bram_rdat[FC1_EC_SIZE-1:0];
    shortreal fc_1_bram_wrdat[FC1_EC_SIZE-1:0];
    logic [FC1_BRAM_ADDR_WIDTH-1:0] fc_1_bram_raddr[FC1_EC_SIZE-1:0];
    logic [FC1_BRAM_ADDR_WIDTH-1:0] fc_1_bram_wraddr[FC1_EC_SIZE-1:0];
    logic fc_1_bram_ren[FC1_EC_SIZE-1:0];
    logic fc_1_bram_wren[FC1_EC_SIZE-1:0];
    logic fc1_new_spk_train;
    logic [FC1_EC_SIZE-1:0] fc1_post_syn_spk;

    (* DONT_TOUCH = "yes" *)
    fc_ec
    #(.TIME_STEPS(TIME_STEPS),
      .EC_SIZE(FC1_EC_SIZE),
      .INPUT_CHANNELS(FC1_INPUT_CHANNELS),
      .INPUT_FRAME_SIZE(FC1_INPUT_FRAME_SIZE),
      .LAYER_SIZE(FC1_LAYER_SIZE),
      .PENC_SIZE(FC1_PENC_SIZE))
    fc_1( 
        .clk(clk), .rst(rst), 
        .pre_syn_RAM_loaded(CONV_3_3_spk_RAM_loaded),
        .post_syn_RAM_loaded(fc_1_spk_RAM_loaded), 
        .spk_in_train(CONV_3_3_spk_bram_rdat), 
        .spk_in_ram_en(CONV_3_3_spk_bram_ren),
        .ic(fc1_channel), .last_time_step(fc1_last_time_step),
        .penc_time_step(fc1_time_step),
        .spk_time_step(fc1_time_step1),
        .en_accum(fc1_en_accum), .en_activ(fc1_en_activ),
        .spk_addr(fc1_spk_addr), .neuron(fc1_neuron),
        .new_spk_train_ready(fc1_new_spk_train),
        .total_spks_out(fc1_total_spks)
        );

        generate
            for (genvar i=0; i<FC1_EC_SIZE; i=i+1) begin : fc_1_block
                fc_nc #(
                    .NEURON_OFFSET(i), 
                    .IN_CHANNELS(FC1_INPUT_CHANNELS),
                    .INPUT_FRAME_SIZE(FC1_INPUT_FRAME_SIZE),
                    .LAYER_SIZE(FC1_LAYER_SIZE),
                    .w_sfactor(`w_sfactor_fc1),
                    .b_sfactor(`b_sfactor_fc1),
                    .w_zpt(`w_zpt_fc1),
                    .b_zpt(`b_zpt_fc1),
                    .BRAM_ADDR_WIDTH(FC1_BRAM_ADDR_WIDTH))
                fc1_nc_i (
                    .clk(clk), .rst(rst),
                    .en_accum(fc1_en_accum),
                    .en_activ(fc1_en_activ),
                    .last_time_step(fc1_last_time_step),
                    .spk_addr(fc1_spk_addr), .neuron(fc1_neuron),
                    .post_syn_spk(fc1_post_syn_spk[i]),
                    .bram_rdat(fc_1_bram_rdat[i]),
                    .bram_raddr(fc_1_bram_raddr[i]),
                    .bram_ren(fc_1_bram_ren[i])
                );

                (* DONT_TOUCH = "yes" *)
                bram_wght #(
                    .RAM_DEPTH(FC1_BRAM_DEPTH),
                    .IN_CHANNELS(FC1_INPUT_CHANNELS),
                    .FILENAME($sformatf("%s/weights/fc1_nc%0d.txt", model_dir, i)))
                fc1_wght_ram_i (
                    .clk(clk), .rst(rst),
                    .rdat(fc_1_bram_rdat[i]),
                    .raddr(fc_1_bram_raddr[i]),
                    .ren(fc_1_bram_ren[i])
                );
            end
        endgenerate

        logic [1:0] fc1_state;
        logic [FC1_EC_SIZE-1:0] fc1_nc_iter;
        always_ff @(posedge clk) begin
            if(rst) begin
                fc1_nc_iter <= 0;
                fc1_state <= 0;
            end else begin
                case(fc1_state)
                    0: begin
                        fc1_nc_iter <= 0;
                        if(fc1_new_spk_train) fc1_state <= 1;
                    end
                    1:begin
                        fc1_spk_set[fc1_time_step1][fc1_neuron+fc1_nc_iter] <= fc1_post_syn_spk[fc1_nc_iter];
                        fc1_nc_iter <= fc1_nc_iter + 1;
                        fc1_state <= 2;
                    end
                    2: begin
                        if(fc1_nc_iter == FC1_EC_SIZE) fc1_state <= 0;
                        else fc1_state <= 1;
                    end
                endcase
            end
        end
        assign CONV_3_3_spk_bram_raddr = fc1_channel +  fc1_time_step*CONV_3_3_OUTPUT_CHANNELS;



    localparam FC2_INPUT_CHANNELS = 1;
    localparam FC2_INPUT_FRAME_SIZE = FC1_LAYER_SIZE;
    localparam FC2_LAYER_SIZE = USER_SET_FC_2_SIZE;
    localparam FC2_EC_SIZE = USER_SET_FC_2_EC_SIZE;
    localparam FC2_PENC_SIZE = 200;
    localparam FC2_BRAM_DEPTH = FC2_LAYER_SIZE*FC2_INPUT_CHANNELS*FC2_INPUT_FRAME_SIZE;
    localparam FC2_BRAM_ADDR_WIDTH = $clog2(FC2_BRAM_DEPTH);

    logic [FC2_LAYER_SIZE-1:0] fc2_spk_set [TIME_STEPS-1:0];
    logic fc_2_spk_RAM_loaded;
    logic [FC2_LAYER_SIZE-1:0] fc_2_spk_bram_rdat;
    logic [$clog2(TIME_STEPS)+1:0] fc2_time_step, fc2_time_step1;
    logic [$clog2(FC2_LAYER_SIZE)-1:0] fc2_neuron;
    logic [$clog2(FC2_INPUT_CHANNELS*FC2_INPUT_FRAME_SIZE)-1:0] fc2_spk_addr;
    logic [$clog2(FC2_INPUT_CHANNELS)+1:0] fc2_channel;
    logic fc2_last_time_step;
    
    logic [$clog2(FC2_INPUT_FRAME_SIZE*FC2_INPUT_CHANNELS):0] fc2_total_spks [TIME_STEPS-1:0];

    `ifdef SIM
        shortreal fc_2_bram_rdat[FC2_EC_SIZE-1:0];
    `else
        logic [31:0] fc_2_bram_rdat[FC2_EC_SIZE-1:0];
    `endif

    logic [FC2_BRAM_ADDR_WIDTH-1:0] fc_2_bram_addr[FC2_EC_SIZE-1:0];
    logic fc_2_bram_en[FC2_EC_SIZE-1:0];
    logic fc2_new_spk_train;
    logic [FC2_EC_SIZE-1:0] fc2_post_syn_spk;

    (* DONT_TOUCH = "yes" *)
    fc_ec
    #(.TIME_STEPS(TIME_STEPS),
      .EC_SIZE(FC2_EC_SIZE),
      .INPUT_CHANNELS(FC2_INPUT_CHANNELS),
      .INPUT_FRAME_SIZE(FC2_INPUT_FRAME_SIZE),
      .LAYER_SIZE(FC2_LAYER_SIZE),
      .PENC_SIZE(FC2_PENC_SIZE))
      fc_2(
        .clk(clk), .rst(rst),
        .pre_syn_RAM_loaded(fc_1_spk_RAM_loaded),
        .post_syn_RAM_loaded(fc_2_spk_RAM_loaded),
        .spk_in_train(fc1_spk_set[fc2_time_step]),
        .spk_in_ram_en(fc_1_spk_bram_ren),
        .ic(fc2_channel),
        .penc_time_step(fc2_time_step),
        .spk_time_step(fc2_time_step1),
        .en_accum(fc2_en_accum), .en_activ(fc2_en_activ),
        .spk_addr(fc2_spk_addr),
        .neuron(fc2_neuron),
        .new_spk_train_ready(fc2_new_spk_train),
        .last_time_step(fc2_last_time_step),
        .total_spks_out(fc2_total_spks)
      );

        generate
            for (genvar i=0; i<FC2_EC_SIZE; i=i+1) begin : fc_2_block
                fc_nc #(
                    .NEURON_OFFSET(i), 
                    .IN_CHANNELS(FC2_INPUT_CHANNELS),
                    .INPUT_FRAME_SIZE(FC2_INPUT_FRAME_SIZE),
                    .LAYER_SIZE(FC2_LAYER_SIZE),
                    .w_sfactor(`w_sfactor_fc2),
                    .b_sfactor(`b_sfactor_fc2),
                    .w_zpt(`w_zpt_fc2),
                    .b_zpt(`b_zpt_fc2),
                    .BRAM_ADDR_WIDTH(FC2_BRAM_ADDR_WIDTH))
                fc2_nc_i (
                    .clk(clk), .rst(rst),
                    .en_accum(fc2_en_accum),
                    .en_activ(fc2_en_activ),
                    .last_time_step(fc2_last_time_step),
                    .spk_addr(fc2_spk_addr), .neuron(fc2_neuron),
                    .post_syn_spk(fc2_post_syn_spk[i]),
                    .bram_rdat(fc_2_bram_rdat[i]),
                    .bram_raddr(fc_2_bram_addr[i]),
                    .bram_ren(fc_2_bram_en[i])
                );

                (* DONT_TOUCH = "yes" *)
                bram_wght #(
                    .RAM_DEPTH(FC2_BRAM_DEPTH),
                    .FILENAME($sformatf("%s/weights/fc2_nc%0d.txt", model_dir, i)))
                fc2_wght_ram_i (
                    .clk(clk), .rst(rst),
                    .rdat(fc_2_bram_rdat[i]),
                    .raddr(fc_2_bram_addr[i]),
                    .ren(fc_2_bram_en[i])
                );
            end
        endgenerate

        always_ff @(posedge clk) begin
            if (fc2_new_spk_train == 1) begin
                for (int i = 0; i < FC2_EC_SIZE; i++) begin
                    fc2_spk_set[fc2_time_step][fc2_neuron+i] <= fc2_post_syn_spk[i];
                end
            end else begin
                for (int i = 0; i < FC2_EC_SIZE; i++) begin
                    fc2_spk_set[fc2_time_step][fc2_neuron+i] <= 0;
                end
            end
        end
    
    
    
    // Write the input spike count of layers to spikes and c.txt 
    int cycl_spk_txt, cycl_spk_txt_state, cycl_spk_txt_state_next;
    int FC1_input_spks_sum = 0, FC2_input_spks_sum = 0;
    
    always_ff @(posedge clk) begin
        cycl_spk_txt_state <= cycl_spk_txt_state_next;
    end
    
    
    always_comb begin
        if (rst) begin
            cycl_spk_txt_state_next = 0;
        end else begin
            cycl_spk_txt_state_next = cycl_spk_txt_state;
            
            case(cycl_spk_txt_state)
                0: begin
                    if (CONV_1_1_spk_RAM_loaded) begin
                        cycl_spk_txt = $fopen({`model_directory, "/cycles and spikes.txt"}, "w");
                        
                        if (cycl_spk_txt) begin
                            $display("cycles and spikes.txt was opened successfully");
                            $fdisplay(cycl_spk_txt, "%.0f", $time/20);
                            cycl_spk_txt_state_next = 1;
                        end else begin
                            $display("spikes.txt could not be opened");
                            cycl_spk_txt_state_next = 3;
                        end
                    end 
                end
                1: begin
                    if (CONV_1_2_spk_RAM_loaded) begin
                        $fdisplay(cycl_spk_txt, "%.0f", $time/20);
                    end
                    else if (CONV_2_1_spk_RAM_loaded) begin
                        $fdisplay(cycl_spk_txt, "%.0f", $time/20);
                    end
                    else if (CONV_2_2_spk_RAM_loaded) begin
                        $fdisplay(cycl_spk_txt, "%.0f", $time/20);
                    end
                    else if (CONV_3_1_spk_RAM_loaded) begin
                        $fdisplay(cycl_spk_txt, "%.0f", $time/20);
                    end
                    else if (CONV_3_2_spk_RAM_loaded) begin
                        $fdisplay(cycl_spk_txt, "%.0f", $time/20);
                    end
                    else if (CONV_3_3_spk_RAM_loaded) begin
                        $fdisplay(cycl_spk_txt, "%.0f", $time/20);
                    end
                    else if (fc_1_spk_RAM_loaded) begin
                        $fdisplay(cycl_spk_txt, "%.0f", $time/20);
                        cycl_spk_txt_state_next = 2;
                    end
                end
                2: begin
                    if (fc_2_spk_RAM_loaded) begin
                        $fdisplay(cycl_spk_txt, "%.0f\n", $time/20);
                        
                        $fdisplay(cycl_spk_txt, "%0d", CONV_1_2_input_spks);
                        $fdisplay(cycl_spk_txt, "%0d", CONV_2_1_input_spks);
                        $fdisplay(cycl_spk_txt, "%0d", CONV_2_2_input_spks);
                        $fdisplay(cycl_spk_txt, "%0d", CONV_3_1_input_spks);
                        $fdisplay(cycl_spk_txt, "%0d", CONV_3_2_input_spks);
                        $fdisplay(cycl_spk_txt, "%0d", CONV_3_3_input_spks);
                        
                        for (int i = 0; i < TIME_STEPS-1; i++) FC1_input_spks_sum += fc1_total_spks[i];
                        $fdisplay(cycl_spk_txt, "%0d", FC1_input_spks_sum);
                        
                        for (int i = 0; i < TIME_STEPS-1; i++) FC2_input_spks_sum += fc2_total_spks[i];
                        $fdisplay(cycl_spk_txt, "%0d", FC2_input_spks_sum);
                        cycl_spk_txt_state_next = 3;
                    end
                end
                3: begin
                    $fclose(cycl_spk_txt);
                    $display("cycles and spikes.txt has been closed");
                end
            endcase
        end
    end

endmodule
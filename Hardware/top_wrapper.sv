`include "C:/Users/Ilkin/vivado_projects/hw_design_params.svh"

module top_wrapper #(
    parameter TIME_STEPS = 2,
    parameter CONV_1_INPUT_CHANNELS = 1,
    parameter CONV_1_OUTPUT_CHANNELS = 32,
    parameter CONV_1_KERNEL_SIZE = 3,
    parameter CONV_1_INPUT_FRAME_WIDTH = 32,
    parameter CONV_1_INPUT_FRAME_SIZE = CONV_1_INPUT_FRAME_WIDTH*CONV_1_INPUT_FRAME_WIDTH,
    parameter model_dir = "C:/Users/Ilkin/vivado_projects/model/model_params"
) (
    input clk, rst,
    input input_avail,
    output logic conv_1_avail
);

parameter USER_SET_CONV_2_SIZE = 32;
parameter USER_SET_FC_1_SIZE = 256;
parameter USER_SET_FC_2_SIZE = 450;

parameter USER_SET_CONV_1_EC_SIZE = 32;
parameter USER_SET_CONV_2_EC_SIZE = 32;
parameter USER_SET_FC_1_EC_SIZE = 8;
parameter USER_SET_FC_2_EC_SIZE = 8;

logic input_ram_clk, conv_1_nc_clk, conv_2_nc_clk, conv_1_spk_clk, conv_2_spk_clk;

/***************************************** CONV_1 params ***********************************************/  
  localparam CONV_1_OUTPUT_FRAME_WIDTH = CONV_1_INPUT_FRAME_WIDTH - CONV_1_KERNEL_SIZE + 1;
  localparam CONV_1_OUTPUT_FRAME_SIZE = CONV_1_OUTPUT_FRAME_WIDTH * CONV_1_OUTPUT_FRAME_WIDTH;
  localparam CONV_1_OUTPUT_FRAME_SIZE_MP = CONV_1_OUTPUT_FRAME_SIZE/4;
  localparam CONV_1_EC_SIZE = USER_SET_CONV_1_EC_SIZE; //`EC_1;
  localparam CONV_1_SPARSE_SIZE = CONV_1_INPUT_FRAME_SIZE>>1;
  localparam CONV_1_PENC_SIZE = CONV_1_INPUT_FRAME_SIZE>>2;
  localparam CONV_1_POT_BRAM_ADDR_WIDTH = $clog2(CONV_1_OUTPUT_FRAME_SIZE); 
  localparam CONV_1_SPK_BRAM_DEPTH = TIME_STEPS * CONV_1_OUTPUT_CHANNELS;
  localparam INPUT_SPK_BRAM_DEPTH = TIME_STEPS * CONV_1_INPUT_CHANNELS;
/***************************************** CONV_1 params ***********************************************/  

/***************************************** INPUT layer ***********************************************/    
 (* DONT_TOUCH = "yes" *)
  bram_spk #(
    .RAM_DEPTH(INPUT_SPK_BRAM_DEPTH), 
    .RAM_WIDTH(CONV_1_INPUT_FRAME_SIZE), 
    .FILENAME($sformatf({model_dir, "/spk_in.txt"})))
 input_spk_ram (
    .clk(clk), .rst(rst),
    .rdat(input_spk_bram_rdat),
    .raddr(input_spk_bram_raddr),
    .ren(input_spk_bram_ren),
    .wrdat(0), .wraddr(0), .wren(0)
 );
/***************************************** INPUT layer ***********************************************/  

/***************************************** CONV_1 layer ***********************************************/  
    logic [$clog2(INPUT_SPK_BRAM_DEPTH):0] input_spk_bram_raddr;
    logic [$clog2(TIME_STEPS)-1:0] conv_1_time_step, conv_1_curr_time_step;
    logic [CONV_1_INPUT_FRAME_SIZE-1:0] input_spk_bram_rdat;
    logic input_spk_bram_ren;
    logic [CONV_1_OUTPUT_FRAME_SIZE_MP-1:0] conv_1_spk_bram_wrdat, conv_1_spk_bram_wrdat_nxt;
    logic [$clog2(CONV_1_SPK_BRAM_DEPTH):0] conv_1_spk_bram_wraddr, conv_1_spk_bram_wraddr_nxt;
    logic conv_1_spk_bram_wren, conv_1_spk_bram_wren_nxt;
    logic [CONV_1_OUTPUT_FRAME_SIZE_MP-1:0] conv_1_spk_bram_rdat;
    logic [$clog2(CONV_1_SPK_BRAM_DEPTH)-1:0] conv_1_spk_bram_raddr;
    logic conv_1_spk_bram_ren;
    logic [$clog2(CONV_1_INPUT_FRAME_WIDTH)-1:0] conv_1_affect_neur_addr_y[CONV_1_EC_SIZE-1:0], conv_1_affect_neur_addr_x[CONV_1_EC_SIZE-1:0];
    logic [$clog2(CONV_1_INPUT_CHANNELS)+1:0] conv_1_channel;
    logic conv_1_neur_addr_invalid, conv_1_last_time_step, conv_1_ic_done;
    assign input_spk_bram_raddr = conv_1_channel +  conv_1_time_step;
  
  logic conv_1_en_accum, conv_1_en_activ;
  logic conv_1_ram_clk;

  `ifdef SIM
  shortreal conv_1_pot_bram_rdat [CONV_1_EC_SIZE-1:0];
  shortreal conv_1_pot_bram_wrdat [CONV_1_EC_SIZE-1:0];
  `else
  logic [31:0] conv_1_pot_bram_rdat [CONV_1_EC_SIZE-1:0];
  logic [31:0] conv_1_pot_bram_wrdat [CONV_1_EC_SIZE-1:0];
  `endif
  
  logic [CONV_1_POT_BRAM_ADDR_WIDTH-1:0] conv_1_pot_bram_raddr [CONV_1_EC_SIZE-1:0], conv_1_pot_bram_wraddr [CONV_1_EC_SIZE-1:0];
  logic conv_1_pot_bram_ren [CONV_1_EC_SIZE-1:0], conv_1_pot_bram_wren [CONV_1_EC_SIZE-1:0];
  logic [CONV_1_OUTPUT_FRAME_SIZE-1:0] conv_1_post_syn_spk [CONV_1_EC_SIZE-1:0]; 
  logic [$clog2(CONV_1_KERNEL_SIZE)+1:0] conv_1_filter_phase;
  logic conv_1_new_spk_train;
  logic [$clog2(CONV_1_OUTPUT_CHANNELS)+1:0] conv_1_oc_phase;

  (* DONT_TOUCH = "yes" *)
  conv_ec 
  #(.TIME_STEPS(TIME_STEPS),
    .INPUT_CHANNELS(CONV_1_INPUT_CHANNELS),
    .OUTPUT_CHANNELS(CONV_1_OUTPUT_CHANNELS),
    .KERNEL_SIZE(CONV_1_KERNEL_SIZE),
    .INPUT_FRAME_WIDTH(CONV_1_INPUT_FRAME_WIDTH),
    .INPUT_FRAME_SIZE(CONV_1_INPUT_FRAME_SIZE),
    .OUTPUT_FRAME_WIDTH(CONV_1_OUTPUT_FRAME_WIDTH),
    .OUTPUT_FRAME_SIZE(CONV_1_OUTPUT_FRAME_SIZE),
    .EC_SIZE(CONV_1_EC_SIZE),
    .SPARSE_SIZE(CONV_1_SPARSE_SIZE), 
    .PENC_SIZE(CONV_1_PENC_SIZE))
  conv_1_ec (
    .clk(clk), .rst(rst),
    .pre_syn_RAM_loaded(input_avail),
    .post_syn_RAM_loaded(conv_1_spk_RAM_loaded),
    .new_spk_train_ready(conv_1_new_spk_train),
    .last_time_step(conv_1_last_time_step),
    .ic_done(conv_1_ic_done),
    .spk_in_train(input_spk_bram_rdat),
    .spk_in_ram_en(input_spk_bram_ren),
    .ic(conv_1_channel),
    .oc_phase(conv_1_oc_phase),
    .curr_time_step(conv_1_curr_time_step),
    .time_step(conv_1_time_step),
    .affect_neur_addr_y(conv_1_affect_neur_addr_y),
    .affect_neur_addr_x(conv_1_affect_neur_addr_x),
    .neur_addr_invalid(conv_1_neur_addr_invalid),
    .filter_phase(conv_1_filter_phase),
    .en_accum(conv_1_en_accum),
    .en_activ(conv_1_en_activ)
  );

 generate
    for (genvar i=0; i<CONV_1_EC_SIZE; i=i+1) begin : gen_1
    conv_nc #(
        .NEURON_OFFSET(i),
        .IN_CHANNELS(CONV_1_INPUT_CHANNELS),
        .OUT_CHANNELS(CONV_1_OUTPUT_CHANNELS),
        .EC_SIZE(CONV_1_EC_SIZE),
        .KERNEL_SIZE(CONV_1_KERNEL_SIZE),
        .INPUT_FRAME_WIDTH(CONV_1_INPUT_FRAME_WIDTH),
        .OUTPUT_FRAME_WIDTH(CONV_1_OUTPUT_FRAME_WIDTH),
        .BRAM_ADDR_WIDTH(CONV_1_POT_BRAM_ADDR_WIDTH),
        .WEIGHT_FILENAME($sformatf("%s/weights/conv1_nc%0d.txt", model_dir, i))
    ) conv_1_nc_i (
        .clk(clk), .rst(rst),
        .en_accum(conv_1_en_accum),
        .en_activ(conv_1_en_activ),
        .last_time_step(conv_1_last_time_step),
        .ic_done(conv_1_ic_done),
        .oc_phase(conv_1_oc_phase),
        .ic(conv_1_channel),
        .filter_phase(conv_1_filter_phase),
        .affect_neur_addr_y(conv_1_affect_neur_addr_y[i]),
        .affect_neur_addr_x(conv_1_affect_neur_addr_x[i]),
        .neur_addr_invalid(conv_1_neur_addr_invalid),
        .post_syn_spk(conv_1_post_syn_spk[i]),
        .bram_rdat(conv_1_pot_bram_rdat[i]),
        .bram_raddr(conv_1_pot_bram_raddr[i]),
        .bram_ren(conv_1_pot_bram_ren[i]),
        .bram_wrdat(conv_1_pot_bram_wrdat[i]),
        .bram_wraddr(conv_1_pot_bram_wraddr[i]),
        .bram_wren(conv_1_pot_bram_wren[i])
    );

    (* DONT_TOUCH = "yes" *)
    bram_pot #(
        .RAM_DEPTH(CONV_1_OUTPUT_FRAME_SIZE))
    conv_1_pot_ram (
        .clk(clk), .rst(rst),
        .rdat(conv_1_pot_bram_rdat[i]),
        .raddr(conv_1_pot_bram_raddr[i]),
        .ren(conv_1_pot_bram_ren[i]),
        .wrdat(conv_1_pot_bram_wrdat[i]),
        .wraddr(conv_1_pot_bram_wraddr[i]),
        .wren(conv_1_pot_bram_wren[i])
    );
    end
 endgenerate

  (* DONT_TOUCH = "yes" *)
  bram_spk #(
    .RAM_DEPTH(CONV_1_SPK_BRAM_DEPTH), 
    .RAM_WIDTH(CONV_1_OUTPUT_FRAME_SIZE_MP))
 conv_1_spk_ram (
    .clk(clk), .rst(rst),
    .rdat(conv_1_spk_bram_rdat),
    .raddr(conv_1_spk_bram_raddr),
    .ren(conv_1_spk_bram_ren),
    .wrdat(conv_1_spk_bram_wrdat), 
    .wraddr(conv_1_spk_bram_wraddr), 
    .wren(conv_1_spk_bram_wren)
 );
/***************************************** CONV_1 layer ***********************************************/  

/*************************************** CONV_1 Spike R/W & MP ********************************************/  
  logic [1:0] conv_1_state, conv_1_state_nxt;
  logic [CONV_1_EC_SIZE-1:0] conv_1_nc_iter, conv_1_nc_iter_nxt;

  always_ff @(posedge clk) begin
    conv_1_state <= conv_1_state_nxt;
    conv_1_nc_iter <= conv_1_nc_iter_nxt;
    conv_1_spk_bram_wraddr <= conv_1_spk_bram_wraddr_nxt;
    conv_1_spk_bram_wrdat <= conv_1_spk_bram_wrdat_nxt;
    conv_1_spk_bram_wren <= conv_1_spk_bram_wren_nxt;
  end
  
  always_comb begin
    if(rst) begin
        conv_1_state_nxt = 0;
        conv_1_nc_iter_nxt = 0;
        conv_1_spk_bram_wraddr_nxt = 0;
        conv_1_spk_bram_wrdat_nxt = 0;
        conv_1_spk_bram_wren_nxt = 0;
    end else begin 
        conv_1_state_nxt = conv_1_state;
        conv_1_nc_iter_nxt = conv_1_nc_iter;
        conv_1_spk_bram_wraddr_nxt = conv_1_spk_bram_wraddr;
        conv_1_spk_bram_wrdat_nxt = conv_1_spk_bram_wrdat;
        conv_1_spk_bram_wren_nxt = conv_1_spk_bram_wren;
        case(conv_1_state)
            0: begin
                if(conv_1_new_spk_train) conv_1_state_nxt = 1;
            end
            1:begin
                conv_1_spk_bram_wraddr_nxt = (conv_1_curr_time_step-1)*CONV_1_OUTPUT_CHANNELS + conv_1_oc_phase*CONV_1_EC_SIZE + conv_1_nc_iter;
                for (int j = 0; j < CONV_1_OUTPUT_FRAME_SIZE_MP; j++) begin // assuming 2x2 maxpool
                    conv_1_spk_bram_wrdat_nxt[j] = conv_1_post_syn_spk[conv_1_nc_iter][4*j] 
                                                    | conv_1_post_syn_spk[conv_1_nc_iter][4*j + 1] 
                                                    | conv_1_post_syn_spk[conv_1_nc_iter][4*j + 2] 
                                                    | conv_1_post_syn_spk[conv_1_nc_iter][4*j + 3];
                end
                conv_1_spk_bram_wren_nxt = 1;
                conv_1_nc_iter_nxt = conv_1_nc_iter + 1;
                conv_1_state_nxt = 2;
            end
            2: begin
                conv_1_state_nxt = 3;
            end
            3: begin
                conv_1_spk_bram_wren_nxt = 0;
                if(conv_1_nc_iter == CONV_1_EC_SIZE) begin
                    conv_1_state_nxt = 0;
                    conv_1_nc_iter_nxt = 0;
                end else conv_1_state_nxt = 1;
            end
        endcase
    end  
  end
/*************************************** CONV_1 Spike R/W & MP ********************************************/  

/***************************************** CONV_2 params ***********************************************/  
  localparam CONV_2_INPUT_CHANNELS = CONV_1_OUTPUT_CHANNELS;
  localparam CONV_2_OUTPUT_CHANNELS = USER_SET_CONV_2_SIZE; // Change this as per your design
  localparam CONV_2_KERNEL_SIZE = 3; // Change this as per your design
  localparam CONV_2_INPUT_FRAME_WIDTH = CONV_1_OUTPUT_FRAME_WIDTH/2; // maxpooling 2x2
  localparam CONV_2_INPUT_FRAME_SIZE = CONV_2_INPUT_FRAME_WIDTH*CONV_2_INPUT_FRAME_WIDTH;
  localparam CONV_2_OUTPUT_FRAME_WIDTH = CONV_2_INPUT_FRAME_WIDTH - CONV_2_KERNEL_SIZE + 1;
  localparam CONV_2_OUTPUT_FRAME_SIZE = CONV_2_OUTPUT_FRAME_WIDTH * CONV_2_OUTPUT_FRAME_WIDTH;
  localparam CONV_2_OUTPUT_FRAME_SIZE_MP = CONV_2_OUTPUT_FRAME_SIZE/4;
  localparam CONV_2_EC_SIZE = USER_SET_CONV_2_EC_SIZE; // Change this as per your design
  localparam CONV_2_SPARSE_SIZE = CONV_2_INPUT_FRAME_SIZE>>1;
  localparam CONV_2_PENC_SIZE = CONV_2_INPUT_FRAME_SIZE>>2;
  localparam CONV_2_POT_BRAM_ADDR_WIDTH = $clog2(CONV_2_OUTPUT_FRAME_SIZE); 
  localparam CONV_2_SPK_BRAM_DEPTH = TIME_STEPS * CONV_1_OUTPUT_CHANNELS;
/***************************************** CONV_2 params ***********************************************/  

/***************************************** CONV_2 layer ***********************************************/  
  logic [CONV_2_OUTPUT_FRAME_SIZE-1:0] conv_2_spk_bram_wrdat, conv_2_spk_bram_wrdat_nxt;
  logic [$clog2(CONV_2_SPK_BRAM_DEPTH):0] conv_2_spk_bram_wraddr, conv_2_spk_bram_wraddr_nxt;
  logic conv_2_spk_bram_wren, conv_2_spk_bram_wren_nxt;
  logic [CONV_2_OUTPUT_FRAME_SIZE-1:0] conv_2_spk_bram_rdat;
  logic [$clog2(CONV_2_SPK_BRAM_DEPTH)-1:0] conv_2_spk_bram_raddr;
  logic conv_2_spk_bram_ren;
  logic [$clog2(CONV_2_INPUT_FRAME_WIDTH)-1:0] conv_2_affect_neur_addr_y[CONV_2_EC_SIZE-1:0], conv_2_affect_neur_addr_x[CONV_2_EC_SIZE-1:0];
  logic [$clog2(CONV_2_INPUT_CHANNELS)+1:0] conv_2_channel;
  logic [$clog2(TIME_STEPS)-1:0] conv_2_time_step, conv_2_curr_time_step;
  logic conv_2_neur_addr_invalid;
  assign conv_1_spk_bram_raddr = conv_2_channel +  conv_2_time_step;

  logic conv_2_en_accum, conv_2_en_activ;
  logic conv_2_ram_clk;

  `ifdef SIM
  shortreal conv_2_pot_bram_rdat [CONV_2_EC_SIZE-1:0];
  shortreal conv_2_pot_bram_wrdat [CONV_2_EC_SIZE-1:0];
  `else
  logic [31:0] conv_2_pot_bram_rdat [CONV_2_EC_SIZE-1:0];
  logic [31:0] conv_2_pot_bram_wrdat [CONV_2_EC_SIZE-1:0];
  `endif

  logic [CONV_2_POT_BRAM_ADDR_WIDTH-1:0] conv_2_pot_bram_raddr [CONV_2_EC_SIZE-1:0], conv_2_pot_bram_wraddr [CONV_2_EC_SIZE-1:0];
  logic conv_2_pot_bram_ren [CONV_2_EC_SIZE-1:0], conv_2_pot_bram_wren [CONV_2_EC_SIZE-1:0];
  logic [CONV_2_OUTPUT_FRAME_SIZE-1:0] conv_2_post_syn_spk [CONV_2_EC_SIZE-1:0]; 
  logic [CONV_2_OUTPUT_FRAME_SIZE/4-1:0] conv_2_post_syn_spk_ored [CONV_2_EC_SIZE-1:0]; 
  logic [$clog2(CONV_2_KERNEL_SIZE)+1:0] conv_2_filter_phase;
  logic conv_2_new_spk_train, conv_2_last_time_step, conv_2_ic_done;
  logic [$clog2(CONV_2_OUTPUT_CHANNELS)+1:0] conv_2_oc_phase;

    (* DONT_TOUCH = "yes" *)
    conv_ec 
    #(.TIME_STEPS(TIME_STEPS),
    .INPUT_CHANNELS(CONV_2_INPUT_CHANNELS),
    .OUTPUT_CHANNELS(CONV_2_OUTPUT_CHANNELS),
    .KERNEL_SIZE(CONV_2_KERNEL_SIZE),
    .INPUT_FRAME_WIDTH(CONV_2_INPUT_FRAME_WIDTH),
    .INPUT_FRAME_SIZE(CONV_2_INPUT_FRAME_SIZE),
    .OUTPUT_FRAME_WIDTH(CONV_2_OUTPUT_FRAME_WIDTH),
    .OUTPUT_FRAME_SIZE(CONV_2_OUTPUT_FRAME_SIZE),
    .EC_SIZE(CONV_2_EC_SIZE),
    .SPARSE_SIZE(CONV_2_SPARSE_SIZE), 
    .PENC_SIZE(CONV_2_PENC_SIZE))
    conv_2_ec (
    .clk(clk), .rst(rst),
    .pre_syn_RAM_loaded(conv_1_spk_RAM_loaded), // Connect to output of CONV_1 layer
    .post_syn_RAM_loaded(conv_2_spk_RAM_loaded),
    .new_spk_train_ready(conv_2_new_spk_train),
    .last_time_step(conv_2_last_time_step), // Add this line
    .ic_done(conv_2_ic_done), // Add this line
    .spk_in_train(conv_1_spk_bram_rdat),
    .spk_in_ram_en(conv_1_spk_bram_ren),
    .ic(conv_2_channel),
    .oc_phase(conv_2_oc_phase),
    .curr_time_step(conv_2_time_step),
    .time_step(conv_2_curr_time_step),
    .affect_neur_addr_y(conv_2_affect_neur_addr_y),
    .affect_neur_addr_x(conv_2_affect_neur_addr_x),
    .neur_addr_invalid(conv_2_neur_addr_invalid),
    .filter_phase(conv_2_filter_phase),
    .en_accum(conv_2_en_accum),
    .en_activ(conv_2_en_activ)
    );

 generate
    for (genvar i=0; i<CONV_2_EC_SIZE; i=i+1) begin : gen_2
    conv_nc #(
        .NEURON_OFFSET(i),
        .IN_CHANNELS(CONV_2_INPUT_CHANNELS),
        .OUT_CHANNELS(CONV_2_OUTPUT_CHANNELS),
        .KERNEL_SIZE(CONV_2_KERNEL_SIZE),
        .INPUT_FRAME_WIDTH(CONV_2_INPUT_FRAME_WIDTH),
        .OUTPUT_FRAME_WIDTH(CONV_2_OUTPUT_FRAME_WIDTH),
        .BRAM_ADDR_WIDTH(CONV_2_POT_BRAM_ADDR_WIDTH),
        .WEIGHT_FILENAME($sformatf("%s/weights/conv2_nc%0d.txt", model_dir, i))
    ) conv_2_nc_i (
        .clk(clk), .rst(rst),
        .en_accum(conv_2_en_accum),
        .en_activ(conv_2_en_activ),
        .ic(conv_2_channel),
        .oc_phase(conv_2_oc_phase),
        .filter_phase(conv_2_filter_phase),
        .affect_neur_addr_y(conv_2_affect_neur_addr_y[i]),
        .affect_neur_addr_x(conv_2_affect_neur_addr_x[i]),
        .neur_addr_invalid(conv_2_neur_addr_invalid),
        .last_time_step(conv_2_last_time_step), // Add this line
        .ic_done(conv_2_ic_done), // Add this line
        .post_syn_spk(conv_2_post_syn_spk[i]),
        .bram_rdat(conv_2_pot_bram_rdat[i]),
        .bram_raddr(conv_2_pot_bram_raddr[i]),
        .bram_ren(conv_2_pot_bram_ren[i]),
        .bram_wrdat(conv_2_pot_bram_wrdat[i]),
        .bram_wraddr(conv_2_pot_bram_wraddr[i]),
        .bram_wren(conv_2_pot_bram_wren[i])
    );

    (* DONT_TOUCH = "yes" *)
    bram_pot #(
        .RAM_DEPTH(CONV_2_OUTPUT_FRAME_SIZE))
    conv_2_pot_ram (
        .clk(clk), .rst(rst),
        .rdat(conv_2_pot_bram_rdat[i]),
        .raddr(conv_2_pot_bram_raddr[i]),
        .ren(conv_2_pot_bram_ren[i]),
        .wrdat(conv_2_pot_bram_wrdat[i]),
        .wraddr(conv_2_pot_bram_wraddr[i]),
        .wren(conv_2_pot_bram_wren[i])
    );
    end
 endgenerate

  (* DONT_TOUCH = "yes" *)
  bram_spk #(
    .RAM_DEPTH(CONV_2_SPK_BRAM_DEPTH), 
    .RAM_WIDTH(CONV_2_OUTPUT_FRAME_SIZE))
 conv_2_spk_ram (
    .clk(clk), .rst(rst),
    .rdat(conv_2_spk_bram_rdat),
    .raddr(conv_2_spk_bram_raddr),
    .ren(conv_2_spk_bram_ren),
    .wrdat(conv_2_spk_bram_wrdat), 
    .wraddr(conv_2_spk_bram_wraddr), 
    .wren(conv_2_spk_bram_wren)
 );
/***************************************** CONV_2 layer ***********************************************/  

/***************************************** CONV_2 Spike R/W ***********************************************/  
  logic [1:0] conv_2_state, conv_2_state_nxt;
  logic [CONV_2_EC_SIZE-1:0] conv_2_nc_iter, conv_2_nc_iter_nxt;

  always_ff @(posedge clk) begin
    conv_2_state <= conv_2_state_nxt;
    conv_2_nc_iter <= conv_2_nc_iter_nxt;
    conv_2_spk_bram_wraddr <= conv_2_spk_bram_wraddr_nxt;
    conv_2_spk_bram_wrdat <= conv_2_spk_bram_wrdat_nxt;
    conv_2_spk_bram_wren <= conv_2_spk_bram_wren_nxt;
  end
  
  always_comb begin
    if(rst) begin
        conv_2_state_nxt = 0;
        conv_2_nc_iter_nxt = 0;
        conv_2_spk_bram_wraddr_nxt = 0;
        conv_2_spk_bram_wrdat_nxt = 0;
        conv_2_spk_bram_wren_nxt = 0;
    end else begin 
        conv_2_state_nxt = conv_2_state;
        conv_2_nc_iter_nxt = conv_2_nc_iter;
        conv_2_spk_bram_wraddr_nxt = conv_2_spk_bram_wraddr;
        conv_2_spk_bram_wrdat_nxt = conv_2_spk_bram_wrdat;
        conv_2_spk_bram_wren_nxt = conv_2_spk_bram_wren;
        case(conv_2_state)
            0: begin
                if(conv_2_new_spk_train) conv_2_state_nxt = 1;
            end
            1:begin
                conv_2_spk_bram_wraddr_nxt = (conv_2_curr_time_step-1)*CONV_2_OUTPUT_CHANNELS + conv_2_oc_phase*CONV_2_EC_SIZE + conv_2_nc_iter;
                conv_2_spk_bram_wrdat_nxt = conv_2_post_syn_spk[conv_2_nc_iter];
                for (int j = 0; j < CONV_2_OUTPUT_FRAME_SIZE_MP; j++) begin // assuming 2x2 maxpool
                   conv_2_spk_bram_wrdat_nxt[j] = conv_2_post_syn_spk[conv_2_nc_iter][4*j] 
                                                 | conv_2_post_syn_spk[conv_2_nc_iter][4*j + 1] 
                                                 | conv_2_post_syn_spk[conv_2_nc_iter][4*j + 2] 
                                                 | conv_2_post_syn_spk[conv_2_nc_iter][4*j + 3];
                end
                conv_2_spk_bram_wren_nxt = 1;
                conv_2_nc_iter_nxt = conv_2_nc_iter + 1;
                conv_2_state_nxt = 2;
            end
            2: begin
                conv_2_state_nxt = 3;
            end
            3: begin
                conv_2_spk_bram_wren_nxt = 0;
                if(conv_2_nc_iter == CONV_2_EC_SIZE) begin
                    conv_2_state_nxt = 0;
                    conv_2_nc_iter_nxt = 0;
                end else conv_2_state_nxt = 1;
            end
        endcase
    end  
  end
/***************************************** CONV_2 Spike R/W ***********************************************/  

/***************************************** FC_1 layer ***********************************************/
    localparam FC1_INPUT_CHANNELS = CONV_2_OUTPUT_CHANNELS;
    localparam FC1_INPUT_FRAME_SIZE = CONV_2_OUTPUT_FRAME_SIZE_MP;
    localparam FC1_LAYER_SIZE = USER_SET_FC_1_SIZE; 
    localparam FC1_EC_SIZE = USER_SET_FC_1_EC_SIZE;
    localparam FC1_PENC_SIZE = 150;
    localparam FC1_BRAM_DEPTH = FC1_INPUT_CHANNELS*FC1_INPUT_FRAME_SIZE*FC1_LAYER_SIZE/FC1_EC_SIZE;
    localparam FC1_BRAM_ADDR_WIDTH = $clog2(FC1_BRAM_DEPTH);

    logic [FC1_LAYER_SIZE-1:0] fc1_spk_set [TIME_STEPS-1:0];
    logic fc_1_spk_RAM_loaded;
    logic [FC1_LAYER_SIZE-1:0] fc_1_spk_bram_rdat;
    logic [$clog2(TIME_STEPS)+1:0] fc1_time_step, fc1_time_step1;
    logic [$clog2(FC1_LAYER_SIZE)+1:0] fc1_neuron;
    logic [$clog2(FC1_INPUT_FRAME_SIZE):0] fc1_spk_addr;
    logic [$clog2(FC1_INPUT_CHANNELS)+1:0] fc1_channel;
    logic fc1_last_time_step;

    `ifdef SIM
     shortreal fc_1_bram_rdat[FC1_EC_SIZE-1:0];
     shortreal fc_1_bram_wrdat[FC1_EC_SIZE-1:0];
    `else
     logic [31:0] fc_1_bram_rdat[FC1_EC_SIZE-1:0];
     logic [31:0] fc_1_bram_wrdat[FC1_EC_SIZE-1:0];
    `endif
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
        .pre_syn_RAM_loaded(conv_2_spk_RAM_loaded),
        .post_syn_RAM_loaded(fc_1_spk_RAM_loaded), 
        .spk_in_train(conv_2_spk_bram_rdat), 
        .spk_in_ram_en(conv_2_spk_bram_ren),
        .ic(fc1_channel), .last_time_step(fc1_last_time_step),
        .penc_time_step(fc1_time_step),
        .spk_time_step(fc1_time_step1),
        .en_accum(fc1_en_accum), .en_activ(fc1_en_activ),
        .spk_addr(fc1_spk_addr), .neuron(fc1_neuron),
        .new_spk_train_ready(fc1_new_spk_train)
        );

        generate
            for (genvar i=0; i<FC1_EC_SIZE; i=i+1) begin : fc_1_block
                fc_nc #(
                    .NEURON_OFFSET(i), 
                    .IN_CHANNELS(FC1_INPUT_CHANNELS),
                    .INPUT_FRAME_SIZE(FC1_INPUT_FRAME_SIZE),
                    .LAYER_SIZE(FC1_LAYER_SIZE),
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
                `ifdef SIM
                    bram_wght #(
                        .RAM_DEPTH(FC1_BRAM_DEPTH),
                        .FILENAME($sformatf({model_dir, "/weights/fc1_nc%0d.txt"}, i)))
                    fc1_wght_ram_i (
                        .clk(clk), .rst(rst),
                        .rdat(fc_1_bram_rdat[i]),
                        .raddr(fc_1_bram_raddr[i]),
                        .ren(fc_1_bram_ren[i]));
                 `else
                    uram_wght #(
                        .RAM_DEPTH(FC1_BRAM_DEPTH))
                    fc1_wght_ram_i (
                        .clk(clk), 
                        .rdat(fc_1_bram_rdat[i]),
                        .raddr(fc_1_bram_raddr[i]),
                        .ren(fc_1_bram_ren[i]),
                        .wraddr(fc_1_bram_wrdat[i]), 
                        .wrdat(fc_1_bram_wraddr[i]), 
                        .wren(fc_1_bram_wren[i]));
                  `endif
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
        assign conv_2_spk_bram_raddr = fc1_channel +  fc1_time_step;
/***************************************** FC_1 layer ***********************************************/

/***************************************** FC_2 layer ***********************************************/
    localparam FC2_INPUT_CHANNELS = 1;
    localparam FC2_INPUT_FRAME_SIZE = FC1_LAYER_SIZE;
    localparam FC2_LAYER_SIZE = USER_SET_FC_2_SIZE;
    localparam FC2_EC_SIZE = USER_SET_FC_2_EC_SIZE;
    localparam FC2_PENC_SIZE = 150;
    localparam FC2_BRAM_DEPTH = FC2_LAYER_SIZE*FC2_INPUT_CHANNELS*FC2_INPUT_FRAME_SIZE;
    localparam FC2_BRAM_ADDR_WIDTH = $clog2(FC2_BRAM_DEPTH);

    logic [FC2_LAYER_SIZE-1:0] fc2_spk_set [TIME_STEPS-1:0];
    logic fc_2_spk_RAM_loaded;
    logic [FC2_LAYER_SIZE-1:0] fc_2_spk_bram_rdat;
    logic [$clog2(TIME_STEPS)+1:0] fc2_time_step, fc2_time_step1;
    logic [$clog2(FC2_LAYER_SIZE)+1:0] fc2_neuron;
    logic [$clog2(FC2_INPUT_FRAME_SIZE):0] fc2_spk_addr;
    logic [$clog2(FC2_INPUT_CHANNELS)+1:0] fc2_channel;
    logic fc2_last_time_step;

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
        .spk_addr(fc2_spk_addr),
        .neuron(fc2_neuron),
        .new_spk_train_ready(fc2_new_spk_train),
        .last_time_step(fc2_last_time_step)
      );

        generate
            for (genvar i=0; i<FC2_EC_SIZE; i=i+1) begin : fc_2_block
                fc_nc #(
                    .NEURON_OFFSET(i), 
                    .IN_CHANNELS(FC2_INPUT_CHANNELS),
                    .INPUT_FRAME_SIZE(FC2_INPUT_FRAME_SIZE),
                    .LAYER_SIZE(FC2_LAYER_SIZE),
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
                    .FILENAME($sformatf({model_dir, "/weights/fc2_nc%0d.txt"}, i)))
                fc2_pot_ram_i (
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
/***************************************** FC_2 layer ***********************************************/

endmodule

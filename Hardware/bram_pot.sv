`timescale 1ns / 1ps

module bram_pot #(
    parameter RAM_DEPTH = 32, 
    parameter RAM_ADDR_WIDTH = $clog2(RAM_DEPTH), 
    parameter string FILENAME = "/sim_1/new/weight_file_0_3.txt"
)(
    input logic clk,
    input logic rst,
    input logic wren,
    `ifdef SIM
    input shortreal wrdat,
    output shortreal rdat,
    `else
    input logic [31:0] wrdat,
    output logic [31:0] rdat,
    `endif
    input logic [RAM_ADDR_WIDTH-1:0] wraddr,
    input logic [RAM_ADDR_WIDTH-1:0] raddr,
    input logic ren
);

  (* ram_style = "block" *)
  (* synthesis_primitive = "MEMORY_PRIMITIVE" *)
  (* implementation = "memory" *)
  (* mem_gen_type = "block" *)
  (* mem_style = "block_ram" *)

   shortreal data_ram [0:RAM_DEPTH-1];


  // Write Operation
  always_ff @(posedge clk) begin
    if (wren) begin
      data_ram[wraddr] <= wrdat;
    end
  end

  // Read Operation
  always_ff @(posedge clk) begin
    if (ren) begin
      rdat <= data_ram[raddr];
    end
  end

endmodule

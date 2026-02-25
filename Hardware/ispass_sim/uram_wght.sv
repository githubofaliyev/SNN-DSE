module uram_wght #( parameter RAM_DEPTH = 10485, 
                   parameter RAM_ADDR_WIDTH = $clog2(RAM_DEPTH))
(
  input  logic         clk,
  input  logic         ren,
  input  logic         wren,
  input  logic [RAM_ADDR_WIDTH-1:0]   raddr, wraddr,
  input  logic signed [63:0]  wrdat,
  output logic signed [63:0]  rdat
);

  (* ram_style = "ultra" *)
  (* synthesis_primitive = "URAM" *)
  (* implementation = "memory" *)
  (* mem_gen_type = "ultra_ram" *)
  (* mem_style = "ultra_ram" *)
  logic signed [63:0] data_ram [0:RAM_DEPTH-1];

  // Write data to URAM when wr_en is asserted
  always_ff @(posedge clk) begin
    if(wren) 
      data_ram[wraddr] <= wrdat;
  end

  // Read data from the URAM based on address
  always_ff @(posedge clk) begin
    if(ren)
      rdat <= data_ram[raddr];
  end

endmodule

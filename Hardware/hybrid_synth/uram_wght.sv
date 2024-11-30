module uram_wght #(
    parameter BIT_WIDTH = 31,
    parameter RAM_DEPTH = 32, 
    parameter RAM_ADDR_WIDTH = $clog2(RAM_DEPTH)
)(
    input logic clk0, clk1,
    input logic [RAM_ADDR_WIDTH-1:0] raddr, wraddr,
    output logic [BIT_WIDTH:0] rdat, wrdat,
    input logic ren, wren
);

  (* ram_style = "ultra" *)
  (* synthesis_primitive = "URAM" *)
  (* implementation = "memory" *)
  (* mem_gen_type = "ultra_ram" *)
  (* mem_style = "ultra_ram" *)

  logic [BIT_WIDTH:0] data_ram0 [0:RAM_DEPTH/2-1];
  logic [BIT_WIDTH:0] data_ram1 [0:RAM_DEPTH/2-1];

   // Write Operation
  always_ff @(posedge clk0) begin
    if (wren) begin
      data_ram0[wraddr] <= wrdat;
    end
  end
  always_ff @(posedge clk1) begin
    if (wren) begin
      data_ram1[wraddr] <= wrdat;
    end
  end

  // Read Operation
  always_ff @(posedge clk0) begin
    if (ren) begin
      rdat <= data_ram0[raddr];
    end
  end
  always_ff @(posedge clk1) begin
    if (ren) begin
      rdat <= data_ram1[raddr];
    end
  end  

endmodule

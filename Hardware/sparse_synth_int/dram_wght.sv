module dram_wght #(
    parameter BIT_WIDTH = 31,
    parameter RAM_DEPTH = 32, 
    parameter RAM_ADDR_WIDTH = $clog2(RAM_DEPTH)
)(
    input logic clk,
    input logic rst,
    input logic [RAM_ADDR_WIDTH-1:0] raddr, wraddr,
    output logic [BIT_WIDTH:0] rdat, wrdat,
    input logic ren, wren
);

  (* ram_style = "distributed" *) 
  logic [BIT_WIDTH:0] data_ram [0:RAM_DEPTH-1];
  
  // Read Operation
  always_ff @(posedge clk) begin
    if (ren) begin
      rdat <= data_ram[raddr];
    end
  end

endmodule


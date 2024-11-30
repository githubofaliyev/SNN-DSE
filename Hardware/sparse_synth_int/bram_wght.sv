module bram_wght #(
    parameter BIT_WIDTH = 31,
    parameter RAM_DEPTH = 32, 
    parameter RAM_ADDR_WIDTH = $clog2(RAM_DEPTH), 
    parameter string FILENAME = "/sim_1/new/weight_file_0_3.txt"
)(
    input logic clk0, clk1,
    input logic rst,
    input logic [RAM_ADDR_WIDTH-1:0] raddr, wraddr,
    output logic [BIT_WIDTH:0] rdat, wrdat,
    input logic ren, wren
);

  (* ram_style = "block" *)
  (* synthesis_primitive = "MEMORY_PRIMITIVE" *)
  (* implementation = "memory" *)
  (* mem_gen_type = "block" *)
  (* mem_style = "block_ram" *)

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

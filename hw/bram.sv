module my_bram #( parameter BRAM_DEPTH = 32, parameter string FILENAME = "/sim_1/new/weight_file_0_3.txt", 
                  parameter BRAM_ADDR_WIDTH = 10, parameter FIXED_POINT_WIDTH = 32)
(
  input  logic         clk,
  input logic bram_en,
  input  logic [BRAM_ADDR_WIDTH-1:0]   addr,
  output logic signed [FIXED_POINT_WIDTH-1:0]  data_out
);


  (* ram_style = "block" *)
  (* synthesis_primitive = "MEMORY_PRIMITIVE" *)
  (* implementation = "memory" *)
  (* mem_gen_type = "block" *)
  (* mem_style = "block_ram" *)
  
  logic signed [FIXED_POINT_WIDTH-1:0] my_bram [BRAM_DEPTH-1:0];
  
  // Initialize BRAM with weights from file
  initial begin
    $readmemb(FILENAME, my_bram);
  end
  
  // Read data from the BRAM based on address
  always_ff @(posedge clk) begin
    if(bram_en)
        data_out <= my_bram[addr];
  end

endmodule


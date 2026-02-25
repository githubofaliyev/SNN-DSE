module bram_wght #(
    parameter RAM_DEPTH = 32, 
    parameter RAM_ADDR_WIDTH = $clog2(RAM_DEPTH), 
    parameter string FILENAME = "/sim_1/new/weight_file_0_3.txt"
)(
    input logic clk,
    input logic rst,
    input logic [RAM_ADDR_WIDTH-1:0] raddr,
    output shortreal rdat,
    input logic ren
);

  (* ram_style = "block" *)
  (* synthesis_primitive = "MEMORY_PRIMITIVE" *)
  (* implementation = "memory" *)
  (* mem_gen_type = "block" *)
  (* mem_style = "block_ram" *)

  shortreal data_ram [0:RAM_DEPTH-1];


  integer file;
    shortreal temp;
    initial begin
        file = $fopen(FILENAME, "r");
        if (file) begin
            for (int i = 0; i < RAM_DEPTH; i++) begin
                $fscanf(file, "%f", temp);
                data_ram[i] = temp; // Assuming data_ram is declared to hold real values
            end
            $fclose(file);
        end else begin
            $display("Error opening file %s", FILENAME);
        end
    end

  // Read Operation
  always_ff @(posedge clk) begin
    if (ren) begin
      rdat <= data_ram[raddr];
    end
  end

endmodule

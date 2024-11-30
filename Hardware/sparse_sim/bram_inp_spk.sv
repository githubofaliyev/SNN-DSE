module bram_inp_spk #(
    parameter RAM_DEPTH = 32, 
    parameter RAM_WIDTH = 32, 
    parameter RAM_ADDR_WIDTH = $clog2(RAM_DEPTH), 
    parameter string FILENAME = "/sim_1/new/weight_file_0_3.txt"
)(
    input logic clk,
    input logic rst,
    input logic wren,
    input logic [RAM_WIDTH-1:0] wrdat,
    input logic [RAM_ADDR_WIDTH-1:0] wraddr,
    input logic [RAM_ADDR_WIDTH-1:0] raddr,
    input logic ren,
    output logic [RAM_WIDTH-1:0] rdat
);

  logic [RAM_WIDTH-1:0] data_ram [0:RAM_DEPTH-1];

  integer file;
    logic [RAM_WIDTH-1:0] temp;
    initial begin
        file = $fopen(FILENAME, "r");
        if (file) begin
            for (int i = 0; i < RAM_DEPTH; i++) begin
                $fscanf(file, "%b", temp);
                data_ram[i] = temp; // Assuming data_ram is declared to hold real values
            end
            $fclose(file);
        end else begin
            $display("Error opening file %s", FILENAME);
        end
    end


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
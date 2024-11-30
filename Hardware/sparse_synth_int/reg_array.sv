module reg_array #(
    parameter BIT_WIDTH = 31,
    parameter RAM_DEPTH = 32, 
    parameter RAM_ADDR_WIDTH = $clog2(RAM_DEPTH),
    parameter string FILENAME = "/sim_1/new/weight_file_0_3.txt"
)(
    input logic clk,
    input logic rst,
    input logic [RAM_ADDR_WIDTH-1:0] addr,
    input logic ren, wren,
    input logic [BIT_WIDTH:0] wrdat,
    output logic [BIT_WIDTH:0] rdat
 );

  logic [BIT_WIDTH:0] data_ram [0:RAM_DEPTH-1];
  
//  integer file;
//  logic [BIT_WIDTH-1:0] temp;
//  initial begin
//    file = $fopen(FILENAME, "r");
//    if (file) begin
//        for (int i = 0; i < RAM_DEPTH; i++) begin
//            $fscanf(file, "%b", temp);
//            data_ram[i] = temp; // Assuming data_ram is declared to hold real values
//        end
//        $fclose(file);
//    end
//  end
  
  assign rdat = (ren) ? data_ram[addr] : 0;

endmodule


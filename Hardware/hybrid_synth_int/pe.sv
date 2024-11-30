// clockwise: in0-> input left, in1-> input up
module pe #(parameter WEIGHT_SIZE = 1,
            parameter OUT_CHANNELS = 2,
            parameter BIT_WIDTH = 31,
            parameter w_sfactor = 1,
            parameter w_zpt = 0,
            parameter string WEIGHT_FILENAME = "weight_file_0_3.txt"
)
(
    input clk, rst, transit,
    input logic [31:0] in0, in1,
    input logic [$clog2(OUT_CHANNELS):0] oc_phase,
    output logic [31:0] out0, out1
);

    logic [BIT_WIDTH:0] weight_bias[WEIGHT_SIZE-1:0]; // weight and bias
    integer file;
    initial begin
        file = $fopen(WEIGHT_FILENAME, "r");
        if (file == 0) begin
            $display("Error: Opening file failed!");
        end else begin
            $display("Success: Opening file!");
            for (int i = 0; i < WEIGHT_SIZE; i++) begin
                $fscanf(file, "%b", weight_bias[i]);
            end
            $fclose(file);
        end
    end

    always_ff @(posedge clk)begin
        if(rst || transit) begin
            out0 <= 0;
            out1 <= 0;
        end else begin  
            out0 <= in0;
            //out1 <= in1 + ((weight_bias[oc_phase] - w_zpt)*w_sfactor) * in0; shift-add multipl assuming the factor number bit positions active like below
            out1 <= in1 + (weight_bias[oc_phase] - w_zpt<<30 + weight_bias[oc_phase]<<28 + weight_bias[oc_phase] - w_zpt<<24)* in0;
        end
    end
 
endmodule
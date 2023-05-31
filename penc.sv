 module penc (input [31:0] sparse_in, output [4:0] spk_addr, output done);
    always_comb begin
        done = 0;
        if(sparse_in[0]) spk_addr = 0;
        else if(sparse_in[1]) spk_addr = 1;
        else if(sparse_in[2]) spk_addr = 2;
        else if(sparse_in[3]) spk_addr = 3;
        else if(sparse_in[4]) spk_addr = 4;
        else if(sparse_in[5]) spk_addr = 5;
        else if(sparse_in[6]) spk_addr = 6;
        else if(sparse_in[7]) spk_addr = 7;
        else if(sparse_in[8]) spk_addr = 8;
        else if(sparse_in[9]) spk_addr = 9;
        else if(sparse_in[10]) spk_addr = 10;
        else if(sparse_in[11]) spk_addr = 11;
        else if(sparse_in[12]) spk_addr = 12;
        else if(sparse_in[13]) spk_addr = 13;
        else if(sparse_in[14]) spk_addr = 14;
        else if(sparse_in[15]) spk_addr = 15;
        else if(sparse_in[16]) spk_addr = 16;
        else if(sparse_in[17]) spk_addr = 17;
        else if(sparse_in[18]) spk_addr = 18;
        else if(sparse_in[19]) spk_addr = 19;
        else if(sparse_in[20]) spk_addr = 20;
        else if(sparse_in[21]) spk_addr = 21;
        else if(sparse_in[22]) spk_addr = 22;
        else if(sparse_in[23]) spk_addr = 23;
        else if(sparse_in[24]) spk_addr = 24;
        else if(sparse_in[25]) spk_addr = 25;
        else if(sparse_in[26]) spk_addr = 26;
        else if(sparse_in[27]) spk_addr = 27;
        else if(sparse_in[28]) spk_addr = 28;
        else if(sparse_in[29]) spk_addr = 29;
        else if(sparse_in[30]) spk_addr = 30;
        else if(sparse_in[31]) spk_addr = 31;
        else done = 1;
    end

 endmodule
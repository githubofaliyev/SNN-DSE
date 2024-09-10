#include <errno.h>
#include <iostream>
#include <cmath>
#include <fstream>
#include "defines.h"

int main(int argc, char *argv[]){
    std::string data; uint16_t idx=0; char ch; bool bias=false; size_t u_size;
    std::string wght_mem_file_name; size_t n_cntr=0; size_t file_no = 0;

    std::fstream ofc2[LAYER1_SIZE_LOGICAL+1];
    
    // parse fc2 data
    if(std::stoi(argv[1])){
        std::ifstream ifc2(FC2_RAW_FILE, std::ifstream::in);
        if (!ifc2.good()) std::cout << "Could not open fc2 raw file." << std::endl;
        while(ifc2>>data){
        u_size = L1_MEM_UNIT_SIZE;
        if(!data.find("[")) {
                if(bias){
                    ofc2[file_no-1].close();
                    ofc2[file_no].open(FC2_BIAS_FILE, std::ios::out);
                    file_no++;
                }
                else if((n_cntr%u_size) == 0){
                    if(file_no != 0) ofc2[file_no-1].close();
                    wght_mem_file_name = "input/weight_mem_L1_N"+std::to_string(file_no)+".txt";
                    ofc2[file_no].open(wght_mem_file_name, std::ios::out);
                    file_no = (n_cntr/u_size + 1);
                    ofc2[file_no-1]<<u_size*LAYER0_SIZE_LOGICAL<<std::endl;
                }
                n_cntr++;
                if(data.size()>2)
                    data.erase(0,1); // erase [ from [-5.8136e-02
                else
                    continue; // skip [
            }

            if(data.find(']') != std::string::npos) {
                if(data.size()>2)
                    data.erase(data.size()-1); 
                else
                    continue;
            }

            if(!data.find("bias")) {
                bias = true;
                continue;
            }

            ofc2[file_no-1]<<data<<std::endl;
        }
        ifc2.close(); ofc2[n_cntr-1].close(); n_cntr=0; file_no = 0; bias=false;
    }

    return 0;
}
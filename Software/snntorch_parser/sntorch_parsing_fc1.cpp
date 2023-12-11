#include <errno.h>
#include <iostream>
#include <cmath>
#include <fstream>
#include "defines.h"

int main(int argc, char *argv[]){
    std::string data; uint16_t idx=0; char ch; bool bias=false; size_t u_size;
    std::string wght_mem_file_name; size_t n_cntr=0; size_t file_no = 0;

    std::fstream ofc1[LAYER0_SIZE_LOGICAL+1]; 

    // parse fc1 data
    if(std::stoi(argv[1])){
        std::ifstream ifc1(FC1_RAW_FILE, std::ifstream::in); 
        if (!ifc1.good()) std::cout << "Could not open fc1 raw file." << std::endl;
        while(ifc1>>data){
            u_size = L0_MEM_UNIT_SIZE;
            if(!data.find("[")) {
                if(bias){
                    ofc1[file_no-1].close();
                    ofc1[file_no].open(FC1_BIAS_FILE, std::ios::out);
                    file_no++;
                }
                else if((n_cntr%u_size) == 0){
                    if(file_no != 0) ofc1[file_no-1].close();
                    wght_mem_file_name = "input/weight_mem_L0_N"+std::to_string(file_no)+".txt";
                    ofc1[file_no].open(wght_mem_file_name, std::ios::out);
                    file_no = (n_cntr/u_size + 1);
                    ofc1[file_no-1]<<u_size*INPUT_LAYER_SIZE<<std::endl;
                }
                    //std::cout<<"[o]file_no: "<<file_no<<", n_cntr: "<<n_cntr<<std::endl;
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

            ofc1[file_no-1]<<data<<std::endl;
        }
        ifc1.close(); ofc1[n_cntr-1].close(); n_cntr=0; file_no = 0; bias=false;
    }

    return 0;
}
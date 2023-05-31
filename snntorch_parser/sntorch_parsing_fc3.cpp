#include <errno.h>
#include <iostream>
#include <cmath>
#include <fstream>
#include "defines.h"

int main(int argc, char *argv[]){
    std::string data; uint16_t idx=0; char ch; bool bias=false; size_t u_size;
    std::string wght_mem_file_name; size_t n_cntr=0; size_t file_no = 0;

    std::fstream ofc3[LAYER2_SIZE_LOGICAL+1];  

    // parse fc3 data
    if(std::stoi(argv[1])){
        std::ifstream ifc3(FC3_RAW_FILE, std::ifstream::in);
        if (!ifc3.good()) std::cout << "Could not open fc3 raw file." << std::endl;
        while(ifc3>>data){
        u_size = L2_MEM_UNIT_SIZE;
        if(!data.find("[")) {
                if(bias){
                    ofc3[file_no-1].close();
                    ofc3[file_no].open(FC3_BIAS_FILE, std::ios::out);
                    file_no++;
                }
                else if((n_cntr%u_size) == 0){
                    if(file_no != 0) ofc3[file_no-1].close();
                    wght_mem_file_name = "input/weight_mem_L2_N"+std::to_string(file_no)+".txt";
                    ofc3[file_no].open(wght_mem_file_name, std::ios::out);
                    file_no = (n_cntr/u_size + 1);
                    ofc3[file_no-1]<<u_size*LAYER1_SIZE_LOGICAL<<std::endl;
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

            ofc3[file_no-1]<<data<<std::endl;
        }
        ifc3.close(); ofc3[n_cntr-1].close(); n_cntr=0; file_no = 0; bias=false;
    }

    if(std::stoi(argv[1])){
        std::ifstream ispkin(SPIKE_IN_RAW_FILE, std::ifstream::in);
        std::ofstream ospkin(SPIKE_IN_FILE, std::ifstream::out);
        if (!ispkin.good()) std::cout << "Could not open spk_in raw file." << std::endl;   
        if (!ospkin.good()) std::cout << "Could not open spk_in file." << std::endl;   
        while(ispkin>>ch){
            if(ch == '0' || ch == '1') {
                ospkin<<ch;
                if(idx%INPUT_LAYER_SIZE==INPUT_LAYER_SIZE-1) ospkin<<"\n";
                idx++;
            }
        }
        ispkin.close();
        ospkin.close();
    }

    return 0;
}

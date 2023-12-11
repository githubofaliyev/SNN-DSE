#include <errno.h>
#include <iostream>
#include <cmath>
#include <fstream>
#include "defines.h"

int main(int argc, char *argv[]){   
    
    std::ifstream def_in("neuron_replicator/defines.txt", std::ifstream::in);    
    std::string my_str = "";
    std::string data;
    std::ofstream def_out("include/defines.h", std::ifstream::out);
   
    // generate top_level.h
    if (!def_in.good()) std::cout << "Could not open def_in raw file." << std::endl;
    if (!def_out.good()) std::cout << "Could not open def_out raw file." << std::endl;
    while(std::getline(def_in,data)){
        if(!data.find("#define L0_MEM_UNIT_SIZE"))      def_out<<data<<" "<<argv[1]<<std::endl;
        else if(!data.find("#define L1_MEM_UNIT_SIZE")) def_out<<data<<" "<<argv[2]<<std::endl;
        else if(!data.find("#define L2_MEM_UNIT_SIZE")) def_out<<data<<" "<<argv[3]<<std::endl;
        else if(!data.find("#define TIME_STEP")) def_out<<data<<" "<<argv[4]<<std::endl;
        else def_out<<data<<std::endl;
    }
    def_out<<std::endl;

    def_in.close(); 
    def_out.close();

    return 0;
}

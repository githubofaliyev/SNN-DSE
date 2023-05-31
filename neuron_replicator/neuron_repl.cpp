#include <errno.h>
#include <iostream>
#include <cmath>
#include <fstream>
#include "defines.h"

int main(){   
    
    std::ifstream h_templ("neuron_replicator/top_template1.txt", std::ifstream::in);    
    std::ifstream cpp_templ("neuron_replicator/top_cpp_template1.txt", std::ifstream::in);    
    std::string my_str = "";
    std::string data;
    std::ofstream ospkin_h("include/top_level.h", std::ifstream::out);
    std::ofstream ospkin_cpp("src/top_level.cpp", std::ifstream::out);
   
    // generate top_level.h
    if (!h_templ.good()) std::cout << "Could not open h_templ raw file." << std::endl;
    while(std::getline(h_templ,data)){
        ospkin_h<<data<<std::endl;
    }
    ospkin_h<<std::endl;

   /************************* Layer0 ***********************/
    for(size_t i=0; i<L0_TOTAL_AVAIL_MEM; i++){
        my_str = "        memory L0_mem_inst"+std::to_string(i)+";";
        ospkin_h<<my_str<<std::endl;
    }
    ospkin_h<<std::endl;
    for(size_t i=0; i<L0_TOTAL_AVAIL_MEM; i++){
        my_str = "        L0_accum L0_accum_inst"+std::to_string(i)+";";
        ospkin_h<<my_str<<std::endl;
    }
    ospkin_h<<std::endl;
    for(size_t i=0; i<LAYER0_SIZE_LOGICAL; i++){
        my_str = "        L0_activ L0_activ_inst"+std::to_string(i)+";";
        ospkin_h<<my_str<<std::endl;
    }
    ospkin_h<<"\n"<<std::endl;
    /************************* Layer0 ***********************/ 

    /************************* Layer1 ***********************/ 
    for(size_t i=0; i<L1_TOTAL_AVAIL_MEM; i++){
        my_str = "        memory L1_mem_inst"+std::to_string(i)+";";
        ospkin_h<<my_str<<std::endl;
    }
    ospkin_h<<"\n"<<std::endl;
    for(size_t i=0; i<L1_TOTAL_AVAIL_MEM; i++){
        my_str = "        L1_accum L1_accum_inst"+std::to_string(i)+";";
        ospkin_h<<my_str<<std::endl;
    }
    ospkin_h<<std::endl;
    for(size_t i=0; i<LAYER1_SIZE_LOGICAL; i++){
        my_str = "        L1_activ L1_activ_inst"+std::to_string(i)+";";
        ospkin_h<<my_str<<std::endl;
    } 
    ospkin_h<<"\n"<<std::endl;  
    /************************* Layer1 ***********************/

    /************************* Layer2 ***********************/
    for(size_t i=0; i<L2_TOTAL_AVAIL_MEM; i++){
        my_str = "        memory L2_mem_inst"+std::to_string(i)+";";
        ospkin_h<<my_str<<std::endl;
    }
    ospkin_h<<"\n"<<std::endl;
    for(size_t i=0; i<L2_TOTAL_AVAIL_MEM; i++){
        my_str = "        L2_accum L2_accum_inst"+std::to_string(i)+";";
        ospkin_h<<my_str<<std::endl;
    }
    ospkin_h<<std::endl;
    for(size_t i=0; i<LAYER2_SIZE_LOGICAL; i++){
        my_str = "        L2_activ L2_activ_inst"+std::to_string(i)+";";
        ospkin_h<<my_str<<std::endl;
    } 
    /************************* Layer2 ***********************/
    ospkin_h<<"};"<<std::endl;

    // generate top_level.cpp
    if (!cpp_templ.good()) std::cout << "Could not open cpp_templ raw file." << std::endl;
    while(std::getline(cpp_templ,data)){
        ospkin_cpp<<data<<std::endl;
    }
    ospkin_cpp<<std::endl;

    /************************* Layer0 ***********************/
    for(size_t i=0; i<L0_TOTAL_AVAIL_MEM; i++){
        my_str = ", L0_mem_inst"+std::to_string(i)+"(\"L0_mem_inst"+std::to_string(i)+"\", \"input/weight_mem_L0_N"+std::to_string(i)+".txt\")";
        ospkin_cpp<<my_str<<std::endl;
    } 
    ospkin_cpp<<std::endl;
    for(size_t i=0; i<L0_TOTAL_AVAIL_MEM; i++){
        my_str = ", L0_accum_inst"+std::to_string(i)+"(\"L0_accum_inst"+std::to_string(i)+"\", "+std::to_string(i)+")";
        ospkin_cpp<<my_str<<std::endl;
    } 
    ospkin_cpp<<std::endl;    
    for(size_t i=0; i<LAYER0_SIZE_LOGICAL; i++){
        my_str = ", L0_activ_inst"+std::to_string(i)+"(\"L0_activ_inst"+std::to_string(i)+"\", "+std::to_string(i)+")";
        ospkin_cpp<<my_str<<std::endl;
    } 
    ospkin_cpp<<std::endl;
    /************************* Layer0 ***********************/

    /************************* Layer1 ***********************/
    for(size_t i=0; i<L1_TOTAL_AVAIL_MEM; i++){
        my_str = ", L1_mem_inst"+std::to_string(i)+"(\"L1_mem_inst"+std::to_string(i)+"\", \"input/weight_mem_L1_N"+std::to_string(i)+".txt\")";
        ospkin_cpp<<my_str<<std::endl;
    } 
    ospkin_cpp<<std::endl;
    for(size_t i=0; i<L1_TOTAL_AVAIL_MEM; i++){
        my_str = ", L1_accum_inst"+std::to_string(i)+"(\"L1_accum_inst"+std::to_string(i)+"\", "+std::to_string(i)+")";
        ospkin_cpp<<my_str<<std::endl;
    } 
    ospkin_cpp<<std::endl;    
    for(size_t i=0; i<LAYER1_SIZE_LOGICAL; i++){
        my_str = ", L1_activ_inst"+std::to_string(i)+"(\"L1_activ_inst"+std::to_string(i)+"\", "+std::to_string(i)+")";
        ospkin_cpp<<my_str<<std::endl;
    } 
    ospkin_cpp<<std::endl;
    /************************* Layer1 ***********************/

    /************************* Layer2 ***********************/
    for(size_t i=0; i<L2_TOTAL_AVAIL_MEM; i++){
        my_str = ", L2_mem_inst"+std::to_string(i)+"(\"L2_mem_inst"+std::to_string(i)+"\", \"input/weight_mem_L2_N"+std::to_string(i)+".txt\")";
        ospkin_cpp<<my_str<<std::endl;
    } 
    ospkin_cpp<<std::endl;
    for(size_t i=0; i<L2_TOTAL_AVAIL_MEM; i++){
        my_str = ", L2_accum_inst"+std::to_string(i)+"(\"L2_accum_inst"+std::to_string(i)+"\", "+std::to_string(i)+")";
        ospkin_cpp<<my_str<<std::endl;
    } 
    ospkin_cpp<<std::endl;    
    for(size_t i=0; i<LAYER2_SIZE_LOGICAL; i++){
        my_str = ", L2_activ_inst"+std::to_string(i)+"(\"L2_activ_inst"+std::to_string(i)+"\", "+std::to_string(i)+")";
        ospkin_cpp<<my_str<<std::endl;
    } 
    /************************* Layer2 ***********************/

    ospkin_cpp<<"{"<<std::endl;
    ospkin_cpp<<"  ec_inst.clk(clk);"<<std::endl;
    ospkin_cpp<<std::endl;

    /************************* Layer0 ***********************/
    for(size_t i=0; i<L0_TOTAL_AVAIL_MEM; i++){
        my_str = "  L0_mem_inst"+std::to_string(i)+".Clk(clk);";
        ospkin_cpp<<my_str<<std::endl;
    }  
    ospkin_cpp<<std::endl;
    for(size_t i=0; i<L0_TOTAL_AVAIL_MEM; i++){
        my_str = "  L0_accum_inst"+std::to_string(i)+".clk(clk);";
        ospkin_cpp<<my_str<<std::endl;
    }  
    ospkin_cpp<<std::endl;
    for(size_t i=0; i<LAYER0_SIZE_LOGICAL; i++){
        my_str = "  L0_activ_inst"+std::to_string(i)+".clk(clk);";
        ospkin_cpp<<my_str<<std::endl;
    }  
    ospkin_cpp<<std::endl;
    for(size_t i=0; i<L0_TOTAL_AVAIL_MEM; i++){
        my_str = "  L0_accum_inst"+std::to_string(i)+".mem_port(L0_mem_inst"+std::to_string(i)+");";
        ospkin_cpp<<my_str<<std::endl;
    } 
    ospkin_cpp<<std::endl;
    /************************* Layer0 ***********************/

    /************************* Layer1 ***********************/
    for(size_t i=0; i<L1_TOTAL_AVAIL_MEM; i++){
        my_str = "  L1_mem_inst"+std::to_string(i)+".Clk(clk);";
        ospkin_cpp<<my_str<<std::endl;
    }  
    ospkin_cpp<<std::endl;
    for(size_t i=0; i<L1_TOTAL_AVAIL_MEM; i++){
        my_str = "  L1_accum_inst"+std::to_string(i)+".clk(clk);";
        ospkin_cpp<<my_str<<std::endl;
    }  
    ospkin_cpp<<std::endl;
    for(size_t i=0; i<LAYER1_SIZE_LOGICAL; i++){
        my_str = "  L1_activ_inst"+std::to_string(i)+".clk(clk);";
        ospkin_cpp<<my_str<<std::endl;
    }  
    ospkin_cpp<<std::endl;
    for(size_t i=0; i<L1_TOTAL_AVAIL_MEM; i++){
        my_str = "  L1_accum_inst"+std::to_string(i)+".mem_port(L1_mem_inst"+std::to_string(i)+");";
        ospkin_cpp<<my_str<<std::endl;
    }  
    ospkin_cpp<<std::endl;
    /************************* Layer1 ***********************/

    /************************* Layer2 ***********************/
    for(size_t i=0; i<L2_TOTAL_AVAIL_MEM; i++){
        my_str = "  L2_mem_inst"+std::to_string(i)+".Clk(clk);";
        ospkin_cpp<<my_str<<std::endl;
    }  
    ospkin_cpp<<std::endl;
    for(size_t i=0; i<L2_TOTAL_AVAIL_MEM; i++){
        my_str = "  L2_accum_inst"+std::to_string(i)+".clk(clk);";
        ospkin_cpp<<my_str<<std::endl;
    }  
    ospkin_cpp<<std::endl;
    for(size_t i=0; i<LAYER2_SIZE_LOGICAL; i++){
        my_str = "  L2_activ_inst"+std::to_string(i)+".clk(clk);";
        ospkin_cpp<<my_str<<std::endl;
    }  
    ospkin_cpp<<std::endl;
    for(size_t i=0; i<L2_TOTAL_AVAIL_MEM; i++){
        my_str = "  L2_accum_inst"+std::to_string(i)+".mem_port(L2_mem_inst"+std::to_string(i)+");";
        ospkin_cpp<<my_str<<std::endl;
    } 
    /************************* Layer2 ***********************/
      
    ospkin_cpp<<"}"<<std::endl;
    
    ospkin_h.close(); ospkin_cpp.close();

    return 0;
}

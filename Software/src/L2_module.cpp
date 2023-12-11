#include "L2_module.h"
#include "memory.h"
#include "globalVars.h"
#include <systemc.h>

using namespace globalVars;

L2_accum::L2_accum(sc_module_name name, uint16_t unit_idx): sc_module(name) ,unit_idx(unit_idx)
{
    SC_THREAD(ord_thread);
}

L2_activ::L2_activ(sc_module_name name, uint16_t unit_idx): sc_module(name), unit_idx(unit_idx)
{
    SC_THREAD(ord_thread);
}

void L2_accum::ord_thread() {
    bool avt;

    for(size_t n=0; n<L2_MEM_UNIT_SIZE; n++) {
        L2_acc[unit_idx*L2_MEM_UNIT_SIZE + n] = 0;
    }
    
    while(true){
        if(layer_accum[2] && !avt){
            for(size_t unit_neuron_idx=0; unit_neuron_idx<L2_MEM_UNIT_SIZE; unit_neuron_idx++){ // then start iterating unit-level neurons
                size_t layer_neuron_idx = unit_idx*L2_MEM_UNIT_SIZE + unit_neuron_idx; 
                if(layer_neuron_idx<LAYER2_SIZE_LOGICAL){   
                    double wght = 0; 
                    mem_port->Read((unit_neuron_idx*LAYER1_SIZE_LOGICAL+layer2_pre_spk_addr[layer_neuron_idx]), wght);
                    L2_acc[layer_neuron_idx] += wght;
                }
                wait(clk.posedge_event()); 
            }
            L2_accum_unit[unit_idx] = 1;
        }

        if(layer_accum[2]) avt = true;
        else avt = false;

        wait(clk.posedge_event()); // delta cycle, let accumulation done
    }
}

void L2_activ::ord_thread() {
    bool activateOnce1;
    L2_pot[unit_idx] = 0;
    
    while(true){
        if(layer_activ[2] && !activateOnce1){
            if(unit_idx<LAYER2_SIZE_LOGICAL){   
                L2_pot[unit_idx] = L2_pot[unit_idx]*BETA + L2_acc[unit_idx] + L2_bias[unit_idx];
                if(PRINT_NEURON)
                    std::cout << sc_time_stamp() << ",       [L2N"<<unit_idx<< "], L2_pot: "<< L2_pot[unit_idx] <<", L2_acc: "<<L2_acc[unit_idx]<< std::endl;
                L2_acc[unit_idx] = 0;
                if(L2_pot[unit_idx] > POSITIVE_THRESHOLD) {
                    layer2_out[unit_idx] = 1;
                    L2_pot[unit_idx] = L2_pot[unit_idx] - POSITIVE_THRESHOLD;
                }
            }
            wait(clk.posedge_event()); 
            L2_activ_unit[unit_idx] = 1; 
        }
        
        if(layer_activ[2]) activateOnce1 = true;
        else activateOnce1 = false;

        wait(clk.posedge_event()); // delta cycle, let accumulation done
    }
}
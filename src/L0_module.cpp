#include "L0_module.h"
#include "memory.h"
#include "globalVars.h"
#include <systemc.h>

using namespace globalVars;

L0_accum::L0_accum(sc_module_name name, uint16_t unit_idx): sc_module(name), unit_idx(unit_idx)
{
    SC_THREAD(ord_thread);
}

L0_activ::L0_activ(sc_module_name name, uint16_t unit_idx): sc_module(name), unit_idx(unit_idx)
{
    SC_THREAD(ord_thread);
}

void L0_accum::ord_thread() {
    bool avt;

    for(size_t n=0; n<L0_MEM_UNIT_SIZE; n++) {
        L0_acc[unit_idx*L0_MEM_UNIT_SIZE + n] = 0;
    }

    while(true){
        if(layer_accum[0] && !avt){
            for(size_t unit_neuron_idx=0; unit_neuron_idx<L0_MEM_UNIT_SIZE; unit_neuron_idx++){ // then start iterating unit-level neurons
                size_t layer_neuron_idx = unit_idx*L0_MEM_UNIT_SIZE + unit_neuron_idx; 
                if(layer_neuron_idx<LAYER0_SIZE_LOGICAL){  
                    double wght = 0; //L0_accum_unit[unit_idx] = 0;
                    mem_port->Read((unit_neuron_idx*INPUT_LAYER_SIZE+layer0_pre_spk_addr[layer_neuron_idx]), wght);
                    L0_acc[layer_neuron_idx] += wght;
                    //std::cout<<sc_time_stamp()<<", unit_idx: "<<unit_idx<<", neuron_idx: "<<layer_neuron_idx<<", spk_addr: "<<layer0_pre_spk_addr[layer_neuron_idx]<<", wght: "<<wght<<", L0_acc: "<<L0_acc[layer_neuron_idx]<<std::endl;
                }
                wait(clk.posedge_event()); 
            }
            L0_accum_unit[unit_idx] = 1;
        }
        if(layer_accum[0]) avt = true;
        else avt = false;
        wait(clk.posedge_event()); // delta cycle, let accumulation done
    }
}

void L0_activ::ord_thread() {
    bool activateOnce1;
    L0_pot[unit_idx] = 0;
 
    while(true){    
        if(layer_activ[0] && !activateOnce1){
            if(unit_idx<LAYER0_SIZE_LOGICAL){   
                L0_pot[unit_idx] = L0_pot[unit_idx]*BETA + L0_acc[unit_idx] + L0_bias[unit_idx];
                if(L0_pot[unit_idx] > POSITIVE_THRESHOLD) {
                    //std::cout << sc_time_stamp() << ",       [L0N"<<unit_idx<< "], L0_pot: "<< L0_pot[unit_idx] <<", L0_acc: "<<L0_acc[unit_idx]<< std::endl;
                    layer0_out[unit_idx] = 1;
                    L0_pot[unit_idx] = L0_pot[unit_idx] - POSITIVE_THRESHOLD;
                }
                L0_acc[unit_idx] = 0;
            }
            wait(clk.posedge_event()); 
            L0_activ_unit[unit_idx] = 1; 
        }
        
        if(layer_activ[0]) activateOnce1 = true;
        else activateOnce1 = false;

        wait(clk.posedge_event()); // delta cycle, let accumulation done
    }
}
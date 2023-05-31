#include "L1_module.h"
#include "memory.h"
#include "globalVars.h"
#include <systemc.h>

using namespace globalVars;

L1_accum::L1_accum(sc_module_name name, uint16_t unit_idx): sc_module(name) ,unit_idx(unit_idx)
{
    SC_THREAD(ord_thread);
}

L1_activ::L1_activ(sc_module_name name, uint16_t unit_idx): sc_module(name), unit_idx(unit_idx)
{
    SC_THREAD(ord_thread);
}

void L1_accum::ord_thread() {
    bool avt;

    for(size_t n=0; n<L1_MEM_UNIT_SIZE; n++) {
        L1_acc[unit_idx*L1_MEM_UNIT_SIZE + n] = 0;
    }

    while(true){
        if(layer_accum[1] && !avt){
            for(size_t unit_neuron_idx=0; unit_neuron_idx<L1_MEM_UNIT_SIZE; unit_neuron_idx++){ // then start iterating unit-level neurons
                size_t layer_neuron_idx = unit_idx*L1_MEM_UNIT_SIZE + unit_neuron_idx; 
                if(layer_neuron_idx<LAYER1_SIZE_LOGICAL){   
                    double wght = 0; 
                    mem_port->Read((unit_neuron_idx*LAYER0_SIZE_LOGICAL+layer1_pre_spk_addr[layer_neuron_idx]), wght);
                    L1_acc[layer_neuron_idx] += wght;
                    //if(layer_neuron_idx==2) 
                    //    std::cout<<sc_time_stamp()<<", unit_idx: "<<unit_idx<<", neuron_idx: "<<layer_neuron_idx<<", spk_addr: "<<layer1_pre_spk_addr[layer_neuron_idx]<<", wght: "<<wght<<", L1_acc: "<<L1_acc[layer_neuron_idx]<<std::endl;
                    //mem_access_cnt++;
                }
                wait(clk.posedge_event()); 
            }
            L1_accum_unit[unit_idx] = 1;
        }

        if(layer_accum[1]) avt = true;
        else avt = false;

        wait(clk.posedge_event()); // delta cycle, let accumulation done
    }
}


void L1_activ::ord_thread() {
    bool activateOnce1;
    L1_pot[unit_idx] = 0;

    while(true){
        if(layer_activ[1] && !activateOnce1){
            if(unit_idx<LAYER1_SIZE_LOGICAL){   
                L1_pot[unit_idx] = L1_pot[unit_idx]*BETA + L1_acc[unit_idx] + L1_bias[unit_idx];
                //std::cout << sc_time_stamp() << ",       [L1N"<<unit_idx<< "], pot: "<< L1_pot[unit_idx] <<", acc: "<<L1_acc[unit_idx]<<", bias: "<<L1_bias[unit_idx]<<", idx: "<<unit_idx<<std::endl;
                if(L1_pot[unit_idx] > POSITIVE_THRESHOLD) {
                    //std::cout << sc_time_stamp() << ",       [L1N"<<unit_idx<< "], L1_pot: "<< L1_pot[unit_idx] <<", L1_acc: "<<L1_acc[unit_idx]<< std::endl;
                    layer1_out[unit_idx] = 1;
                    L1_pot[unit_idx] = L1_pot[unit_idx] - POSITIVE_THRESHOLD;
                }
                L1_acc[unit_idx] = 0;
            }
            wait(clk.posedge_event()); 
            L1_activ_unit[unit_idx] = 1; 
        }
        
        if(layer_activ[1]) activateOnce1 = true;
        else activateOnce1 = false;

        wait(clk.posedge_event()); // delta cycle, let accumulation done
    }
}
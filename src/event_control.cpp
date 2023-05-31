#include "event_control.h"
#include "globalVars.h"
#include <systemc.h>

using namespace globalVars;

event_control::event_control(sc_module_name name)
: sc_module(name)
{
    SC_THREAD(event_controller0); 
    SC_THREAD(event_controller1);
    SC_THREAD(event_controller2);
}

void event_control::spike_file_read(){
    std::ifstream spk_infs(SPIKE_IN_FILE, std::ifstream::in);
    std::ifstream fc1_biasfs(FC1_BIAS_FILE, std::ifstream::in);
    std::ifstream fc2_biasfs(FC2_BIAS_FILE, std::ifstream::in);
    std::ifstream fc3_biasfs(FC3_BIAS_FILE, std::ifstream::in);
    uint16_t idx=0; std::string data;

    if (!spk_infs.good()) std::cout << "Could not open spike file." << endl;    
    while((spk_infs >> data)){
        //std::cout<<"data: "<<data<<std::endl;
        spk_in[idx] = static_cast<std::bitset<INPUT_LAYER_SIZE>>(data);
        reverse(spk_in[idx]); idx++;
        //std::cout<<"size: "<<spk_in[idx].size()<<std::endl;
    }
    spk_infs.close(); idx=0;

    if (!fc1_biasfs.good()) std::cout << "Could not open bias file." << endl;
    while(fc1_biasfs >> data){
        L0_bias[idx] = std::stof(data);        
        idx++;
    }
    fc1_biasfs.close(); idx=0;

    if (!fc2_biasfs.good()) std::cout << "Could not open bias file." << endl;
    while(fc2_biasfs >> data){
        L1_bias[idx] = std::stof(data);  
        //std::cout << sc_time_stamp() << ",       bias"<<L1_bias[idx]<<", idx: "<<idx<<std::endl;    
        idx++;
    }
    fc2_biasfs.close(); idx=0;

    if (!fc3_biasfs.good()) std::cout << "Could not open bias file." << endl;
    while(fc3_biasfs >> data){
        L2_bias[idx] = std::stof(data);   
        idx++;
    }
    fc3_biasfs.close(); idx=0;

}

void event_control::init(){
    time_step[0] = 0; time_step[1] = 0;
    layer_accum[0] = 0; layer_accum[1] = 0;
    layer_activ[0] = 0; layer_activ[1] = 0;
    spk_in_done = false; layer0_shift_amt = 0;
    state1 = 0; state2 = 0; layer0_phase = 0; layer1_phase = 0;
    L1_accum_unit = 0; spike_file_read(); state3 = 0;
    buf_avail[0] = true; buf_avail[1] = true; mem_access_cnt = 0;
    std::cout<<sc_time_stamp()<<", init done!"<<std::endl;
}

void event_control::wait_clocks(uint8_t cycles){
    for (int w=0; w<cycles; w++) wait(clk.posedge_event());
}

void event_control::spk_address_gen(uint8_t layer){
    if(layer == 0){
        for(size_t n=0; n<LAYER0_SIZE_LOGICAL; n++){
            size_t n_shifted = (layer0_shift_cntr+n)%L0_total_spks;
            layer0_pre_spk_addr[n] = layer0_in[n_shifted];
        }
    }
    else if(layer == 1){
        for(size_t n=0; n<LAYER1_SIZE_LOGICAL; n++){
            size_t n_shifted = (layer1_shift_cntr+n)%L1_total_spks;
            layer1_pre_spk_addr[n] = layer1_in[n_shifted];
            //std::cout<<sc_time_stamp()<<", neuron: "<<n<<", spk: "<<layer1_pre_spk_addr[n]<<std::endl;
        }
    }
    else if(layer == 2){
        for(size_t n=0; n<LAYER2_SIZE_LOGICAL; n++){
            size_t n_shifted = (layer2_shift_cntr+n)%L2_total_spks;
            layer2_pre_spk_addr[n] = layer2_in[n_shifted];
            //std::cout<<sc_time_stamp()<<", neuron: "<<n<<", spk: "<<layer1_pre_spk_addr[n]<<std::endl;
        }
    }
}


template<std::size_t N>
void event_control::reverse(std::bitset<N> &b) {
    for(std::size_t i = 0; i < N/2; ++i) {
        bool t = b[i];
        b[i] = b[N-i-1];
        b[N-i-1] = t;
    }
}

void event_control::event_controller0(){
    init(); spk_in_done = false; size_t ind;
    
    while(!spk_in_done){
        switch(state1){
            case 0:
                layer_accum[0] = 0; 
                L0_total_spks = spk_in[time_step[0]].count();
                std::cout<<sc_time_stamp()<<", input->layer0 spks: "<<L0_total_spks<<", for time step: "<<time_step[0]<<std::endl;
                ind = 0;
                if(L0_total_spks == 0){
                    state1 = 4; //buf_avail[1] = true;
                } else{
                    for(size_t spk = 0; spk < L0_total_spks; spk++){
                        size_t ind = spk_in[time_step[0]]._Find_first();
                        //if(ind < INPUT_LAYER_SIZE){
                            //std::cout<<sc_time_stamp()<<", ind: "<<ind<<", spk: "<<spk<<std::endl;
                            layer0_in[spk] = ind; 
                            spk_in[time_step[0]][ind] = 0;
                        //}
                    }
                    state1 = 1; layer0_shift_cntr = 0; 
                }
                //std::cout<<sc_time_stamp()<<", L0_total_spks: "<<L0_total_spks<<std::endl;
                break;
            case 1: // accumulation state
                //std::cout<<sc_time_stamp()<<", layer0_shift_cntr: "<<layer0_shift_cntr<<std::endl;                
                
                spk_address_gen(0); 
                state1 = 2; layer0_shift_cntr++;
                L0_accum_unit = 0; layer_accum[0] = 1;
                break;  
            case 2:
                //std::cout<<sc_time_stamp()<<", L0_accum_unit: "<<L0_accum_unit<<std::endl;
                layer_accum[0] = 1; layer_activ[0] = 0;
                wait_clocks(4*L0_MEM_UNIT_SIZE);
                layer_accum[0] = 0; 
                state1 = 1; // if all mem units done, go to shifting
                if(layer0_shift_cntr >= L0_total_spks) {
                    //std::cout<<sc_time_stamp()<<", layer0_shift_cntr: "<<layer0_shift_cntr<<", L0_total_spks: "<<L0_total_spks<<std::endl;
                    layer0_shift_cntr = 0; state1 = 3; layer_accum[0] = 0; 
                } 
                break;
            case 3:
                if(buf_avail[0]){
                    state1 = 4; layer_activ[0] = 1; L0_accum_unit = 0; L0_activ_unit = 0;
                }
                break;
            case 4: // activation state
                wait_clocks(1);
                layer_activ[0] = 0; layer0_buf = layer0_out; 
                state1 = 5; buf_avail[0] = false;
                break;  
            case 5:
                //std::cout<<sc_time_stamp()<<", Layer0 done with time step: "<<time_step[0]<<", axon_in: "<<spk_in[time_step[0]]<<", axon_out: "<<layer0_out<<std::endl;               
                layer0_out = 0; state1 = 0; time_step[0]++;
                if(time_step[0] == TIME_STEP) spk_in_done = true;
                break;     
        }
        wait(clk.posedge_event()); // wait for RTL cycle
    }    
}

void event_control::event_controller1(){
    while(true){
        switch(state2){
            case 0: // wait state
                layer_accum[1] = 0; layer_activ[1] = 0;
                if(!buf_avail[0]) {
                    state2 = 1; time_step[1] = time_step[0];
                }
                break;
            case 1:
                L1_accum_unit = 0; layer_accum[1] = 0;
                L1_total_spks = layer0_buf.count();
                std::cout<<sc_time_stamp()<<", layer0->layer1 spks: "<<L1_total_spks<<", for time step: "<<time_step[1]<<std::endl;
                if(L1_total_spks == 0){
                    state2 = 4; //buf_avail[1] = true;
                }
                else {
                    for(size_t spk = 0; spk < L1_total_spks; spk++){
                        size_t ind = layer0_buf._Find_first();
                        //if(ind < LAYER0_SIZE_LOGICAL){
                            layer1_in[spk] = ind; 
                            layer0_buf[ind] = 0;
                        //}
                    }
                    state2 = 2; layer1_shift_cntr = 0; 
                }
                break;               
            case 2: // accumulation state              
                spk_address_gen(1);
                //std::cout<<sc_time_stamp()<<", layer1_shift_cntr: "<<layer1_shift_cntr<<std::endl;
                layer1_shift_cntr++; state2 = 3;
                L1_accum_unit = 0;
                break;
            case 3:
                layer_accum[1] = 1; layer_activ[1] = 0;
                wait_clocks(4*L1_MEM_UNIT_SIZE);
                layer_accum[1] = 0;
                state2 = 2; // if all mem units done, go to shifting
                if(layer1_shift_cntr == L1_total_spks) {
                    layer1_shift_cntr = 0; state2 = 4;
                    //std::cout<<sc_time_stamp()<<", layer1_phase: "<<layer1_phase<<std::endl;
                } 
                break;
            case 4:
                if(buf_avail[1]){
                    state2 = 5; L1_accum_unit = 0; L1_activ_unit = 0;
                    layer_activ[1] = 1;
                }
                break;
            case 5: // activation state
                //std::cout<<sc_time_stamp()<<", layer1_phase: "<<layer1_phase<<std::endl;
                wait_clocks(1);
                layer_activ[1] = 0; buf_avail[1] = false; // buff not avail, since just filled up
                state2 = 6; layer1_buf = layer1_out;  // load buffer again with new spikes
                buf_avail[0] = true;
                break;  
            case 6:
                if(PRINT_LAYER1)
                    std::cout<<sc_time_stamp()<<", Layer1 done with time step: "<<time_step[1]<<", axon_in: "<<layer0_buf<<", axon_out: "<<layer1_out<<std::endl;               
                layer_activ[1] = 0; layer1_out = 0; state2 = 0; time_step[2] = time_step[1];
        }
        wait(clk.posedge_event());
    }    
}

void event_control::event_controller2(){
    while(true){
        switch(state3){
            case 0: // wait state
                layer_accum[2] = 0; layer_activ[2] = 0; layer2_phase = 0;
                //std::cout<<sc_time_stamp()<<", Layer2, state2 = 0, time step: "<<time_step-1<<std::endl;
                if(!buf_avail[1]){ // if buffer full, meaning spike exist
                    state3 = 1; time_step[2] = time_step[1];
                }
                break;
            case 1:
                L2_accum_unit = 0; layer_accum[2] = 0;
                L2_total_spks = layer1_buf.count();
                std::cout<<sc_time_stamp()<<", layer1->layer2 spks: "<<L2_total_spks<<", for time step: "<<time_step[2]<<std::endl;                
                if(L2_total_spks == 0){
                    state3 = 4; //buf_avail[1] = true;
                }
                else{    
                    for(size_t spk = 0; spk < L2_total_spks; spk++){
                        size_t ind = layer1_buf._Find_first();
                        //if(ind < LAYER1_SIZE_LOGICAL){
                            layer2_in[spk] = ind; 
                            layer1_buf[ind] = 0;
                        //}
                        //std::cout<<sc_time_stamp()<<", spk: "<<spk<<", layer2_in[spk]: "<<layer2_in[spk]<<std::endl;
                    }
                    state3 = 2; layer2_shift_cntr = 0; 
                }
                //std::cout<<sc_time_stamp()<<", state1: "<<state1<<std::endl;
                break;              
            case 2: // accumulation state              
                spk_address_gen(2); // generate addresses of layer1 neurons 
                //std::cout<<sc_time_stamp()<<", layer2_shift_cntr: "<<layer2_shift_cntr<<std::endl;
                layer2_shift_cntr++; state3 = 3;
                L2_accum_unit = 0;
                break;
            case 3:
                //std::cout<<sc_time_stamp()<<", L1_mem_unit: "<<L1_mem_unit<<std::endl;
                layer_accum[2] = 1; layer_activ[2] = 0;
                wait_clocks(4*L2_MEM_UNIT_SIZE);
                layer_accum[2] = 0;
                state3 = 2; // if all mem units done, go to shifting
                if(layer2_shift_cntr == L2_total_spks) {
                    layer2_shift_cntr = 0; state3 = 4;
                } 
                break;
            case 4:
                state3 = 5;
                layer_activ[2] = 1; L2_accum_unit = 0; L2_activ_unit = 0;
                break;
            case 5: // activation state
                //std::cout<<sc_time_stamp()<<", layer1_phase: "<<layer1_phase<<std::endl;
                wait_clocks(1);
                layer_activ[2] = 0;
                state3 = 6; buf_avail[1] = true;
                break;  
            case 6:
                std::cout<<sc_time_stamp()<<", layer2 spks: "<<layer2_out.count()<<", for time step: "<<time_step[2]<<std::endl;
                if(PRINT_LAYER1)
                    std::cout<<sc_time_stamp()<<", Layer2 done with time step: "<<time_step[2]<<", axon_in: "<<layer1_buf<<", axon_out: "<<layer2_out<<std::endl;               
                layer_activ[2] = 0; layer2_out = 0; state3 = 0;
                if(spk_in_done && time_step[2] == TIME_STEP-1) {
                    std::ofstream trace_log("trace_log.txt", std::ofstream::out | std::ofstream::app);
                    trace_log<<"resource config: "<<L0_MEM_UNIT_SIZE<<"x"<<L1_MEM_UNIT_SIZE<<"x"<<L2_MEM_UNIT_SIZE<<", time spent: "<<sc_time_stamp()<<std::endl; // Write the data to the file
                    trace_log.close(); 
                    std::cout<<"resource config: "<<L0_MEM_UNIT_SIZE<<"x"<<L1_MEM_UNIT_SIZE<<"x"<<L2_MEM_UNIT_SIZE<<", time spent: "<<sc_time_stamp()<<std::endl;
                    sc_stop();
                }
                time_step[2] = time_step[1];
        }
        wait(clk.posedge_event());
    }    
}
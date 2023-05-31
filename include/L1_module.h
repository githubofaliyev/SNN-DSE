#ifndef L1_MODULE_H
#define L1_MODULE_H

#include <systemc.h>
#include "memory_if.h"
#include <bitset>
#include "defines.h"

SC_MODULE(L1_accum) {
    public:
        SC_HAS_PROCESS(L1_accum);
        sc_in<bool> clk;
        sc_port<memory_if> mem_port;
        L1_accum(sc_module_name name, uint16_t unit_idx);
        
    private:
        void ord_thread();
        uint16_t unit_idx;
};

SC_MODULE(L1_activ) {
    public:
        SC_HAS_PROCESS(L1_activ);
        sc_in<bool> clk;
        L1_activ(sc_module_name name, uint16_t unit_idx);
        
    private:
        void ord_thread();
        uint16_t unit_idx;

};

#endif
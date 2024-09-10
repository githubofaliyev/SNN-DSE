#ifndef L2_MODULE_H
#define L2_MODULE_H

#include <systemc.h>
#include "memory_if.h"
#include <bitset>
#include "defines.h"

SC_MODULE(L2_accum) {
    public:
        SC_HAS_PROCESS(L2_accum);
        sc_in<bool> clk;
        sc_port<memory_if> mem_port;
        L2_accum(sc_module_name name, uint16_t unit_idx);
        
    private:
        void ord_thread();
        uint16_t unit_idx;
};

SC_MODULE(L2_activ) {
    public:
        SC_HAS_PROCESS(L2_activ);
        sc_in<bool> clk;
        L2_activ(sc_module_name name, uint16_t unit_idx);
        
    private:
        void ord_thread();
        uint16_t unit_idx;

};

#endif
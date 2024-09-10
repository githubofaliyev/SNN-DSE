#include "event_control.h"
#include "L0_module.h"
#include "L1_module.h"
#include "L2_module.h"
#include "mem.h"
#include "memory.h"
#include <systemc.h>

SC_MODULE(top_level) {
 public:
 SC_HAS_PROCESS(top_level);
 sc_in<bool> clk;
 top_level(sc_module_name name);
 private:
 event_control ec_inst;

 // declare arrays of memory, L0_accum and L0_activ objects for L0
 memory* L0_mem_inst[L0_TOTAL_AVAIL_MEM];
 L0_accum* L0_accum_inst[L0_TOTAL_AVAIL_MEM];
 L0_activ* L0_activ_inst[LAYER0_SIZE_LOGICAL];

 // declare arrays of memory, L1_accum and L1_activ objects for L1
 memory* L1_mem_inst[L1_TOTAL_AVAIL_MEM];
 L1_accum* L1_accum_inst[L1_TOTAL_AVAIL_MEM];
 L1_activ* L1_activ_inst[LAYER1_SIZE_LOGICAL];

 // declare arrays of memory, L2_accum and L2_activ objects for L2
 memory* L2_mem_inst[L2_TOTAL_AVAIL_MEM];
 L2_accum* L2_accum_inst[L2_TOTAL_AVAIL_MEM];
 L2_activ* L2_activ_inst[LAYER2_SIZE_LOGICAL];
};

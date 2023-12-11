#ifndef MEMORY_RTL_H
#define MEMORY_RTL_H

#include "mem.h"

#include <systemc.h>

class memory_rtl
: public sc_module
{
    public:
        sc_in<bool> Clk;
        sc_in<sc_logic> Ren, Wen;
        sc_in<int> Addr;
        sc_in<double> DataIn;
        sc_out<double> DataOut;
        sc_out<sc_logic> Ack;
        // unsigned int memData[MEM_SIZE];

        SC_HAS_PROCESS(memory_rtl);

        memory_rtl(sc_module_name name, std::string memInitFilename);

    private:
        mem mem_inst;
        void rtl_thread();
};

#endif

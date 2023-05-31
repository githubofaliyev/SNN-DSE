#ifndef MEMORY_H
#define MEMORY_H

#include "memory_if.h"
#include "memory_rtl.h"

#include <systemc.h>

class memory 
: public sc_channel
, public memory_if {
    public:
        SC_HAS_PROCESS(memory);
        sc_in<bool> Clk;
        memory(sc_module_name name, std::string file_name);
        bool Write(unsigned int addr, double data);
        bool Read(unsigned int addr, double& data);

    private:
        sc_signal<sc_logic> Ren, Wen;
        sc_signal<int> Addr;
        sc_signal<double> DataIn;
        sc_signal<double> DataOut;
        sc_signal<sc_logic> Ack;

        memory_rtl rtl;
};

#endif

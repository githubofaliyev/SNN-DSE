#include "memory_if.h"
#include "memory_rtl.h"
#include "mem.h"

#include <systemc.h>

#include <iostream>

memory_rtl::memory_rtl(sc_module_name name, std::string memInitFilename)
: sc_module(name)
, mem_inst("mem_inst", memInitFilename)
{
    SC_THREAD(rtl_thread);
}

void memory_rtl::rtl_thread() {
    bool ack = false;
    unsigned int addr;
    double data;

    while (true) {
        if (Ren.read() == SC_LOGIC_1) {
            addr = Addr.read();
            ack = mem_inst.Read(addr, data);
            wait(Clk.posedge_event());
            if (ack)
                DataOut.write(data);
            // std::cout << "Reading " << data << " from address " << addr << std::endl;
        } else if (Wen.read() == SC_LOGIC_1) {
            addr = Addr.read();
            data = DataIn.read();
            ack = mem_inst.Write(addr, data);
            wait(Clk.posedge_event());
        } else {
            Ack.write(SC_LOGIC_0);
            wait(Clk.posedge_event());
        }
        Ack.write(ack ? SC_LOGIC_1 : SC_LOGIC_0);
    }
}

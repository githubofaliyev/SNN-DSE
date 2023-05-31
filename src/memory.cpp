#include "memory_rtl.h"
#include "memory.h"
#include <systemc.h>

memory::memory(sc_module_name name, std::string file_name)
: sc_module(name)
, rtl("rtl", file_name)
{
    rtl.Clk(Clk);
    rtl.Ren(Ren);
    rtl.Wen(Wen);
    rtl.Addr(Addr);
    rtl.DataIn(DataIn);
    rtl.DataOut(DataOut);
    rtl.Ack(Ack);

    //SC_THREAD(oscillator_thread);
}

bool memory::Write(unsigned int addr, double data) {
    Addr.write(addr);
    DataIn.write(data);
    Wen.write(SC_LOGIC_1);

    wait(Clk.posedge_event()); // RTL reads inputs
    Wen.write(SC_LOGIC_0);
    wait(Clk.posedge_event()); // RTL waits a cycle
    wait(Clk.posedge_event()); // Wait for Delta cycle

    return ((Ack.read() == SC_LOGIC_1) ? true : false);
}

bool memory::Read(unsigned int addr, double& data) {
    //wait(Clk.posedge_event()); // RTL reads inputs
    Addr.write(addr);
    Ren.write(SC_LOGIC_1);
    
    wait(Clk.posedge_event()); // RTL reads inputs
    Ren.write(SC_LOGIC_0);
    wait(Clk.posedge_event()); // RTL waits a cycle
    wait(Clk.posedge_event()); // Wait for Delta cycle

    data = (double)DataOut.read();
    return ((Ack.read() == SC_LOGIC_1) ? true : false);
}


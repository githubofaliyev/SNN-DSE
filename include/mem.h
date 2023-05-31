#ifndef MEM_H
#define MEM_H

#include <string>
#include <systemc.h>
#include "memory_if.h"
#include "defines.h"

class mem
: virtual public sc_channel
, virtual public memory_if
{
    public:
        SC_HAS_PROCESS(mem);
        mem(sc_module_name name, std::string file_name);
        virtual bool Write(unsigned int addr,  double data);
        virtual bool Read(unsigned int addr, double& data);

    protected:
        double* memory;
        u_int32_t mem_size;
};

#endif
#ifndef MEMORY_IF
#define MEMORY_IF

#include <systemc.h>

class memory_if : virtual public sc_interface
{
    public:
        virtual bool Write(unsigned int addr, double data) = 0;
        virtual bool Read(unsigned int addr, double& data) = 0;
};

#endif

#include <fstream>
#include <iostream>

#include <systemc.h>

#include "mem.h"
#include <sstream>

mem::mem(sc_module_name name, std::string mem_file_name)
: sc_module(name)
{
    std::ifstream ifs(mem_file_name, std::ifstream::in);
    uint32_t idx = 0;
    double data = 0;

    if (!ifs.good()) {
        std::cout << "Could not open mem file: "<<mem_file_name<< endl;
    }
    
    ifs>>mem_size;

    memory = new double[mem_size];
    memset(memory, 0, mem_size * sizeof(double));

    while((ifs >> data) && (idx < mem_size))
        memory[idx++] = data;

    ifs.close();
}

bool mem::Write(unsigned int addr, double data) {
    if (addr < mem_size) {
        memory[addr] = data;
        return true;
    } else {
        return false;
    }
}

bool mem::Read(unsigned int addr, double& data) {
    if (addr < mem_size) {
        data = memory[addr];
        return true;
    } else {
        return false;
    }
}

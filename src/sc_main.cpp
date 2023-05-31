#include "top_level.h"
#include <systemc.h>

#include <errno.h>
#include <iostream>
#include <fstream>
#include "defines.h"

int sc_main(int argc, char* argv[]) {

    sc_clock clk("clk", 10, SC_US, 0.5, 5, SC_US, false);
    top_level top_inst("top_inst");
    top_inst.clk(clk);

    sc_start();

    //double t = (0.0+LAYER0_SIZE)/LAYER1_SIZE; t = std::ceil(t);
    //std::cout<<", phase: "<<t<<std::endl;


    return 0;
}

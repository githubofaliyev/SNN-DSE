#ifndef EVENT_CONTROL
#define EVENT_CONTROL

#include <systemc.h>
#include <bitset>
#include "defines.h"

SC_MODULE(event_control){
    public:
        SC_CTOR(event_control);
        sc_in<bool> clk;

        bool spike_rd[3], spike_wrt[3];
        uint8_t state1, state2, state3, layer0_shift_amt, layer1_shift_amt;
        uint32_t layer0_shift_cntr, layer1_shift_cntr, layer2_shift_cntr;
        uint16_t time_step[3];
        std::bitset<INPUT_LAYER_SIZE> spk_in[TIME_STEP];
        bool spk_in_done, buf_avail[2];
        uint32_t L0_cycles=0;

    protected:
        void event_controller0();
        void event_controller1();
        void event_controller2();

        // utility functions
        void init();
        void spike_file_read();
        void spk_address_gen(uint8_t layer);
        void wait_clocks(uint8_t cycles);
        template<std::size_t N>
        void reverse(std::bitset<N> &b);

};
#endif
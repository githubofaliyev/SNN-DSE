#pragma once
namespace globalVars
{
    inline double L0_bias[LAYER0_SIZE_LOGICAL];
    inline double L1_bias[LAYER1_SIZE_LOGICAL];
    inline double L2_bias[LAYER2_SIZE_LOGICAL];

    inline double l0_wght[LAYER0_SIZE_LOGICAL];
    inline double l1_wght[LAYER1_SIZE_LOGICAL];
    inline double l2_wght[LAYER2_SIZE_LOGICAL];

    inline std::bitset<L0_TOTAL_AVAIL_MEM> L0_accum_unit;
    inline std::bitset<L1_TOTAL_AVAIL_MEM> L1_accum_unit;
    inline std::bitset<L2_TOTAL_AVAIL_MEM> L2_accum_unit;

    inline std::bitset<LAYER0_SIZE_LOGICAL> L0_activ_unit;
    inline std::bitset<LAYER1_SIZE_LOGICAL> L1_activ_unit;
    inline std::bitset<LAYER2_SIZE_LOGICAL> L2_activ_unit;

    inline bool layer_accum[3], layer_activ[3];

    inline uint32_t layer0_pre_spk_addr[LAYER0_SIZE_LOGICAL];
    inline uint32_t layer1_pre_spk_addr[LAYER1_SIZE_LOGICAL];
    inline uint32_t layer2_pre_spk_addr[LAYER2_SIZE_LOGICAL];

    inline size_t layer0_phase, layer1_phase, layer2_phase;
    
    inline size_t layer0_in[LAYER0_SIZE_LOGICAL];
    inline size_t layer1_in[LAYER1_SIZE_LOGICAL];
    inline size_t layer2_in[LAYER2_SIZE_LOGICAL];
    
    inline std::bitset<LAYER0_SIZE_LOGICAL> layer0_out, layer0_buf;
    inline std::bitset<LAYER1_SIZE_LOGICAL> layer1_out, layer1_buf;
    inline std::bitset<LAYER2_SIZE_LOGICAL> layer2_out, layer2_buf;

    inline uint32_t mem_access_cnt;
    inline double L0_pot[LAYER0_SIZE_LOGICAL];
    inline double L1_pot[LAYER1_SIZE_LOGICAL];
    inline double L2_pot[LAYER2_SIZE_LOGICAL];

    inline double L0_acc[LAYER0_SIZE_LOGICAL];
    inline double L1_acc[LAYER1_SIZE_LOGICAL];
    inline double L2_acc[LAYER2_SIZE_LOGICAL];

    inline size_t L0_total_spks, L1_total_spks, L2_total_spks;

}  
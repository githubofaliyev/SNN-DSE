#include "top_level.h"

top_level::top_level(sc_module_name name)
: sc_module(name)
, ec_inst("ec_inst")
{
 ec_inst.clk(clk);

 // loop through the array and initialize each object for L0
 for (int i = 0; i < L0_TOTAL_AVAIL_MEM; i++) {
  // create a string with the file name
  std::string file_name = "input/weight_mem_L0_N" + std::to_string(i) + ".txt";
  // create a string with the instance name
  std::string inst_name = "L0_mem_inst" + std::to_string(i);
  // create a new memory object with the file name and instance name
  L0_mem_inst[i] = new memory(inst_name.c_str(), file_name.c_str());
  // connect the clock signal
  L0_mem_inst[i]->Clk(clk);

  // create a string with the instance name for L0_accum
  inst_name = "L0_accum_inst" + std::to_string(i);
  // create a new L0_accum object with the instance name and index
  L0_accum_inst[i] = new L0_accum(inst_name.c_str(), i);
  // connect the clock signal
  L0_accum_inst[i]->clk(clk);
  // connect the mem_port signal
  L0_accum_inst[i]->mem_port(*L0_mem_inst[i]);
 }

  for (int i = 0; i < LAYER0_SIZE_LOGICAL; i++) {
    std::string inst_name = "L0_activ_inst" + std::to_string(i);
    L0_activ_inst[i] = new L0_activ(inst_name.c_str(), i);
    L0_activ_inst[i]->clk(clk);
  }

 // similarly, loop through the array and initialize each object for L1
 for (int i = 0; i < L1_TOTAL_AVAIL_MEM; i++) {
  std::string file_name = "input/weight_mem_L1_N" + std::to_string(i) + ".txt";
  std::string inst_name = "L1_mem_inst" + std::to_string(i);
  L1_mem_inst[i] = new memory(inst_name.c_str(), file_name.c_str());
  L1_mem_inst[i]->Clk(clk);

  inst_name = "L1_accum_inst" + std::to_string(i);
  L1_accum_inst[i] = new L1_accum(inst_name.c_str(), i);
  L1_accum_inst[i]->clk(clk);
  L1_accum_inst[i]->mem_port(*L1_mem_inst[i]);

  inst_name = "L1_activ_inst" + std::to_string(i);
  L1_activ_inst[i] = new L1_activ(inst_name.c_str(), i);
  L1_activ_inst[i]->clk(clk);
 }

  for (int i = 0; i < LAYER1_SIZE_LOGICAL; i++) {
    std::string inst_name = "L1_activ_inst" + std::to_string(i);
    L1_activ_inst[i] = new L1_activ(inst_name.c_str(), i);
    L1_activ_inst[i]->clk(clk);
  }

 // similarly, loop through the array and initialize each object for L2
 for (int i = 0; i < L2_TOTAL_AVAIL_MEM; i++) {
  std::string file_name = "input/weight_mem_L2_N" + std::to_string(i) + ".txt";
  std::string inst_name = "L2_mem_inst" + std::to_string(i);
  L2_mem_inst[i] = new memory(inst_name.c_str(), file_name.c_str());
  L2_mem_inst[i]->Clk(clk);

  inst_name = "L2_accum_inst" + std::to_string(i);
  L2_accum_inst[i] = new L2_accum(inst_name.c_str(), i);
  L2_accum_inst[i]->clk(clk);
  L2_accum_inst[i]->mem_port(*L2_mem_inst[i]);
 }

  for (int i = 0; i < LAYER2_SIZE_LOGICAL; i++) {
    std::string inst_name = "L2_activ_inst" + std::to_string(i);
    L2_activ_inst[i] = new L2_activ(inst_name.c_str(), i);
    L2_activ_inst[i]->clk(clk);
  }

}

// Verilator testbench
#include <iostream>
#include <iomanip>
#include <cstdio>
#include <verilated.h>
#include "Vtop.h"
#include "svdpi.h"
#include "Vtop__Dpi.h"
#define STRINGIFY(x) #x
#define TOSTRING(x) STRINGIFY(x)
#define assertm(exp, msg) { \
  if(!(exp)) {                \
    std::cerr << "[ERROR] " << msg << std::endl; \
    assert(exp);                \
  }                           \
}

extern void toggleClock();

Vtop *top;
vluint64_t main_time;
double sc_time_stamp () {     // Called by $time in Verilog
  return main_time;           // converts to double, to match
}

void nextCycle() {
  top->clock ^= 1;
  top->eval();

  top->clock ^= 1;
  top->eval();
}

void test_rf_init() {
  top->reset = 1;
  for(int i = 0; i < 5; i++) nextCycle();

  top->reset = 0;
  nextCycle();
  nextCycle();
  nextCycle();
  nextCycle();
  for (int i = 0; i < 32; i++) {
    nextCycle();
    printf("Checking addi x%d,x%d,0 in writeback stage...\n", i, i);
    int expected_PC = 0x01000000 + 4 * (i+1);
    int expected_data = 0;
    if (i == 2) {
      expected_data = MEM_DEPTH + 0x01000000;
    }
    assertm(top->W_PC == expected_PC, "W_PC should be 0x" << 
      std::hex << std::setw(8) << std::setfill('0') << expected_PC << 
      ", got 0x" << std::setw(8) << top->W_PC);
    assertm(top->W_ENABLE == 1, "W_ENABLE should be 1, got " << std::hex << top->W_ENABLE);
    assertm(top->W_DESTINATION == i, "W_DESTINATION should be " << i << ", got " << top->W_DESTINATION);
    assertm(top->W_DATA == expected_data, "W_DATA (initial value of x" << i <<") should be 0x" <<
      std::hex << std::setw(8) << std::setfill('0') << expected_data << 
      ", got 0x" << std::setw(8) << top->W_DATA);
  }
}

int main(int argc, char** argv) {
  Verilated::commandArgs(argc, argv);   // Remember args
  top = new Vtop;

  std::string mem_path = TOSTRING(MEM_PATH);
  assertm(mem_path.find("read_rf.x") != std::string::npos, 
      "test_rf_init must run with read_rf.x");

  // set the scope correctly so that we can access the clock in C testbench
  svSetScope(svGetScopeFromName("TOP.top.clkg"));
  top->reset = 1;
  test_rf_init();

  std::cout << "Test passed" << std::endl;

  top->final();
  delete top;
  return 0;
}

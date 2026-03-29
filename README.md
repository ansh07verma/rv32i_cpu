# RV32I-Core: A Cycle-Accurate 32-bit RISC-V Processor

An industry-style, bare-metal single-cycle RISC-V (RV32I) microprocessor developed in Verilog. This repository contains the complete structural RTL datapath from Instruction Fetch to Write-Back, heavily integrated with an expanded Top-Level debug interface and driven by a SystemVerilog UVM-style automated verification suite.

## Core Features

*   **Base Integer Instruction Set (RV32I)**: Natively executes Arithmetic, Memory (Load/Store), and Branch/Jump operations without stalling.
*   **Transparent System Architecture**: Extracted 11 critical internal data/control paths directly to the top-level wrapper (`rv32i_cpu`) for unhindered waveform observability.
*   **Hardware Protection & Traps**: Embeds procedural assertions natively into the components. Implements an explicit `trap` pin that halts execution immediately upon unsupported fetches or boundary failures (e.g., zero-register immutability logic).
*   **Self-Checking Regression Suite**: `tb_phase5_top.sv` programmatically iterates through dedicated `.mem` scripts, validates memory arrays cycle-by-cycle against golden targets, dynamically restarts the CPU, and tallies `PASS/FAIL` outcomes automatically.

## Repository Structure

```text
/rv32i_cpu
├── /rtl          # Complete synthesizable Verilog datapath (ALU, Control, PC, Regfile)
├── /tb           # SystemVerilog testbenches (tb_phase5_top.sv) and module-level TBs
├── /sim          # Simulation scripts and test execution artifacts (.mem programs)
├── /docs         # Architecture diagrams, waveform exports, and theoretical analyses
└── /results      # Automated verification logs and golden output files
```

## Running the Verification Suite (Vivado)
The SystemVerilog testbench dynamically parses and loads four separate `.mem` program files (`prog_arith`, `prog_memops`, `prog_loop`, `prog_edgecases`).

To reproduce the automated checks locally using Xilinx Vivado:

1. Open a Vivado Project and expand your Tcl Console.
2. Link the working directory by adding the `/rtl` and `/tb` folders:
```tcl
# Clear out lingering files (if re-importing)
remove_files -quiet [get_files -filter {NAME =~ "*/imports/rtl/*.v"}]
# Add RTL implementation files
add_files -norecurse -scan_for_includes C:/rv32i_cpu/rtl
# Add SystemVerilog Phase 5 Master testbench
add_files -norecurse -fileset sim_1 C:/rv32i_cpu/tb/tb_phase5_top.sv
set_property file_type SystemVerilog [get_files C:/rv32i_cpu/tb/tb_phase5_top.sv]
```
3. Set the active testbench and run:
```tcl
set_property top tb_phase5_top [get_filesets sim_1]
update_compile_order -fileset sim_1
launch_simulation
```
4. Check your Tcl Console! The master testbench will iterate through all 4 test programs. If the CPU logic correctly calculates results, resolves hazards, and executes traps on edge cases, it prints:
```text
=================================================
 FINAL RV32I RTL VERIFICATION RESULTS            
 OVERALL PASS : 23                              
 OVERALL FAIL : 0                              
 PHASE 5 VERIFICATION + OPTIMIZATION COMPLETE ✓
=================================================
```

## Detailed Documentation
For an in-depth breakdown of the architecture, modules, opcodes, and testbench validation strategy, please refer to `/docs/project_detailed_documentation.md`.

## Example Visuals (Waveforms)
To graphically track the datapath signals such as jump boundaries and exception traps, add the top-level telemetry metrics provided by the wrapper:

```tcl
add_wave /tb_phase5_top/trap
add_wave -radix hex /tb_phase5_top/uut/pc_out
add_wave -radix hex /tb_phase5_top/uut/instr
add_wave -radix dec /tb_phase5_top/uut/alu_inst/result
```

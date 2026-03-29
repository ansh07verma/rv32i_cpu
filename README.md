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
The testbench dynamically parses the `.mem` files. To reproduce the automated checks locally using Xilinx Vivado:

1. Open a Vivado Project and expand your Tcl Console.
2. Link the working directory by cleaning out stagnant caches and directly referencing the `/rtl` and `/tb` folders:
```tcl
remove_files -quiet [get_files -filter {NAME =~ "*/imports/rtl/*.v"}]
add_files -norecurse -scan_for_includes C:/rv32i_cpu/rtl
add_files -norecurse -fileset sim_1 C:/rv32i_cpu/tb/tb_phase5_top.sv
set_property file_type SystemVerilog [get_files C:/rv32i_cpu/tb/tb_phase5_top.sv]
```
3. Command the compiler to build the hierarchy automatically:
```tcl
set_property top tb_phase5_top [get_filesets sim_1]
update_compile_order -fileset sim_1
launch_simulation
```
4. Check your Tcl Console! The master testbench will load the sequence, calculate the branch hazards, and if the ALU successfully decodes the negative bounds, finish with `OVERALL PASS: 23 | OVERALL FAIL: 0`.

## Example Visuals (Waveforms)
To graphically track the `ADDI` sign-extension bugs or trap assertions, add the top-level telemetry metrics:

```tcl
add_wave /tb_phase5_top/trap
add_wave /tb_phase5_top/uut/pc_out
add_wave -radix hex /tb_phase5_top/uut/instr
add_wave -radix dec /tb_phase5_top/uut/alu_inst/result
```

*Project taped out and rigorously verified via Phase 6 execution methodologies.*

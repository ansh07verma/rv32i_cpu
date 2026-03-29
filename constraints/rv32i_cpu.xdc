## ============================================================
## rv32i_cpu.xdc — Xilinx Design Constraints
## Board: Digilent Basys3 (Artix-7 xc7a35tcpg236-1)
## Project: RV32I Single-Cycle Processor
## ============================================================

## --- Onboard 100 MHz oscillator (W5) ---
set_property PACKAGE_PIN W5 [get_ports clk]
set_property IOSTANDARD LVCMOS33 [get_ports clk]
create_clock -period 10.000 -name sys_clk [get_ports clk]

## --- Reset: Center button (U18) ---
set_property PACKAGE_PIN U18 [get_ports reset]
set_property IOSTANDARD LVCMOS33 [get_ports reset]

## --- Input delay constraints for combinational paths ---
set_input_delay  -clock sys_clk -max 2.0 [get_ports reset]
set_output_delay -clock sys_clk -max 2.0 [all_outputs]

## ============================================================
## Timing Assertions (leave commented until synthesis)
## ============================================================
# set_max_delay 10.0 -datapath_only -from [get_cells pc_inst/pc_reg*] -to [get_cells *]

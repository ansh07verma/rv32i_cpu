# RV32I Single-Cycle Processor

A fully synthesizable, cycle-accurate implementation of the **RISC-V RV32I Base Integer Instruction Set** in Verilog. Built from scratch as a structural datapath — every module from the Program Counter to the Write-Back MUX is hand-coded and individually verified.

Targets the **Digilent Basys3 (Xilinx Artix-7)** FPGA and is simulated using **Xilinx Vivado xsim**.

---

## Features

- **Complete RV32I datapath** — R-type, I-type ALU, Load/Store, Branch, LUI, AUIPC, JAL, JALR
- **Harvard architecture** — separate Instruction and Data memories, fully combinational reads
- **Single-cycle execution** — every instruction completes in exactly one clock cycle (CPI = 1)
- **Hardware trap signal** — `trap` pin asserts on any illegal/undefined opcode fetch
- **x0 immutability enforcement** — register-file guard prevents writes to x0; fires a simulation assertion
- **11 debug telemetry ports** — key internal signals surfaced directly on the top-level for zero-friction Vivado waveform inspection
- **Parameterized memory** — `MEM_DEPTH` and `MEM_FILE` parameters allow any `.mem` program to be loaded at elaboration time
- **Full testbench suite** — unit tests for every module + a SystemVerilog Phase 5 master regression that auto-iterates four programs and tallies PASS/FAIL

---

## Repository Structure

```
rv32i_cpu/
├── rtl/                        # Synthesizable Verilog RTL
│   ├── rv32i_cpu.v             # Top-level structural wrapper
│   ├── pc.v                    # 32-bit Program Counter register
│   ├── imem.v                  # Instruction Memory (parameterized ROM)
│   ├── control.v               # Main Control Unit (opcode decoder)
│   ├── regfile.v               # 32 × 32-bit Register File
│   ├── imm_gen.v               # Immediate Generator (I/S/B/U/J formats)
│   ├── alu_ctrl.v              # ALU Control Sub-Decoder
│   ├── alu.v                   # 32-bit ALU (11 operations)
│   └── dmem.v                  # Data Memory (256 × 32-bit SRAM model)
│
├── tb/                         # Testbenches
│   ├── tb_phase5_top.sv        # ★ Master SystemVerilog regression (Phase 5)
│   ├── tb_phase4.v             # Multi-program Verilog testbench (Phase 4)
│   ├── tb_cpu.v                # Integration testbench (Phase 3)
│   ├── tb_alu.v                # Unit test: ALU
│   ├── tb_alu_control.v        # Unit test: ALU Control
│   ├── tb_control.v            # Unit test: Main Control Unit
│   ├── tb_dmem.v               # Unit test: Data Memory
│   ├── tb_pc.v                 # Unit test: Program Counter
│   ├── tb_regfile.v            # Unit test: Register File
│   └── tb_rv32i_cpu.v          # Smoke test
│
├── sim/
│   └── test_programs/
│       ├── prog_arith.mem      # ADD/SUB/AND/OR/XOR/SLL/SLT tests
│       ├── prog_memops.mem     # LW/SW with address offsets
│       ├── prog_loop.mem       # BEQ countdown loop (forward + backward branch)
│       ├── prog_edgecases.mem  # Traps, x0-write guard, negative immediates
│       ├── test_add.mem        # Minimal ADD smoke test
│       └── test_cpu.mem        # Phase 3 integration program
│
├── constraints/
│   └── rv32i_cpu.xdc           # Basys3 XDC (100 MHz clock, reset button)
│
└── docs/
    └── DOCUMENTATION.md        # Full technical documentation
```

---

## Architecture

The processor implements all five classic datapath stages combinationally within a single clock period. Only the PC register and register-file/data-memory write ports are clocked.

```
         ┌──────────────────────────────────────────────────────────┐
  clk ──▶│                   rv32i_cpu (top-level)                   │
reset ──▶│                                                            │
         │  ┌──────┐   ┌────────┐   ┌──────────────┐   ┌────────┐  │
         │  │  PC  │──▶│  IMEM  │──▶│   CONTROL    │   │  DMEM  │  │
         │  └──────┘   └────────┘   │  + IMM_GEN   │   └────────┘  │
         │      ▲                   └──────────────┘       ▲        │
         │      │     ┌─────────┐          │               │        │
         │      │     │ REGFILE │◀─────────┼───────────────┘        │
         │      │     └─────────┘          │                        │
         │      │           │         ┌────▼─────┐                  │
         │      │           └────────▶│ ALU_CTRL │                  │
         │      │                     │   + ALU  │                  │
         │      └─────────────────────└──────────┘                  │
         └──────────────────────────────────────────────────────────┘
```

### PC Next-Address Logic

| Condition | Next PC |
|-----------|---------|
| Normal | `PC + 4` |
| BEQ taken (`zero = 1`) | `PC + imm_ext` |
| JAL | `PC + imm_ext` |
| JALR | `rs1 + imm_ext` |

### Write-Back MUX (`result_src`)

| `result_src` | Source | Used by |
|:---:|--------|---------|
| `00` | ALU result | R-type, I-ALU, LUI, AUIPC |
| `01` | Memory read data | LOAD |
| `10` | PC + 4 | JAL, JALR (return address) |

---

## Supported Instructions

| Type | Instructions |
|------|-------------|
| **R-type** | ADD, SUB, AND, OR, XOR, SLL, SRL, SRA, SLT, SLTU |
| **I-type ALU** | ADDI, ANDI, ORI, XORI, SLTI, SLTIU, SLLI, SRLI, SRAI |
| **Load** | LW, LH, LHU, LB, LBU |
| **Store** | SW, SH, SB |
| **Branch** | BEQ, BNE, BLT, BGE, BLTU, BGEU |
| **Upper Imm** | LUI, AUIPC |
| **Jump** | JAL, JALR |
| **Illegal** | Any undefined opcode → `trap = 1` |

---

## Running Simulations (Vivado)

### Quick Start — Master Testbench

**Step 1**: Update the `.mem` file paths in `tb_phase5_top.sv` to match your local project directory.

```systemverilog
// In tb/tb_phase5_top.sv, update these paths:
string tests[] = '{
    "C:/your_path/sim/test_programs/prog_arith.mem",
    "C:/your_path/sim/test_programs/prog_memops.mem",
    "C:/your_path/sim/test_programs/prog_loop.mem",
    "C:/your_path/sim/test_programs/prog_edgecases.mem"
};
```

**Step 2**: Add sources in Vivado's Tcl Console:

```tcl
# Add all RTL files
add_files -norecurse -scan_for_includes {C:/your_path/rtl}

# Add the Phase 5 master testbench
add_files -norecurse -fileset sim_1 {C:/your_path/tb/tb_phase5_top.sv}
set_property file_type SystemVerilog [get_files tb_phase5_top.sv]
```

**Step 3**: Set top and simulate:

```tcl
set_property top tb_phase5_top [get_filesets sim_1]
update_compile_order -fileset sim_1
launch_simulation
```

**Expected output**:
```
=================================================
 FINAL RV32I RTL VERIFICATION RESULTS
 OVERALL PASS : 23
 OVERALL FAIL : 0
 VERIFICATION + OPTIMIZATION COMPLETE ✓
=================================================
```

### Running Individual Unit Tests

To run any unit testbench (e.g., ALU test):

```tcl
set_property top tb_alu [get_filesets sim_1]
launch_simulation
```

---

## Debug Waveforms

The top-level exposes 11 internal signals as named output ports. Add them to the Vivado waveform viewer without deep hierarchical paths:

```tcl
# Core execution state
add_wave -radix hex  /tb_phase5_top/uut/pc_out
add_wave -radix hex  /tb_phase5_top/uut/instr
add_wave              /tb_phase5_top/trap

# Control signals
add_wave              /tb_phase5_top/uut/dbg_reg_write
add_wave              /tb_phase5_top/uut/dbg_mem_write
add_wave              /tb_phase5_top/uut/dbg_mem_read

# Register & ALU visibility
add_wave -radix unsigned /tb_phase5_top/uut/dbg_rd
add_wave -radix hex      /tb_phase5_top/uut/dbg_alu_a
add_wave -radix hex      /tb_phase5_top/uut/dbg_alu_b
add_wave -radix hex      /tb_phase5_top/uut/dbg_alu_result
add_wave                 /tb_phase5_top/uut/dbg_zero
add_wave -radix hex      /tb_phase5_top/uut/dbg_write_data
```

---

## Test Programs

All programs are in `sim/test_programs/` as `$readmemh`-compatible hex files. Each file includes a full annotated assembly comment header.

| Program | Description | Key Checks |
|---------|-------------|------------|
| `prog_arith.mem` | Arithmetic & logic ops | x3=27, x4=13, x5=4, x7=19, x9=54, x10=1 |
| `prog_memops.mem` | Load/store round-trips | Memory address correctness, LW→register |
| `prog_loop.mem` | BEQ countdown loop (x1=4..0) | x2=10 (sum 4+3+2+1), x4=10 |
| `prog_edgecases.mem` | Traps, sign-ext, x0 guard | x1=10, x2=−5, x3=0, x4=1, trap=1 |
| `test_cpu.mem` | Phase 3 integration | ADD/SUB/SW/LW/BEQ branch-taken |
| `test_add.mem` | Minimal ADD smoke test | x1 = 5+3 = 8 |

---

## FPGA Target

| Parameter | Value |
|-----------|-------|
| Board | Digilent Basys3 |
| FPGA | Xilinx Artix-7 (xc7a35tcpg236-1) |
| Clock pin | W5 (100 MHz onboard oscillator) |
| Reset pin | U18 (center pushbutton, active-high) |
| I/O standard | LVCMOS33 |

To synthesize and implement, add `constraints/rv32i_cpu.xdc` to the constraints fileset in Vivado and set `rv32i_cpu` as the top-level synthesis module.

---

## Module Summary

| Module | Lines | Type | Role |
|--------|------:|------|------|
| `rv32i_cpu.v` | ~170 | Structural | Top-level wiring + MUX logic |
| `control.v` | ~110 | Combinational | Opcode → control signals |
| `alu_ctrl.v` | ~55 | Combinational | ALUOp + funct → alu_ctrl |
| `alu.v` | ~55 | Combinational | 32-bit arithmetic/logic |
| `imm_gen.v` | ~45 | Combinational | Immediate sign-extension |
| `regfile.v` | ~45 | Sequential (write) | 32×32 register file |
| `imem.v` | ~40 | Combinational | Instruction ROM |
| `dmem.v` | ~35 | Sequential (write) | Data SRAM model |
| `pc.v` | ~20 | Sequential | Program Counter |

---

## Known Limitations

- **Sub-word memory**: LH/LB/SH/SB are decoded but the memory model performs full 32-bit word access only (no byte-enable masking).
- **Branch conditions**: Full BEQ only via `alu_zero`. BNE/BLT/BGE require extending the branch-taken logic with `funct3` decoding.
- **JALR alignment**: The spec requires masking `pc[0]` to 0; this is not implemented.
- **No CSRs / interrupts**: `trap` is a debug output only; no machine-mode registers or interrupt routing.
- **Fixed memory size**: 256 words (1 KB) per memory. Programs must fit within this budget.
- **Absolute MEM_FILE paths**: Default parameters use Windows paths. Override `MEM_FILE` for your environment.

---

## Documentation

See [`docs/DOCUMENTATION.md`](docs/DOCUMENTATION.md) for the complete technical reference, including:
- Full datapath signal flow diagrams per instruction class
- Complete control signal truth table
- ALU control encoding table
- Immediate format bit-field diagrams
- Full RV32I instruction reference with funct3/funct7 decode
- Testbench strategy and assertion methodology
- Design decision rationale

---

## References

- [The RISC-V Instruction Set Manual, Volume I: Unprivileged ISA](https://riscv.org/specifications/)
- Harris, D. & Harris, S. — *Digital Design and Computer Architecture: RISC-V Edition* (Morgan Kaufmann, 2021)
- [Digilent Basys3 Reference Manual](https://digilent.com/reference/programmable-logic/basys-3/reference-manual)
- [Xilinx Vivado Design Suite User Guide](https://www.xilinx.com/support/documentation-navigation/design-hubs/dh0013-vivado-installation-and-licensing-hub.html)

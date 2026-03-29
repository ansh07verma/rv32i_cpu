# RV32I Single-Cycle Processor — Complete Technical Documentation

> **Project**: RV32I Single-Cycle CPU in Verilog  
> **Target Board**: Digilent Basys3 (Xilinx Artix-7 xc7a35tcpg236-1)  
> **Tool**: Xilinx Vivado + xsim  
> **Language**: Verilog (RTL) + SystemVerilog (Testbenches)  
> **Architecture**: Harvard, single-cycle, 5-stage combinational datapath

---

## Table of Contents

1. [Project Overview](#1-project-overview)
2. [Repository Structure](#2-repository-structure)
3. [Architecture Overview](#3-architecture-overview)
4. [Module Reference](#4-module-reference)
   - 4.1 [rv32i_cpu.v — Top-Level](#41-rv32i_cpuv--top-level)
   - 4.2 [pc.v — Program Counter](#42-pcv--program-counter)
   - 4.3 [imem.v — Instruction Memory](#43-imemv--instruction-memory)
   - 4.4 [control.v — Main Control Unit](#44-controlv--main-control-unit)
   - 4.5 [regfile.v — Register File](#45-regfilev--register-file)
   - 4.6 [imm_gen.v — Immediate Generator](#46-imm_genv--immediate-generator)
   - 4.7 [alu_ctrl.v — ALU Control Sub-Decoder](#47-alu_ctrlv--alu-control-sub-decoder)
   - 4.8 [alu.v — Arithmetic Logic Unit](#48-aluv--arithmetic-logic-unit)
   - 4.9 [dmem.v — Data Memory](#49-dmemv--data-memory)
5. [Datapath Signal Flow](#5-datapath-signal-flow)
6. [Control Signal Table](#6-control-signal-table)
7. [ALU Control Encoding](#7-alu-control-encoding)
8. [Immediate Format Encoding](#8-immediate-format-encoding)
9. [Supported Instruction Set (RV32I)](#9-supported-instruction-set-rv32i)
10. [Debug / Telemetry Interface](#10-debug--telemetry-interface)
11. [Test Programs](#11-test-programs)
12. [Testbench Suite](#12-testbench-suite)
13. [FPGA Constraints](#13-fpga-constraints)
14. [Design Decisions & Notes](#14-design-decisions--notes)
15. [Known Limitations](#15-known-limitations)

---

## 1. Project Overview

This project implements a fully functional, synthesizable single-cycle processor compliant with the **RISC-V RV32I Base Integer Instruction Set**. The design follows a classic Harvard architecture where instruction memory and data memory are separate, allowing both to be accessed simultaneously within a single clock cycle.

Every instruction — from fetch through write-back — completes in exactly **one clock cycle**. There are no pipeline stages, hazard detection units, or stall logic. This makes the design easy to reason about, simulate, and synthesize to an FPGA.

The project was developed in five phases:
| Phase | Focus |
|-------|-------|
| 1 | Individual module implementation (ALU, Regfile, PC) |
| 2 | Immediate generator, control unit |
| 3 | Full datapath integration (Phase 3 integration testbench) |
| 4 | Multi-program regression (arithmetic, memory ops, loops) |
| 5 | Edge-case hardening, trap logic, SystemVerilog UVM-style testbench |

---

## 2. Repository Structure

```
rv32i_cpu/
├── rtl/                        # Synthesizable RTL (Verilog)
│   ├── rv32i_cpu.v             # Top-level structural wrapper
│   ├── pc.v                    # Program Counter register
│   ├── imem.v                  # Instruction Memory (parameterized ROM)
│   ├── control.v               # Main Control Unit (opcode decoder)
│   ├── regfile.v               # 32×32-bit Register File
│   ├── imm_gen.v               # Immediate Generator (I/S/B/U/J formats)
│   ├── alu_ctrl.v              # ALU Control Sub-Decoder
│   ├── alu.v                   # 32-bit ALU (11 operations)
│   └── dmem.v                  # Data Memory (256×32-bit SRAM model)
│
├── tb/                         # Testbenches
│   ├── tb_phase5_top.sv        # ★ Master SystemVerilog regression suite (Phase 5)
│   ├── tb_phase4.v             # Multi-program testbench (Phase 4)
│   ├── tb_cpu.v                # Phase 3 integration testbench
│   ├── tb_alu.v                # Unit test: ALU
│   ├── tb_alu_control.v        # Unit test: ALU Control decoder
│   ├── tb_control.v            # Unit test: Main Control Unit
│   ├── tb_dmem.v               # Unit test: Data Memory
│   ├── tb_pc.v                 # Unit test: Program Counter
│   ├── tb_regfile.v            # Unit test: Register File
│   └── tb_rv32i_cpu.v          # Lightweight smoke-test
│
├── sim/
│   └── test_programs/
│       ├── prog_arith.mem      # Arithmetic test: ADD/SUB/AND/OR/XOR/SLL/SLT
│       ├── prog_memops.mem     # Memory test: LW/SW with address offsets
│       ├── prog_loop.mem       # Branch test: BEQ countdown loop
│       ├── prog_edgecases.mem  # Edge-case test: traps, x0 protection, sign-ext
│       ├── test_add.mem        # Minimal ADD smoke test
│       └── test_cpu.mem        # Phase 3 integration test program
│
├── constraints/
│   └── rv32i_cpu.xdc           # Vivado XDC constraints (Basys3 board)
│
└── docs/
    └── project_detailed_documentation.md
```

---

## 3. Architecture Overview

The processor implements a classic **five-stage datapath** — all stages execute combinationally within a single clock period. State is captured only at the **Program Counter** (clocked register) and the **Register File / Data Memory** write ports (synchronous writes on `posedge clk`).

```
 ┌──────┐    ┌──────┐    ┌──────────┐    ┌──────┐    ┌──────────┐
 │  IF  │───▶│  ID  │───▶│    EX    │───▶│  MA  │───▶│    WB    │
 │      │    │      │    │          │    │      │    │          │
 │ imem │    │regfile    │   ALU    │    │ dmem │    │ WB MUX   │
 │  pc  │    │control    │alu_ctrl  │    │      │    │ → regfile│
 └──────┘    │imm_gen│   │          │    └──────┘    └──────────┘
             └──────┘    └──────────┘
```

### Key Datapath Connections

| Signal | From | To | Purpose |
|--------|------|----|---------|
| `pc_out` | PC | IMEM, branch adder | Current instruction address |
| `instr[31:0]` | IMEM | All decode logic | Raw 32-bit instruction word |
| `opcode[6:0]` | instr[6:0] | control | Instruction type decode |
| `funct3[2:0]` | instr[14:12] | alu_ctrl | Operation refinement |
| `funct7_5` | instr[30] | alu_ctrl | ADD/SUB, SRL/SRA disambiguation |
| `rs1_data` | regfile | ALU operand A | First source register value |
| `rs2_data` | regfile | ALU B MUX, dmem.wd | Second source register value |
| `imm_ext` | imm_gen | ALU B MUX, PC adder | Sign-extended immediate |
| `alu_result` | ALU | dmem.addr, WB MUX | Computed address or value |
| `alu_zero` | ALU | branch logic | BEQ condition flag |
| `mem_read_data` | dmem | WB MUX | Loaded data |
| `write_data` | WB MUX | regfile.wd | Data written to destination register |
| `pc_next` | PC MUX | PC | Next program counter value |

### PC Next-Address Logic

```verilog
assign pc_plus4      = pc_out + 32'd4;
assign pc_branch     = pc_out + imm_ext;           // branch / JAL target
assign pc_src_branch = branch & alu_zero;           // BEQ taken when zero flag
assign pc_src        = (jump | pc_src_branch) ? 2'b01 : 2'b00;
assign pc_next       = (pc_src == 2'b01) ? pc_branch : pc_plus4;
```

| Condition | `pc_next` |
|-----------|-----------|
| Normal sequential | `PC + 4` |
| BEQ taken (zero=1) | `PC + imm_ext` |
| JAL / JALR | `PC + imm_ext` (JAL) or `rs1 + imm_ext` (JALR) |

### Write-Back MUX

```verilog
assign write_data = (result_src == 2'b00) ? alu_result    :  // R-type, I-ALU, LUI, AUIPC
                    (result_src == 2'b01) ? mem_read_data  :  // Load
                                            pc_plus4;         // JAL/JALR (link address)
```

---

## 4. Module Reference

### 4.1 `rv32i_cpu.v` — Top-Level

**File**: `rtl/rv32i_cpu.v`

The structural top-level wrapper. Instantiates all sub-modules and wires the complete datapath. Contains only combinational glue logic (MUXes, field extractions) — no sequential logic resides here.

#### Parameters

| Parameter | Default | Description |
|-----------|---------|-------------|
| `MEM_DEPTH` | `256` | Number of 32-bit words in IMEM and DMEM (1 KB each) |
| `MEM_FILE` | `"C:/rv32i_cpu/sim/test_programs/prog_arith.mem"` | Absolute path to `.mem` program image loaded at simulation start |

#### Ports

| Port | Direction | Width | Description |
|------|-----------|-------|-------------|
| `clk` | input | 1 | System clock (100 MHz on Basys3) |
| `reset` | input | 1 | Synchronous reset; clears PC to 0x00000000 |
| `trap` | output | 1 | Asserted when an illegal/undefined opcode is fetched |
| `dbg_reg_write` | output | 1 | Debug: RegWrite control signal |
| `dbg_mem_read` | output | 1 | Debug: active when WB MUX selects memory data |
| `dbg_mem_write` | output | 1 | Debug: MemWrite control signal |
| `dbg_rd` | output | 5 | Debug: destination register address |
| `dbg_rs1` | output | 5 | Debug: source register 1 address |
| `dbg_rs2` | output | 5 | Debug: source register 2 address |
| `dbg_write_data` | output | 32 | Debug: data being written to register file |
| `dbg_alu_a` | output | 32 | Debug: ALU operand A (rs1_data) |
| `dbg_alu_b` | output | 32 | Debug: ALU operand B (after MUX) |
| `dbg_alu_result` | output | 32 | Debug: ALU computed result |
| `dbg_zero` | output | 1 | Debug: ALU zero flag |

---

### 4.2 `pc.v` — Program Counter

**File**: `rtl/pc.v`

A simple 32-bit D flip-flop. Captures `pc_next` on every rising clock edge. Resets to `0x00000000` on `reset`.

```verilog
always @(posedge clk or posedge reset) begin
    if (reset)  pc <= 32'h00000000;
    else        pc <= pc_next;
end
```

| Port | Direction | Width | Description |
|------|-----------|-------|-------------|
| `clk` | input | 1 | Clock |
| `reset` | input | 1 | Async reset (drives pc to 0) |
| `pc_next` | input | 32 | Next PC value from top-level MUX |
| `pc` | output | 32 | Current PC (byte address) |

---

### 4.3 `imem.v` — Instruction Memory

**File**: `rtl/imem.v`

A **parameterized combinational ROM**. The memory array is initialized from a `.mem` file at simulation startup using `$readmemh`. On FPGA, this synthesizes to Block RAM or distributed RAM initialized with the program image.

#### Key Design Details
- **Word-addressed**: `addr[9:2]` selects the 32-bit word (byte address >> 2). Upper bits are ignored at default depth of 256.
- **Pre-initialized**: All locations are zeroed to `32'h0000_0013` (NOP: `ADDI x0, x0, 0`) before `$readmemh` overwrites the program region.
- **Combinational read**: No clock required; instruction is available in the same cycle as the address.

| Port | Direction | Width | Description |
|------|-----------|-------|-------------|
| `addr` | input | 32 | Byte address (from `pc_out`) |
| `instr` | output | 32 | Instruction word at `mem[addr[9:2]]` |

---

### 4.4 `control.v` — Main Control Unit

**File**: `rtl/control.v`

A **purely combinational** opcode decoder. Receives the 7-bit `opcode` field and drives all datapath control signals. Uses `default: safe` assignments at the top of the `always @(*)` block to prevent synthesis latches.

#### Decoded Opcodes

| `opcode[6:0]` | Constant | Instruction Type |
|---------------|----------|-----------------|
| `7'b0110011` | `OP_RTYPE` | R-type (ADD, SUB, AND, OR, XOR, SLL, SLT, SLTU) |
| `7'b0010011` | `OP_IALU` | I-type ALU (ADDI, ANDI, ORI, XORI, SLTI, SLLI, SRLI, SRAI) |
| `7'b0000011` | `OP_LOAD` | Loads (LW, LH, LB, LHU, LBU) |
| `7'b0100011` | `OP_STORE` | Stores (SW, SH, SB) |
| `7'b1100011` | `OP_BRANCH` | Branches (BEQ, BNE, BLT, BGE, BLTU, BGEU) |
| `7'b0110111` | `OP_LUI` | LUI (Load Upper Immediate) |
| `7'b0010111` | `OP_AUIPC` | AUIPC (Add Upper Immediate to PC) |
| `7'b1101111` | `OP_JAL` | JAL (Jump and Link) |
| `7'b1100111` | `OP_JALR` | JALR (Jump and Link Register) |
| `default` | — | Illegal → `trap = 1` |

#### Ports

| Port | Direction | Width | Description |
|------|-----------|-------|-------------|
| `opcode` | input | 7 | `instr[6:0]` |
| `reg_write` | output | 1 | Enable write to register file |
| `imm_src` | output | 3 | Immediate format selector (→ imm_gen) |
| `alu_src` | output | 1 | ALU B operand: 0 = rs2, 1 = imm_ext |
| `mem_write` | output | 1 | Enable write to data memory |
| `result_src` | output | 2 | WB MUX select: 00=ALU, 01=MEM, 10=PC+4 |
| `branch` | output | 1 | Instruction is a branch |
| `jump` | output | 1 | Instruction is an unconditional jump |
| `alu_op` | output | 3 | 3-bit hint to ALU control sub-decoder |
| `trap` | output | 1 | Illegal instruction detected |

---

### 4.5 `regfile.v` — Register File

**File**: `rtl/regfile.v`

Implements the **32 × 32-bit general-purpose register file** required by the RISC-V specification.

#### Key Properties
- **Two asynchronous read ports** (`rs1`, `rs2`): combinationally return register data with no clock dependency.
- **One synchronous write port** (`rd`): writes occur on `posedge clk` when `we = 1`.
- **x0 is hardwired to zero**: reads from `rs1=0` or `rs2=0` always return `32'b0`. Writes to `rd=0` are silently dropped; a `$error` assertion fires in simulation to flag the erroneous write attempt.
- **Zero-initialized**: all 32 registers start at `0` via an `initial` block.

| Port | Direction | Width | Description |
|------|-----------|-------|-------------|
| `clk` | input | 1 | Clock |
| `we` | input | 1 | Write enable (RegWrite) |
| `rs1` | input | 5 | Read address 1 |
| `rs2` | input | 5 | Read address 2 |
| `rd` | input | 5 | Write address |
| `wd` | input | 32 | Write data |
| `rd1` | output | 32 | Read data 1 |
| `rd2` | output | 32 | Read data 2 |

---

### 4.6 `imm_gen.v` — Immediate Generator

**File**: `rtl/imm_gen.v`

Sign-extends the raw immediate bits embedded in the instruction word according to the RISC-V encoding format selected by `imm_src` from the control unit.

#### Immediate Formats

| `imm_src` | Format | Used By | Bit Assembly |
|-----------|--------|---------|-------------|
| `3'b000` | **I-type** | ADDI, LW, JALR | `{sign×20, instr[31:20]}` |
| `3'b001` | **S-type** | SW, SH, SB | `{sign×20, instr[31:25], instr[11:7]}` |
| `3'b010` | **B-type** | BEQ, BNE, BLT | `{sign×19, instr[31], instr[7], instr[30:25], instr[11:8], 1'b0}` |
| `3'b011` | **U-type** | LUI, AUIPC | `{instr[31:12], 12'b0}` |
| `3'b100` | **J-type** | JAL | `{sign×11, instr[31], instr[19:12], instr[20], instr[30:21], 1'b0}` |

The LSB of B-type and J-type immediates is hardwired to `1'b0` — branch/jump targets are always even (2-byte aligned), enforcing the RISC-V spec.

---

### 4.7 `alu_ctrl.v` — ALU Control Sub-Decoder

**File**: `rtl/alu_ctrl.v`

A secondary decoder that narrows the coarse `alu_op` signal from the main control unit down to a precise 4-bit `alu_ctrl` operation code for the ALU. This two-level decode structure keeps `control.v` from needing per-instruction knowledge of `funct3`/`funct7`.

Uses `casex` matching on `{alu_op[2:0], funct3[2:0], funct7_5}` (7 bits total).

#### ALU_OP Meanings

| `alu_op` | Meaning | Details |
|----------|---------|---------|
| `3'b000` | Force ADD | Used for LOAD, STORE, AUIPC, JAL address computation |
| `3'b001` | Force SUB | Used for BRANCH (compare by subtraction) |
| `3'b010` | R-type | funct3 + funct7_5 determine exact operation |
| `3'b011` | I-type ALU | funct3 determines operation; funct7_5 ignored for ADDI |
| `3'b100` | LUI pass | Forces `ALU_LUI` (pass B operand through unchanged) |

---

### 4.8 `alu.v` — Arithmetic Logic Unit

**File**: `rtl/alu.v`

A 32-bit combinational ALU implementing 11 distinct operations. Operation selection is driven by the 4-bit `alu_ctrl` signal from `alu_ctrl.v`.

#### Operation Table

| `alu_ctrl` | Mnemonic | Operation |
|------------|----------|-----------|
| `4'b0000` | `ALU_ADD` | `a + b` |
| `4'b0001` | `ALU_SUB` | `a - b` |
| `4'b0010` | `ALU_AND` | `a & b` |
| `4'b0011` | `ALU_OR` | `a \| b` |
| `4'b0100` | `ALU_XOR` | `a ^ b` |
| `4'b0101` | `ALU_SLL` | `a << b[4:0]` (logical left shift) |
| `4'b0110` | `ALU_SRL` | `a >> b[4:0]` (logical right shift) |
| `4'b0111` | `ALU_SRA` | `$signed(a) >>> b[4:0]` (arithmetic right shift) |
| `4'b1000` | `ALU_SLT` | `($signed(a) < $signed(b)) ? 1 : 0` |
| `4'b1001` | `ALU_SLTU` | `(a < b) ? 1 : 0` (unsigned) |
| `4'b1010` | `ALU_LUI` | `b` (pass-through for LUI) |

The `zero` output flag (`result == 0`) drives the branch-taken logic in the top-level for BEQ.

A `$error` assertion fires in simulation on any undefined `alu_ctrl` value.

---

### 4.9 `dmem.v` — Data Memory

**File**: `rtl/dmem.v`

A **256 × 32-bit synchronous-write, asynchronous-read SRAM model**.

- **Synchronous write**: Data is written on `posedge clk` when `we = 1`.
- **Asynchronous read**: `rd` reflects `mem[addr[9:2]]` combinationally (available within the same cycle).
- **Word-addressed**: byte address bit-2 upward indexes the word (`addr[9:2]`), consistent with IMEM.
- Zero-initialized via `initial` block.

| Port | Direction | Width | Description |
|------|-----------|-------|-------------|
| `clk` | input | 1 | Clock |
| `we` | input | 1 | Write enable (MemWrite) |
| `addr` | input | 32 | Byte address (from ALU result) |
| `wd` | input | 32 | Write data (rs2_data) |
| `rd` | output | 32 | Read data (to WB MUX) |

> **Note**: The current implementation treats all loads/stores as full 32-bit word operations. Sub-word accesses (LH, LB, SH, SB) are decoded in the control unit but the memory model does not perform byte/half-word masking — this is a known simplification.

---

## 5. Datapath Signal Flow

Below is the complete combinational signal flow for each instruction class:

### R-Type (e.g., `ADD x3, x1, x2`)
```
IMEM[PC] → instr
instr[6:0]   → opcode → control: reg_write=1, alu_src=0, result_src=00, alu_op=010
instr[19:15] → rs1 → regfile → rs1_data → ALU.a
instr[24:20] → rs2 → regfile → rs2_data → ALU.b (alu_src=0)
funct3, funct7_5 + alu_op=010 → alu_ctrl → ALU operation
ALU.result → write_data (result_src=00) → regfile[rd]
PC ← PC + 4
```

### Load (`LW x5, 8(x1)`)
```
instr → opcode=LOAD → control: reg_write=1, alu_src=1, result_src=01, alu_op=000
instr[31:20] → imm_gen (I-type) → imm_ext=8
rs1_data (x1 value) + imm_ext (8) → ALU ADD → addr
dmem[addr] → mem_read_data → write_data (result_src=01) → regfile[rd]
PC ← PC + 4
```

### Store (`SW x5, 12(x2)`)
```
instr → opcode=STORE → control: reg_write=0, mem_write=1, alu_src=1, alu_op=000
instr S-type imm → imm_gen → imm_ext=12
rs1_data (x2) + imm_ext (12) → ALU ADD → addr
rs2_data (x5) → dmem.wd; dmem[addr] ← wd on posedge clk
PC ← PC + 4
```

### Branch (`BEQ x1, x2, offset`)
```
instr → opcode=BRANCH → control: branch=1, alu_src=0, alu_op=001 (SUB)
rs1_data - rs2_data → ALU → result; zero = (result==0)
pc_src_branch = branch & zero
if taken: PC ← PC + imm_ext (B-type)
else:     PC ← PC + 4
```

### JAL (`JAL x1, offset`)
```
instr → opcode=JAL → control: jump=1, reg_write=1, result_src=10
PC + 4 → write_data → regfile[rd=x1]  (return address saved)
PC ← PC + imm_ext (J-type)
```

---

## 6. Control Signal Table

Complete control signal outputs from `control.v` for every supported opcode:

| Instruction | `reg_write` | `imm_src` | `alu_src` | `mem_write` | `result_src` | `branch` | `jump` | `alu_op` | `trap` |
|-------------|:-----------:|:---------:|:---------:|:-----------:|:------------:|:--------:|:------:|:--------:|:------:|
| R-type | 1 | — | 0 | 0 | 00 | 0 | 0 | 010 | 0 |
| I-ALU | 1 | 000 | 1 | 0 | 00 | 0 | 0 | 011 | 0 |
| LOAD | 1 | 000 | 1 | 0 | 01 | 0 | 0 | 000 | 0 |
| STORE | 0 | 001 | 1 | 1 | — | 0 | 0 | 000 | 0 |
| BRANCH | 0 | 010 | 0 | 0 | — | 1 | 0 | 001 | 0 |
| LUI | 1 | 011 | 1 | 0 | 00 | 0 | 0 | 100 | 0 |
| AUIPC | 1 | 011 | 1 | 0 | 00 | 0 | 0 | 000 | 0 |
| JAL | 1 | 100 | — | 0 | 10 | 0 | 1 | 000 | 0 |
| JALR | 1 | 000 | 1 | 0 | 10 | 0 | 1 | 000 | 0 |
| Illegal | 0 | — | — | 0 | — | 0 | 0 | — | **1** |

---

## 7. ALU Control Encoding

The `alu_ctrl.v` module uses a 7-bit `casex` key: `{alu_op[2:0], funct3[2:0], funct7_5}`.

| Key (7-bit) | Instruction | `alu_ctrl` Output |
|-------------|-------------|:-----------------:|
| `000_xxx_x` | Force ADD (LOAD/STORE) | `0000` |
| `001_xxx_x` | Force SUB (BRANCH) | `0001` |
| `100_xxx_x` | LUI pass-through | `1010` |
| `010_000_0` | ADD (R-type) | `0000` |
| `010_000_1` | SUB (R-type) | `0001` |
| `010_001_x` | SLL | `0101` |
| `010_010_x` | SLT | `1000` |
| `010_011_x` | SLTU | `1001` |
| `010_100_x` | XOR | `0100` |
| `010_101_0` | SRL | `0110` |
| `010_101_1` | SRA | `0111` |
| `010_110_x` | OR | `0011` |
| `010_111_x` | AND | `0010` |
| `011_000_x` | ADDI | `0000` |
| `011_001_x` | SLLI | `0101` |
| `011_010_x` | SLTI | `1000` |
| `011_011_x` | SLTIU | `1001` |
| `011_100_x` | XORI | `0100` |
| `011_101_0` | SRLI | `0110` |
| `011_101_1` | SRAI | `0111` |
| `011_110_x` | ORI | `0011` |
| `011_111_x` | ANDI | `0010` |

---

## 8. Immediate Format Encoding

Reference for how each RISC-V immediate format extracts bits from the 32-bit instruction:

| Format | `imm_src` | Bits Used | Sign Extension |
|--------|:---------:|-----------|:--------------:|
| I-type | `000` | `instr[31:20]` | `instr[31]` × 20 |
| S-type | `001` | `instr[31:25]`, `instr[11:7]` | `instr[31]` × 20 |
| B-type | `010` | `instr[31]`, `instr[7]`, `instr[30:25]`, `instr[11:8]`, `0` | `instr[31]` × 19 |
| U-type | `011` | `instr[31:12]`, `12'b0` | None (upper 20 bits) |
| J-type | `100` | `instr[31]`, `instr[19:12]`, `instr[20]`, `instr[30:21]`, `0` | `instr[31]` × 11 |

---

## 9. Supported Instruction Set (RV32I)

### R-Type (opcode `0110011`)
| Instruction | funct3 | funct7[5] | Operation |
|-------------|:------:|:---------:|-----------|
| ADD rd, rs1, rs2 | 000 | 0 | rd = rs1 + rs2 |
| SUB rd, rs1, rs2 | 000 | 1 | rd = rs1 − rs2 |
| AND rd, rs1, rs2 | 111 | 0 | rd = rs1 & rs2 |
| OR rd, rs1, rs2 | 110 | 0 | rd = rs1 \| rs2 |
| XOR rd, rs1, rs2 | 100 | 0 | rd = rs1 ^ rs2 |
| SLL rd, rs1, rs2 | 001 | 0 | rd = rs1 << rs2[4:0] |
| SRL rd, rs1, rs2 | 101 | 0 | rd = rs1 >> rs2[4:0] (logical) |
| SRA rd, rs1, rs2 | 101 | 1 | rd = rs1 >>> rs2[4:0] (arithmetic) |
| SLT rd, rs1, rs2 | 010 | 0 | rd = (signed rs1 < signed rs2) ? 1 : 0 |
| SLTU rd, rs1, rs2 | 011 | 0 | rd = (rs1 < rs2) ? 1 : 0 (unsigned) |

### I-Type ALU (opcode `0010011`)
| Instruction | funct3 | Operation |
|-------------|:------:|-----------|
| ADDI rd, rs1, imm | 000 | rd = rs1 + sign_ext(imm) |
| ANDI rd, rs1, imm | 111 | rd = rs1 & sign_ext(imm) |
| ORI rd, rs1, imm | 110 | rd = rs1 \| sign_ext(imm) |
| XORI rd, rs1, imm | 100 | rd = rs1 ^ sign_ext(imm) |
| SLTI rd, rs1, imm | 010 | rd = (signed rs1 < signed imm) ? 1 : 0 |
| SLTIU rd, rs1, imm | 011 | rd = (rs1 < imm) ? 1 : 0 (unsigned) |
| SLLI rd, rs1, shamt | 001 | rd = rs1 << shamt |
| SRLI rd, rs1, shamt | 101 (funct7_5=0) | rd = rs1 >> shamt (logical) |
| SRAI rd, rs1, shamt | 101 (funct7_5=1) | rd = rs1 >>> shamt (arithmetic) |

### Load (opcode `0000011`)
| Instruction | funct3 | Description |
|-------------|:------:|-------------|
| LW rd, imm(rs1) | 010 | Load word (32-bit) |
| LH rd, imm(rs1) | 001 | Load halfword (sign-extend) |
| LHU rd, imm(rs1) | 101 | Load halfword (zero-extend) |
| LB rd, imm(rs1) | 000 | Load byte (sign-extend) |
| LBU rd, imm(rs1) | 100 | Load byte (zero-extend) |

*Note: Sub-word masking is decoded by control but memory model performs 32-bit word access only.*

### Store (opcode `0100011`)
| Instruction | funct3 | Description |
|-------------|:------:|-------------|
| SW rs2, imm(rs1) | 010 | Store word |
| SH rs2, imm(rs1) | 001 | Store halfword |
| SB rs2, imm(rs1) | 000 | Store byte |

### Branch (opcode `1100011`)
| Instruction | funct3 | Condition |
|-------------|:------:|-----------|
| BEQ rs1, rs2, offset | 000 | branch if rs1 == rs2 |
| BNE rs1, rs2, offset | 001 | branch if rs1 ≠ rs2 |
| BLT rs1, rs1, offset | 100 | branch if signed rs1 < rs2 |
| BGE rs1, rs2, offset | 101 | branch if signed rs1 ≥ rs2 |
| BLTU rs1, rs2, offset | 110 | branch if unsigned rs1 < rs2 |
| BGEU rs1, rs2, offset | 111 | branch if unsigned rs1 ≥ rs2 |

*Note: Current branch evaluation uses `alu_zero` flag only (BEQ semantics). BNE/BLT/BGE are decoded by control but the branch-taken mux uses only `zero`. Full branch condition decoding is a pending enhancement.*

### Upper Immediate & Jump
| Instruction | Type | Operation |
|-------------|------|-----------|
| LUI rd, imm | U | rd = {imm[31:12], 12'b0} |
| AUIPC rd, imm | U | rd = PC + {imm[31:12], 12'b0} |
| JAL rd, offset | J | rd = PC+4; PC = PC + sign_ext(offset) |
| JALR rd, rs1, imm | I | rd = PC+4; PC = (rs1 + sign_ext(imm)) & ~1 |

---

## 10. Debug / Telemetry Interface

The top-level module exposes 11 internal datapath signals directly as output ports, eliminating the need for deep hierarchical probing in Vivado:

```verilog
output wire        dbg_reg_write,   // RegWrite flag
output wire        dbg_mem_read,    // 1 when result_src==01 (memory load active)
output wire        dbg_mem_write,   // MemWrite flag
output wire [4:0]  dbg_rd,          // Destination register [rd]
output wire [4:0]  dbg_rs1,         // Source register 1 [rs1]
output wire [4:0]  dbg_rs2,         // Source register 2 [rs2]
output wire [31:0] dbg_write_data,  // Data going into register file
output wire [31:0] dbg_alu_a,       // ALU operand A
output wire [31:0] dbg_alu_b,       // ALU operand B (post-MUX)
output wire [31:0] dbg_alu_result,  // ALU output
output wire        dbg_zero         // ALU zero flag
```

### Adding to Vivado Waveform

```tcl
add_wave /tb_phase5_top/trap
add_wave -radix hex /tb_phase5_top/uut/pc_out
add_wave -radix hex /tb_phase5_top/uut/instr
add_wave -radix dec /tb_phase5_top/uut/dbg_alu_result
add_wave /tb_phase5_top/uut/dbg_reg_write
add_wave /tb_phase5_top/uut/dbg_mem_write
add_wave -radix unsigned /tb_phase5_top/uut/dbg_rd
add_wave -radix hex /tb_phase5_top/uut/dbg_write_data
```

---

## 11. Test Programs

Located in `sim/test_programs/`. All files are in `$readmemh` hex format (one 32-bit word per line, MSB first). Comments in each file provide an annotated assembly listing with expected register values.

### `prog_arith.mem` — Arithmetic Validation
Tests all R-type and I-type ALU operations:
- ADDI x1=20, x2=7
- ADD x3=27, SUB x4=13
- AND x5=4, OR x6=23, XOR x7=19
- ADDI x8=1
- SLL x9 = 27 << 1 = 54
- SLT x10: verifies signed comparison (both true and false cases)

**Expected final state**: x1=20, x2=7, x3=27, x4=13, x5=4, x6=23, x7=19, x8=1, x9=54, x10=1

### `prog_memops.mem` — Memory Operations
Tests load/store addressing with multiple offsets:
- Stores values to consecutive memory addresses
- Reloads values and verifies round-trip correctness
- Tests address calculation accuracy (rs1 + imm)

### `prog_loop.mem` — Branch Loop
Implements a BEQ-based countdown:
- x1 = 4 (counter), x2 = 0 (accumulator), x3 = 1 (step)
- Loop: x2 += x1; x1 -= x3; BEQ x1, x0, EXIT; (always-taken back-branch)
- Expected: x2 = 4+3+2+1 = 10, x4 = 10 (saved result)

Tests both forward branches (exit condition) and backward branches (loop body).

### `prog_edgecases.mem` — Edge Cases & Trap
```
0x00: ADDI x0, x0, 10   → triggers $error in regfile (x0 write attempt)
0x04: ADDI x1, x0, 10   → x1 = 10 (normal)
0x08: ADDI x2, x0, -5   → x2 = -5 (sign-extension verification)
0x0C: SLT  x3, x1, x2   → x3 = 0 (10 < -5 is FALSE)
0x10: SLT  x4, x2, x1   → x4 = 1 (-5 < 10 is TRUE)
0x14: 0xFFFFFFFF         → ILLEGAL opcode → trap = 1
0x18: BEQ x1, x1, -4    → infinite loop (never reached post-trap)
```

### `test_cpu.mem` — Phase 3 Integration
11-instruction sequence validating the core integration: ADDI, ADD, SW, LW, SUB, BEQ (taken), skipped ADDI, ADDI, NOPs.

### `test_add.mem` — Minimal Smoke Test
Minimal sequence for a quick ADD sanity check during early bringup.

---

## 12. Testbench Suite

### `tb_phase5_top.sv` ★ Master Testbench (Phase 5)
**Language**: SystemVerilog  
**Purpose**: Full automated regression across all four test programs.

Features:
- **Dynamic program loading**: uses a string array of `.mem` paths and `$readmemh` to reload IMEM for each program without re-elaboration.
- **Self-checking tasks**: `check_reg(rn, expected, label)` and `check_mem(addr, expected, label)` compare actual CPU state against golden values and tally PASS/FAIL.
- **Trap detection**: the stepper task monitors `trap` and logs exceptions rather than hanging.
- **Global scoreboard**: `pass_cnt` and `fail_cnt` are accumulated across all programs; final summary is printed.

Expected final output:
```
=================================================
 FINAL RV32I RTL VERIFICATION RESULTS            
 OVERALL PASS : 23                              
 OVERALL FAIL : 0                              
 PHASE 5 VERIFICATION + OPTIMIZATION COMPLETE ✓
=================================================
```

### `tb_phase4.v` — Multi-Program Verilog Testbench
Three separate Verilog modules (`tb_arith`, `tb_memops`, `tb_loop`), each instantiating one DUT with one program. Each module includes a per-negedge `$display` monitor and a `pass_cnt`/`fail_cnt` scoreboard.

### `tb_cpu.v` — Phase 3 Integration
Step-by-step assertion of the 11-instruction `test_cpu.mem` program. Verifies BEQ branch-taken behavior, store/load round-trip, and instruction skipping.

### Unit Testbenches
| File | DUT | Coverage |
|------|-----|---------|
| `tb_alu.v` | `alu` | All 11 ALU operations, zero-flag, edge values |
| `tb_alu_control.v` | `alu_ctrl` | All valid alu_op + funct3 + funct7 combinations |
| `tb_control.v` | `control` | All 9 opcodes + illegal opcode trap |
| `tb_dmem.v` | `dmem` | Read/write, word addressing, zero-init |
| `tb_pc.v` | `pc` | Reset, sequential increment, arbitrary load |
| `tb_regfile.v` | `regfile` | All 32 registers, x0 immutability, read/write same cycle |

---

## 13. FPGA Constraints

**File**: `constraints/rv32i_cpu.xdc`  
**Target**: Digilent Basys3 (Artix-7 xc7a35tcpg236-1)

```
Clock source : W5  (onboard 100 MHz oscillator)
Reset        : U18 (center pushbutton, active-high)
I/O standard : LVCMOS33
Clock period : 10.000 ns (100 MHz, → create_clock)
```

Timing constraint commands:
```tcl
set_input_delay  -clock sys_clk -max 2.0 [get_ports reset]
set_output_delay -clock sys_clk -max 2.0 [all_outputs]
```

> A commented `set_max_delay` constraint is provided for the PC→datapath path and should be enabled after synthesis timing analysis.

---

## 14. Design Decisions & Notes

**Why single-cycle?**  
Single-cycle is the simplest correct implementation of a processor. Every instruction's CPI (Cycles Per Instruction) is exactly 1, at the cost of a longer clock period (the critical path is determined by the slowest instruction). This is ideal for learning, verification, and FPGA prototyping before adding pipelining.

**Why Harvard memory?**  
Separating IMEM and DMEM avoids a structural hazard where a load/store instruction would need simultaneous read and write access to the same memory. It also reflects common embedded FPGA implementations where program ROM and data RAM are independent.

**3-bit `alu_op`**  
The original Harris & Harris textbook design uses a 2-bit `alu_op`. This implementation expands it to 3 bits to separately encode LUI's pass-through operation (`3'b100`), keeping the ALU control decoder clean and avoiding special-casing in the ALU itself.

**`casex` in `alu_ctrl.v`**  
`casex` is used deliberately to allow don't-care matching on bits that are irrelevant for a given `alu_op`. This is safe here because the priority among `alu_op` values is fixed and there are no ambiguous overlapping patterns.

**Latch prevention**  
`control.v` assigns safe defaults (`0`) to all outputs before the `case` statement, guaranteeing that synthesis tools cannot infer latches from the combinational always block.

---

## 15. Known Limitations

| Limitation | Details |
|------------|---------|
| Sub-word memory access | LH, LB, LHU, LBU, SH, SB are decoded but memory model only performs 32-bit word reads/writes. No byte-enable masking. |
| Branch condition | Only BEQ is fully implemented (via `alu_zero`). BNE/BLT/BGE require extending the branch-taken logic to decode `funct3`. |
| No pipeline | Single-cycle: CPI=1 but maximum clock frequency is limited by the longest combinational path (LW instruction through ALU → DMEM → WB MUX). |
| JALR PC alignment | The spec requires clearing bit 0 of the target address. The current implementation does not mask `pc_branch[0]`. |
| No interrupts / CSRs | No machine-mode CSR registers, no MTVEC/MEPC, no external interrupt handling. `trap` is a debug signal only. |
| Fixed memory depth | IMEM and DMEM are each 256 words (1 KB). Programs exceeding this length will wrap or behave incorrectly. |
| Absolute MEM_FILE paths | Default parameter uses a Windows absolute path (`C:/rv32i_cpu/...`). Must be overridden to a local path when porting to another machine. |

# RV32I Single-Cycle Processor — Detailed Documentation

This document serves as the comprehensive technical reference for the RV32I Single-Cycle Processor project implemented in Verilog.

---

## 1. Architectural Overview

The processor is based on a clean, single-cycle Harvard Architecture. In this design, the Instruction Memory (`imem`) and Data Memory (`dmem`) operate independently, allowing simultaneous instruction fetch and data memory access in a single clock cycle. All stages (Instruction Fetch, Instruction Decode, Execute, Memory Access, and Write-Back) are evaluated rotationally within the combinational logic before state elements capture the result on the positive clock edge.

### Core Datapath Routing
1. **Instruction Fetch (IF)**: The Program Counter (`pc`) indexes into `imem` to retrieve a 32-bit instruction (`instr`).
2. **Instruction Decode (ID)**: 
   - The Instruction is fragmented. Read addresses (`rs1`, `rs2`) pull data from the Register File (`regfile`).
   - The Immediate Generator (`imm_gen`) extends immediate fields based on the instruction type.
   - The Main Control Unit (`control`) decodes the 7-bit opcode to orchestrate datapath MUXing.
3. **Execute (EX)**: The ALU performs binary operations between `rs1` data and either `rs2` data or the extended immediate value (`alu_b`). Branch conditions are resolved via the `alu_zero` flag.
4. **Memory Access (MEM)**: `dmem` executes Load/Store ops utilizing the computed ALU result as the memory address, and writes `rs2` payload (on a Store).
5. **Write-Back (WB)**: Data routing back to `regfile` selects from ALU output, Data Memory read result, or PC+4 (for linking).

---

## 2. Module Implementations (`/rtl`)

### Top-Level CPU (`rv32i_cpu.v`)
Integrates the entire sub-systems. Parametrized `MEM_DEPTH` and `MEM_FILE` attributes allow dynamic `.mem` test loading. Exports 11 specialized debug connections for robust signal-inspection inside Vivado Waveform view without resorting to deep hierarchical paths.

### Main Control Unit (`control.v`)
Decodes the 7-bit `opcode` of incoming instructions and outputs flags controlling Write-Enables, MUX selectors (`alu_src`, `result_src`), and Branch/Jump indicators. It forces safe defaults (0s) to avert un-intended latches and explicitly sets the `trap` pin signal upon processing invalid or un-implemented opcodes.

### ALU Control (`alu_ctrl.v`) & ALU (`alu.v`)
A dedicated ALU sub-decoder analyzes `funct3`, `funct7_5`, and `alu_op` generic flags to determine the exact binary math/logic permutation (ADD, SUB, AND, OR, XOR, SLL, SLT). The `alu` subsequently uses the 4-bit indicator to execute 32-bit arithmetic, reporting comparisons via its `zero` flag.

### Registers (`regfile.v`)
Contains x0–x31 32-bit registers. Hard-coded to keep register Zero (`x0`) eternally immutable despite erroneous Write-Enable commands sent to the address. Includes dual-read and single-write ports operating asynchronously for reads and synchronously for writes.

### PC (`pc.v`)
Standard positive-edge triggered 32-bit Program Counter incrementing to `pc_next` per-clock, reset-capable.

### Immediate Generator (`imm_gen.v`)
Takes the RAW instruction stream, analyzes the instruction payload type requested by Control (`imm_src`: I, S, B, U, J types), extracts the immediate fragment, and sign-extends the payload appropriately to full 32-bit widths.

---

## 3. Supported Instruction Set

The design executes the native Integer (RV32I) sub-set, spanning Arithmetic, Branch, Memory Access, and Control Flow manipulations.

| Type | Instruction Mnemonics | Opcode `[6:0]` |
|------|-----------------------|---------------|
| **R-Type** | `ADD`, `SUB`, `AND`, `OR`, `XOR`, `SLT`, `SLL` | `0110011` |
| **I-Type** | `ADDI`, `ANDI`, `ORI`, `XORI`, `SLTI`, `SLLI` | `0010011` |
| **Load** | `LW`, `LH`, `LB`, `LHU`, `LBU` | `0000011` |
| **Store** | `SW`, `SH`, `SB` | `0100011` |
| **Branch** | `BEQ`, `BNE`, `BLT`, `BGE` | `1100011` |
| **U-Type** | `LUI` | `0110111` |
| **U-Type** | `AUIPC` | `0010111` |
| **J-Type** | `JAL` | `1101111` |
| **J-Type** | `JALR` | `1100111` |

---

## 4. Verification and Simulation Strategy

Rigorous validation is achieved via the Master SystemVerilog Testbench (`tb_phase5_top.sv`). Testing scales across discrete functional realms to guarantee robust processing logic, iterating automatically over binary object files (`.mem`).

### Test Payload (`/sim/test_programs/`)
1. **`prog_arith.mem`**: Sequences R-Type and I-Type ops to prove correct logical shifting, XORing, addition, and Signed Less-Than conditions.
2. **`prog_memops.mem`**: Exercises addressing precision by cascading contiguous offset load/stores, asserting memory transparency cycle-by-cycle.
3. **`prog_loop.mem`**: Confirms backwards instruction execution using a branch iteration algorithm (e.g. `BNE`) to stress negative program-counter jumps.
4. **`prog_edgecases.mem`**: Deliberately executes out-of-bounds immediate injections, writes to explicit Zero logic, and runs undefined operation codes to test architecture robustness.

### Assertions & Trap Handling
The test environment embeds gold-reference checks. Custom `check_reg()` and `check_mem()` SystemVerilog tasks compare actual internal state against projected algorithmic outputs. Moreover, if the CPU interprets an invalid instruction sequence, it asserts a hardware `trap` pin. The testbench dynamically detects this `trap`, pauses clocking safely, and logs a verified exception pass.

---

**End of Documentation**

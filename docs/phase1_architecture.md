# RV32I Single-Cycle Processor — Phase 1 Architecture Notes

See the full architecture document in the project artifact.

## Quick Reference

### Opcode Map
| Instruction | opcode[6:0] |
|-------------|-------------|
| R-type | 0110011 |
| I-ALU | 0010011 |
| Load | 0000011 |
| Store | 0100011 |
| Branch | 1100011 |
| LUI | 0110111 |
| AUIPC | 0010111 |
| JAL | 1101111 |
| JALR | 1100111 |

### Key Control Signals
| Signal | Logic |
|--------|-------|
| RegWrite=1 | R-type, I-ALU, Load, LUI, AUIPC, JAL, JALR |
| MemWrite=1 | Store only |
| ALUSrc=1 | All non-R-type (use immediate) |
| Branch=1 | Branch instructions only |
| Jump=1 | JAL, JALR |

### Module Hierarchy
```
rv32i_cpu (top)
├── pc
├── imem
├── control
├── regfile
├── imm_gen
├── alu_ctrl
├── alu
└── dmem
```

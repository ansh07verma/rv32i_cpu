// ============================================================
// Module: imm_gen.v
// Description: Immediate Generator — sign-extends immediates
//   for all RV32I formats (I, S, B, U, J)
// Project: RV32I Single-Cycle Processor
// ============================================================

module imm_gen (
    input  wire [31:0] instr,
    input  wire [2:0]  imm_src,
    output reg  [31:0] imm_ext
);

    always @(*) begin
        case (imm_src)
            3'b000: // I-type: LW, ADDI, JALR, etc.
                imm_ext = {{20{instr[31]}}, instr[31:20]};

            3'b001: // S-type: SW, SH, SB
                imm_ext = {{20{instr[31]}}, instr[31:25], instr[11:7]};

            3'b010: // B-type: BEQ, BNE, BLT, BGE
                imm_ext = {{19{instr[31]}}, instr[31], instr[7],
                            instr[30:25], instr[11:8], 1'b0};

            3'b011: // U-type: LUI, AUIPC
                imm_ext = {instr[31:12], 12'b0};

            3'b100: // J-type: JAL
                imm_ext = {{11{instr[31]}}, instr[31], instr[19:12],
                            instr[20], instr[30:21], 1'b0};

            default:
                imm_ext = 32'b0;
        endcase
    end

endmodule

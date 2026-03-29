// ============================================================
// Module: alu_ctrl.v
// Description: ALU Control Sub-Decoder
//   Maps {ALUOp, funct3, funct7[5]} -> 4-bit alu_ctrl
// Project: RV32I Single-Cycle Processor
// ============================================================

module alu_ctrl (
    input  wire [2:0]  alu_op,      // 3-bit: From main Control Unit
    input  wire [2:0]  funct3,      // From instr[14:12]
    input  wire        funct7_5,    // From instr[30]
    output reg  [3:0]  alu_ctrl     // To ALU
);

    always @(*) begin
        casex ({alu_op, funct3, funct7_5})
            // Force ADD
            7'b000_xxx_x: alu_ctrl = 4'b0000; 

            // Force SUB (Branches)
            7'b001_xxx_x: alu_ctrl = 4'b0001; 

            // LUI Pass-through
            7'b100_xxx_x: alu_ctrl = 4'b1010; 

            // R-TYPE (alu_op = 010)
            7'b010_000_0: alu_ctrl = 4'b0000; // ADD
            7'b010_000_1: alu_ctrl = 4'b0001; // SUB
            7'b010_001_x: alu_ctrl = 4'b0101; // SLL
            7'b010_010_x: alu_ctrl = 4'b1000; // SLT
            7'b010_011_x: alu_ctrl = 4'b1001; // SLTU
            7'b010_100_x: alu_ctrl = 4'b0100; // XOR
            7'b010_101_0: alu_ctrl = 4'b0110; // SRL
            7'b010_101_1: alu_ctrl = 4'b0111; // SRA
            7'b010_110_x: alu_ctrl = 4'b0011; // OR
            7'b010_111_x: alu_ctrl = 4'b0010; // AND

            // I-ALU (alu_op = 011)
            7'b011_000_x: alu_ctrl = 4'b0000; // ADDI (ALWAYS ADD, ignore funct7_5)
            7'b011_001_x: alu_ctrl = 4'b0101; // SLLI
            7'b011_010_x: alu_ctrl = 4'b1000; // SLTI
            7'b011_011_x: alu_ctrl = 4'b1001; // SLTIU
            7'b011_100_x: alu_ctrl = 4'b0100; // XORI
            7'b011_101_0: alu_ctrl = 4'b0110; // SRLI
            7'b011_101_1: alu_ctrl = 4'b0111; // SRAI
            7'b011_110_x: alu_ctrl = 4'b0011; // ORI
            7'b011_111_x: alu_ctrl = 4'b0010; // ANDI

            default: alu_ctrl = 4'b0000; 
        endcase
    end

endmodule

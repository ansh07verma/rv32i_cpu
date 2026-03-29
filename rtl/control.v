// ============================================================
// Module: control.v
// Description: Main Control Unit — Combinational opcode decoder
//   Outputs all datapath control signals from 7-bit opcode
// Project: RV32I Single-Cycle Processor
// ============================================================

module control (
    input  wire [6:0]  opcode,
    output reg         reg_write,   // 1 = write to register file
    output reg  [2:0]  imm_src,     // Immediate format selector
    output reg         alu_src,     // 0=rs2, 1=imm
    output reg         mem_write,   // 1 = write to data memory
    output reg  [1:0]  result_src,  // WB mux: 00=ALU, 01=MEM, 10=PC+4
    output reg         branch,      // 1 = branch instruction
    output reg         jump,        // 1 = unconditional jump (JAL/JALR)
    output reg  [2:0]  alu_op,      // To ALU control sub-decoder (Expanded to 3 bits)
    output reg         trap         // 1 = illegal instruction
);

    // Opcode definitions
    localparam OP_RTYPE   = 7'b0110011; // R-type:  ADD, SUB, AND, OR, XOR, SLT...
    localparam OP_IALU    = 7'b0010011; // I-ALU:   ADDI, ANDI, ORI, XORI...
    localparam OP_LOAD    = 7'b0000011; // Load:    LW, LH, LB, LHU, LBU
    localparam OP_STORE   = 7'b0100011; // Store:   SW, SH, SB
    localparam OP_BRANCH  = 7'b1100011; // Branch:  BEQ, BNE, BLT, BGE...
    localparam OP_LUI     = 7'b0110111; // LUI
    localparam OP_AUIPC   = 7'b0010111; // AUIPC
    localparam OP_JAL     = 7'b1101111; // JAL
    localparam OP_JALR    = 7'b1100111; // JALR

    always @(*) begin
        // Safe defaults — prevent latches
        reg_write  = 1'b0;
        imm_src    = 3'b000;
        alu_src    = 1'b0;
        mem_write  = 1'b0;
        result_src = 2'b00;
        branch     = 1'b0;
        jump       = 1'b0;
        alu_op     = 3'b000;
        trap       = 1'b0;

        case (opcode)
            OP_RTYPE: begin
                reg_write  = 1'b1;
                alu_src    = 1'b0;  // B = rs2
                mem_write  = 1'b0;
                result_src = 2'b00; // WB = ALU result
                alu_op     = 3'b010; // R-Type
            end

            OP_IALU: begin
                reg_write  = 1'b1;
                imm_src    = 3'b000;
                alu_src    = 1'b1;  // B = imm
                mem_write  = 1'b0;
                result_src = 2'b00;
                alu_op     = 3'b011; // I-Type
            end

            OP_LOAD: begin
                reg_write  = 1'b1;
                imm_src    = 3'b000;
                alu_src    = 1'b1;  // addr = rs1 + imm
                mem_write  = 1'b0;
                result_src = 2'b01; // WB = memory read data
                alu_op     = 3'b000; // Force ADD
            end

            OP_STORE: begin
                reg_write  = 1'b0;
                imm_src    = 3'b001; // S-type immediate
                alu_src    = 1'b1;  // addr = rs1 + imm
                mem_write  = 1'b1;
                alu_op     = 3'b000; // Force ADD
            end

            OP_BRANCH: begin
                reg_write  = 1'b0;
                imm_src    = 3'b010; // B-type immediate
                alu_src    = 1'b0;  // compare rs1 vs rs2
                mem_write  = 1'b0;
                branch     = 1'b1;
                alu_op     = 3'b001; // Force SUB (for comparison)
            end

            OP_LUI: begin
                reg_write  = 1'b1;
                imm_src    = 3'b011; // U-type immediate
                alu_src    = 1'b1;
                mem_write  = 1'b0;
                result_src = 2'b00;
                alu_op     = 3'b100; // LUI pass-through
            end

            OP_AUIPC: begin
                reg_write  = 1'b1;
                imm_src    = 3'b011;
                alu_src    = 1'b1;
                mem_write  = 1'b0;
                result_src = 2'b00;
                alu_op     = 3'b000; // ADD (PC + imm)
            end

            OP_JAL: begin
                reg_write  = 1'b1;
                imm_src    = 3'b100; // J-type immediate
                mem_write  = 1'b0;
                result_src = 2'b10; // WB = PC+4 (return address)
                jump       = 1'b1;
                alu_op     = 3'b000;
            end

            OP_JALR: begin
                reg_write  = 1'b1;
                imm_src    = 3'b000; // I-type immediate
                alu_src    = 1'b1;
                mem_write  = 1'b0;
                result_src = 2'b10; // WB = PC+4
                jump       = 1'b1;
                alu_op     = 3'b000; // ADD (rs1 + imm = target)
            end

            default: begin
                // NOP / undefined
                reg_write  = 1'b0;
                mem_write  = 1'b0;
                trap       = 1'b1;  // Signal an illegal instruction
            end
        endcase
    end

endmodule

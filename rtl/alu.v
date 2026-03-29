// ============================================================
// Module: alu.v
// Description: 32-bit Arithmetic Logic Unit
//   Supports: ADD, SUB, AND, OR, XOR, SLL, SRL, SRA, SLT, SLTU, LUI-pass
// Project: RV32I Single-Cycle Processor
// ============================================================

module alu (
    input  wire [31:0] a,           // Operand A (always rs1_data)
    input  wire [31:0] b,           // Operand B (rs2_data or imm_ext)
    input  wire [3:0]  alu_ctrl,    // ALU operation selector
    output reg  [31:0] result,      // Computation result
    output wire        zero         // 1 if result == 0 (for BEQ)
);

    // ALU control encoding (matches alu_ctrl.v output)
    localparam ALU_ADD  = 4'b0000;
    localparam ALU_SUB  = 4'b0001;
    localparam ALU_AND  = 4'b0010;
    localparam ALU_OR   = 4'b0011;
    localparam ALU_XOR  = 4'b0100;
    localparam ALU_SLL  = 4'b0101;
    localparam ALU_SRL  = 4'b0110;
    localparam ALU_SRA  = 4'b0111;
    localparam ALU_SLT  = 4'b1000;
    localparam ALU_SLTU = 4'b1001;
    localparam ALU_LUI  = 4'b1010;

    always @(*) begin
        case (alu_ctrl)
            ALU_ADD:  result = a + b;
            ALU_SUB:  result = a - b;
            ALU_AND:  result = a & b;
            ALU_OR:   result = a | b;
            ALU_XOR:  result = a ^ b;
            ALU_SLL:  result = a << b[4:0];
            ALU_SRL:  result = a >> b[4:0];
            ALU_SRA:  result = $signed(a) >>> b[4:0];
            ALU_SLT:  result = ($signed(a) < $signed(b)) ? 32'd1 : 32'd0;
            ALU_SLTU: result = (a < b) ? 32'd1 : 32'd0;
            ALU_LUI:  result = b;               // LUI: pass immediate through
            default: begin
                result = 32'b0;
                // Using $error to catch undefined operations during simulation
                $error("[ALU/ASSERT] Undefined alu_ctrl value: %b", alu_ctrl);
            end
        endcase
    end

    assign zero = (result == 32'b0);

endmodule

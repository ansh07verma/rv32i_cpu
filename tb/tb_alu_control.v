`timescale 1ns / 1ps
// ============================================================
// Testbench : tb_alu_control.v
// Module    : alu_control.v
// Tests     : all alu_op modes, all funct3 values for alu_op=10,
//             funct7 differentiation (ADD/SUB, SRL/SRA)
// ============================================================

module tb_alu_control;

    reg  [1:0] alu_op;
    reg  [2:0] funct3;
    reg        funct7_5;
    wire [3:0] alu_ctrl;

    integer pass_cnt = 0;
    integer fail_cnt = 0;

    alu_control uut (
        .alu_op(alu_op), .funct3(funct3),
        .funct7_5(funct7_5), .alu_ctrl(alu_ctrl)
    );

    task check;
        input [3:0] expected;
        input [127:0] label;
        begin
            if (alu_ctrl !== expected) begin
                $display("FAIL [%0s] got=%b expected=%b", label, alu_ctrl, expected);
                fail_cnt = fail_cnt + 1;
            end else begin
                $display("PASS [%0s] alu_ctrl=%b", label, alu_ctrl);
                pass_cnt = pass_cnt + 1;
            end
        end
    endtask

    initial begin
        $display("===== ALU Control Testbench =====");

        // ---- alu_op=00: Force ADD ----
        alu_op=2'b00; funct3=3'b000; funct7_5=0; #10;
        check(4'b0000, "ALUOP00_FORCE_ADD");
        funct3=3'b111; funct7_5=1; #10;           // funct3/7 don't matter
        check(4'b0000, "ALUOP00_ADD_irrespective");

        // ---- alu_op=01: Force SUB ----
        alu_op=2'b01; funct3=3'b000; funct7_5=0; #10;
        check(4'b0001, "ALUOP01_FORCE_SUB");

        // ---- alu_op=11: LUI pass ----
        alu_op=2'b11; funct3=3'b000; funct7_5=0; #10;
        check(4'b1010, "ALUOP11_LUI_PASS");

        // ---- alu_op=10: decode funct3/funct7 ----
        alu_op=2'b10;

        funct3=3'b000; funct7_5=0; #10; check(4'b0000, "DECODE_ADD");
        funct3=3'b000; funct7_5=1; #10; check(4'b0001, "DECODE_SUB");
        funct3=3'b001; funct7_5=0; #10; check(4'b0101, "DECODE_SLL");
        funct3=3'b010; funct7_5=0; #10; check(4'b1000, "DECODE_SLT");
        funct3=3'b011; funct7_5=0; #10; check(4'b1001, "DECODE_SLTU");
        funct3=3'b100; funct7_5=0; #10; check(4'b0100, "DECODE_XOR");
        funct3=3'b101; funct7_5=0; #10; check(4'b0110, "DECODE_SRL");
        funct3=3'b101; funct7_5=1; #10; check(4'b0111, "DECODE_SRA");
        funct3=3'b110; funct7_5=0; #10; check(4'b0011, "DECODE_OR");
        funct3=3'b111; funct7_5=0; #10; check(4'b0010, "DECODE_AND");

        $display("---- Results: PASS=%0d  FAIL=%0d ----", pass_cnt, fail_cnt);
        if (fail_cnt == 0) $display("ALL TESTS PASSED");
        $finish;
    end

endmodule

`timescale 1ns / 1ps
// ============================================================
// Testbench : tb_control.v
// Module    : control.v
// Tests     : all 9 opcodes → verify every control signal
// Fix       : removed label param from task (xvlog argcount strict)
// ============================================================

module tb_control;

    reg  [6:0] opcode;
    wire       reg_write;
    wire [2:0] imm_src;
    wire       alu_src;
    wire       mem_write;
    wire [1:0] result_src;
    wire       branch;
    wire       jump;
    wire [1:0] alu_op;

    integer pass_cnt = 0;
    integer fail_cnt = 0;

    control uut (
        .opcode(opcode), .reg_write(reg_write), .imm_src(imm_src),
        .alu_src(alu_src), .mem_write(mem_write), .result_src(result_src),
        .branch(branch), .jump(jump), .alu_op(alu_op)
    );

    // ---- Check task (no label arg — xvlog strict argcount) ----
    task check_signals;
        input       exp_rw;
        input [2:0] exp_imm;
        input       exp_as;
        input       exp_mw;
        input [1:0] exp_rs;
        input       exp_br;
        input       exp_jmp;
        input [1:0] exp_aop;
        begin
            if (reg_write !== exp_rw  || alu_src    !== exp_as  ||
                mem_write  !== exp_mw  || result_src !== exp_rs  ||
                branch     !== exp_br  || jump       !== exp_jmp ||
                alu_op     !== exp_aop) begin
                $display("FAIL [opcode=%b]", opcode);
                $display("  got : RW=%b IS=%b AS=%b MW=%b RS=%b BR=%b JMP=%b AOP=%b",
                          reg_write, imm_src, alu_src, mem_write,
                          result_src, branch, jump, alu_op);
                $display("  exp : RW=%b IS=%b AS=%b MW=%b RS=%b BR=%b JMP=%b AOP=%b",
                          exp_rw, exp_imm, exp_as, exp_mw,
                          exp_rs, exp_br, exp_jmp, exp_aop);
                fail_cnt = fail_cnt + 1;
            end else begin
                $display("PASS [opcode=%b]", opcode);
                pass_cnt = pass_cnt + 1;
            end
        end
    endtask

    initial begin
        $display("===== Control Unit Testbench =====");

        //                         RW  ImmSrc   AS  MW   RS    BR  JMP  AOp
        opcode = 7'b011_0011; #10; check_signals(1, 3'b000, 0, 0, 2'b00, 0, 0, 2'b10); // R-type
        opcode = 7'b001_0011; #10; check_signals(1, 3'b000, 1, 0, 2'b00, 0, 0, 2'b10); // I-ALU
        opcode = 7'b000_0011; #10; check_signals(1, 3'b000, 1, 0, 2'b01, 0, 0, 2'b00); // LOAD
        opcode = 7'b010_0011; #10; check_signals(0, 3'b001, 1, 1, 2'b00, 0, 0, 2'b00); // STORE
        opcode = 7'b110_0011; #10; check_signals(0, 3'b010, 0, 0, 2'b00, 1, 0, 2'b01); // BRANCH
        opcode = 7'b011_0111; #10; check_signals(1, 3'b011, 1, 0, 2'b00, 0, 0, 2'b11); // LUI
        opcode = 7'b001_0111; #10; check_signals(1, 3'b011, 1, 0, 2'b00, 0, 0, 2'b00); // AUIPC
        opcode = 7'b110_1111; #10; check_signals(1, 3'b100, 0, 0, 2'b10, 0, 1, 2'b00); // JAL
        opcode = 7'b110_0111; #10; check_signals(1, 3'b000, 1, 0, 2'b10, 0, 1, 2'b00); // JALR

        // Edge: undefined opcode → no register write, no memory write
        opcode = 7'b000_0000; #10;
        if (reg_write === 0 && mem_write === 0) begin
            $display("PASS [opcode=0000000 UNDEF safe]");
            pass_cnt = pass_cnt + 1;
        end else begin
            $display("FAIL [UNDEF] RW=%b MW=%b", reg_write, mem_write);
            fail_cnt = fail_cnt + 1;
        end

        $display("---- Results: PASS=%0d  FAIL=%0d ----", pass_cnt, fail_cnt);
        if (fail_cnt == 0) $display("ALL TESTS PASSED");
        else               $display("SOME TESTS FAILED — check signals above");
        $finish;
    end

endmodule

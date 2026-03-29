`timescale 1ns / 1ps
// ============================================================
// Testbench : tb_phase4.v
// DUT       : rv32i_cpu
// Project   : RV32I Single-Cycle Processor — Phase 4
//
// PURPOSE:
//   Full-system regression across three self-contained programs.
//   Each program is loaded by overriding MEM_FILE on the DUT.
//   Assertions use $error() (non-fatal) so all checks execute even
//   when earlier ones fail — giving a complete picture of failures.
//
// Programs executed (one DUT instantiation each via tasks):
//   1. prog_arith.mem   — arithmetic (ADD/SUB/AND/OR/XOR/SLL/SLT)
//   2. prog_memops.mem  — LW / SW / ACC accumulate + verify
//   3. prog_loop.mem    — BEQ forward/backward branch loop
//
// Timing model (single-cycle, synchronous write-back):
//   - Every instruction commits in exactly ONE clock cycle
//   - RegFile writes on posedge clk
//   - Combinational reads settle before negedge
//   - All assertions sample on negedge (mid-cycle snapshot)
//
// Clock: 10 ns (100 MHz)
// Reset: 2-posedge synchronous reset
// ============================================================

// ============================================================
// ---- PROGRAM 1: ARITHMETIC ----
// ============================================================
module tb_arith;

    reg clk, reset;
    integer pass_cnt, fail_cnt;

    // DUT — load the arithmetic program
    rv32i_cpu #(
        .MEM_DEPTH (256),
        .MEM_FILE  ("C:/rv32i_cpu/sim/test_programs/prog_arith.mem")
    ) uut (
        .clk   (clk),
        .reset (reset)
    );

    // 100 MHz clock
    initial clk = 0;
    always  #5 clk = ~clk;

    // ---- helpers ----
    task step;
        begin @(posedge clk); @(negedge clk); end
    endtask

    task chk_reg;
        input [4:0]  rn;
        input [31:0] exp;
        input [127:0] lbl;
        reg [31:0] got;
        begin
            got = uut.u_regfile.regs[rn];
            if (got !== exp) begin
                $display("FAIL [TB_ARITH | %0s] x%0d = 0x%08h  (expected 0x%08h)",
                          lbl, rn, got, exp);
                fail_cnt = fail_cnt + 1;
            end else begin
                $display("PASS [TB_ARITH | %0s] x%0d = 0x%08h", lbl, rn, got);
                pass_cnt = pass_cnt + 1;
            end
        end
    endtask

    // ---- Per-negedge monitor ----
    always @(negedge clk) begin
        if (!reset)
            $display("[ARITH] T=%4t | PC=%08h | INSTR=%08h | rd=x%02d | ALU=%08h | Z=%b",
                $time, uut.pc_out, uut.instr, uut.rd_addr, uut.alu_result, uut.alu_zero);
    end

    initial begin
        pass_cnt = 0; fail_cnt = 0;
        $display("=================================================");
        $display(" TB_ARITH — RV32I Arithmetic Validation");
        $display("=================================================");

        // 2-cycle reset
        reset = 1; repeat(2) @(posedge clk); @(negedge clk); reset = 0;

        // CYCLE 1: ADDI x1, x0, 20  → x1 = 20
        step(); chk_reg(1,  32'd20,  "ADDI_x1=20");

        // CYCLE 2: ADDI x2, x0, 7   → x2 = 7
        step(); chk_reg(2,  32'd7,   "ADDI_x2=7");

        // CYCLE 3: ADD x3, x1, x2   → x3 = 27
        step(); chk_reg(3,  32'd27,  "ADD_x3=27");

        // CYCLE 4: SUB x4, x1, x2   → x4 = 13
        step(); chk_reg(4,  32'd13,  "SUB_x4=13");

        // CYCLE 5: AND x5, x1, x2   → x5 = 20&7 = 4
        step(); chk_reg(5,  32'd4,   "AND_x5=4");

        // CYCLE 6: OR  x6, x1, x2   → x6 = 20|7 = 23
        step(); chk_reg(6,  32'd23,  "OR_x6=23");

        // CYCLE 7: XOR x7, x1, x2   → x7 = 20^7 = 19
        step(); chk_reg(7,  32'd19,  "XOR_x7=19");

        // CYCLE 8: ADDI x8, x0, 1   → x8 = 1
        step(); chk_reg(8,  32'd1,   "ADDI_x8=1");

        // CYCLE 9: SLL x9, x3, x8   → x9 = 27<<1 = 54
        step(); chk_reg(9,  32'd54,  "SLL_x9=54");

        // CYCLE 10: SLT x10, x1, x2 → x10 = 0  (20 < 7 is FALSE)
        step(); chk_reg(10, 32'd0,   "SLT_x10=0(20<7_false)");

        // CYCLE 11: SLT x10, x2, x1 → x10 = 1  (7 < 20 is TRUE)
        step(); chk_reg(10, 32'd1,   "SLT_x10=1(7<20_true)");

        // Drain 2 NOPs
        step(); step();

        $display("-------------------------------------------------");
        $display(" TB_ARITH Results: PASS=%0d  FAIL=%0d", pass_cnt, fail_cnt);
        if (fail_cnt == 0) $display(" ALL ARITHMETIC TESTS PASSED ✓");
        else               $display(" ARITHMETIC TESTS FAILED — CHECK DATAPATH");
        $display("=================================================");
        $finish;
    end

endmodule


// ============================================================
// ---- PROGRAM 2: MEMORY OPERATIONS (LW/SW) ----
// ============================================================
module tb_memops;

    reg clk, reset;
    integer pass_cnt, fail_cnt;

    rv32i_cpu #(
        .MEM_DEPTH (256),
        .MEM_FILE  ("C:/rv32i_cpu/sim/test_programs/prog_memops.mem")
    ) uut (
        .clk   (clk),
        .reset (reset)
    );

    initial clk = 0;
    always  #5 clk = ~clk;

    task step;
        begin @(posedge clk); @(negedge clk); end
    endtask

    task chk_reg;
        input [4:0]   rn;
        input [31:0]  exp;
        input [127:0] lbl;
        reg [31:0] got;
        begin
            got = uut.u_regfile.regs[rn];
            if (got !== exp) begin
                $display("FAIL [TB_MEMOPS | %0s] x%0d = 0x%08h  (expected 0x%08h)",
                          lbl, rn, got, exp);
                fail_cnt = fail_cnt + 1;
            end else begin
                $display("PASS [TB_MEMOPS | %0s] x%0d = 0x%08h", lbl, rn, got);
                pass_cnt = pass_cnt + 1;
            end
        end
    endtask

    task chk_mem;
        input [31:0]  baddr;   // byte address
        input [31:0]  exp;
        input [127:0] lbl;
        reg [31:0] got;
        begin
            got = uut.u_dmem.mem[baddr >> 2];
            if (got !== exp) begin
                $display("FAIL [TB_MEMOPS | %0s] MEM[0x%03h] = 0x%08h  (expected 0x%08h)",
                          lbl, baddr, got, exp);
                fail_cnt = fail_cnt + 1;
            end else begin
                $display("PASS [TB_MEMOPS | %0s] MEM[0x%03h] = 0x%08h", lbl, baddr, got);
                pass_cnt = pass_cnt + 1;
            end
        end
    endtask

    always @(negedge clk) begin
        if (!reset)
            $display("[MEMOPS] T=%4t | PC=%08h | INSTR=%08h | rd=x%02d | ALU=%08h | MW=%b | WD=%08h",
                $time, uut.pc_out, uut.instr, uut.rd_addr,
                uut.alu_result, uut.mem_write, uut.write_data);
    end

    initial begin
        pass_cnt = 0; fail_cnt = 0;
        $display("=================================================");
        $display(" TB_MEMOPS — RV32I Load/Store Validation");
        $display("=================================================");

        reset = 1; repeat(2) @(posedge clk); @(negedge clk); reset = 0;

        // CYCLE 1: ADDI x1, x0, 0xA5 (165)  → x1 = 165
        step(); chk_reg(1,  32'h0000_00A5, "ADDI_x1=0xA5");

        // CYCLE 2: ADDI x2, x0, 0x3C (60)   → x2 = 60
        step(); chk_reg(2,  32'h0000_003C, "ADDI_x2=0x3C");

        // CYCLE 3: ADDI x3, x0, 0x11 (17)   → x3 = 17
        step(); chk_reg(3,  32'h0000_0011, "ADDI_x3=0x11");

        // CYCLE 4: SW x1, 0(x0)   → MEM[0x00] = 0xA5
        step(); chk_mem(32'h0, 32'h0000_00A5, "SW_MEM[0]=0xA5");

        // CYCLE 5: SW x2, 4(x0)   → MEM[0x04] = 0x3C
        step(); chk_mem(32'h4, 32'h0000_003C, "SW_MEM[4]=0x3C");

        // CYCLE 6: SW x3, 8(x0)   → MEM[0x08] = 0x11
        step(); chk_mem(32'h8, 32'h0000_0011, "SW_MEM[8]=0x11");

        // CYCLE 7: LW x10, 0(x0)  → x10 = 0xA5
        step(); chk_reg(10, 32'h0000_00A5, "LW_x10=MEM[0]=0xA5");

        // CYCLE 8: LW x11, 4(x0)  → x11 = 0x3C
        step(); chk_reg(11, 32'h0000_003C, "LW_x11=MEM[4]=0x3C");

        // CYCLE 9: LW x12, 8(x0)  → x12 = 0x11
        step(); chk_reg(12, 32'h0000_0011, "LW_x12=MEM[8]=0x11");

        // CYCLE 10: ADD x13, x10, x11 → x13 = 0xA5+0x3C = 0xE1 (225)
        step(); chk_reg(13, 32'h0000_00E1, "ADD_x13=0xE1");

        // CYCLE 11: ADD x13, x13, x12 → x13 = 0xE1+0x11 = 0xF2 (242)
        step(); chk_reg(13, 32'h0000_00F2, "ADD_x13=0xF2(sum)");

        // CYCLE 12: SW x13, 12(x0) → MEM[0x0C] = 0xF2
        step(); chk_mem(32'hC, 32'h0000_00F2, "SW_MEM[12]=0xF2");

        // CYCLE 13: LW x14, 12(x0) → x14 = 0xF2  (round-trip verify)
        step(); chk_reg(14, 32'h0000_00F2, "LW_x14=MEM[12]=0xF2(verify)");

        // Drain 2 NOPs
        step(); step();

        // ---- Memory state summary ----
        $display("--- Final DMEM snapshot ---");
        $display("  MEM[0x00] = 0x%08h  (expect 0x000000A5)", uut.u_dmem.mem[0]);
        $display("  MEM[0x04] = 0x%08h  (expect 0x0000003C)", uut.u_dmem.mem[1]);
        $display("  MEM[0x08] = 0x%08h  (expect 0x00000011)", uut.u_dmem.mem[2]);
        $display("  MEM[0x0C] = 0x%08h  (expect 0x000000F2)", uut.u_dmem.mem[3]);

        $display("-------------------------------------------------");
        $display(" TB_MEMOPS Results: PASS=%0d  FAIL=%0d", pass_cnt, fail_cnt);
        if (fail_cnt == 0) $display(" ALL MEMORY OPERATION TESTS PASSED ✓");
        else               $display(" MEMORY TESTS FAILED — CHECK DMEM/LW/SW PATH");
        $display("=================================================");
        $finish;
    end

endmodule


// ============================================================
// ---- PROGRAM 3: BRANCH LOOP (BEQ forward + backward) ----
// ============================================================
module tb_loop;

    reg clk, reset;
    integer pass_cnt, fail_cnt;

    rv32i_cpu #(
        .MEM_DEPTH (256),
        .MEM_FILE  ("C:/rv32i_cpu/sim/test_programs/prog_loop.mem")
    ) uut (
        .clk   (clk),
        .reset (reset)
    );

    initial clk = 0;
    always  #5 clk = ~clk;

    task step;
        begin @(posedge clk); @(negedge clk); end
    endtask

    task chk_reg;
        input [4:0]   rn;
        input [31:0]  exp;
        input [127:0] lbl;
        reg [31:0] got;
        begin
            got = uut.u_regfile.regs[rn];
            if (got !== exp) begin
                $display("FAIL [TB_LOOP | %0s] x%0d = 0x%08h  (expected 0x%08h)",
                          lbl, rn, got, exp);
                fail_cnt = fail_cnt + 1;
            end else begin
                $display("PASS [TB_LOOP | %0s] x%0d = 0x%08h", lbl, rn, got);
                pass_cnt = pass_cnt + 1;
            end
        end
    endtask

    task chk_pc;
        input [31:0]  exp_pc;
        input [127:0] lbl;
        begin
            if (uut.pc_out !== exp_pc) begin
                $display("FAIL [TB_LOOP | %0s] PC = 0x%08h  (expected 0x%08h)",
                          lbl, uut.pc_out, exp_pc);
                fail_cnt = fail_cnt + 1;
            end else begin
                $display("PASS [TB_LOOP | %0s] PC = 0x%08h", lbl, uut.pc_out);
                pass_cnt = pass_cnt + 1;
            end
        end
    endtask

    // ---- Per-negedge monitor showing branch signals ----
    always @(negedge clk) begin
        if (!reset)
            $display("[LOOP] T=%4t | PC=%08h | INSTR=%08h | ALU=%08h | BRANCH=%b | ZERO=%b | PC_NEXT=%08h",
                $time, uut.pc_out, uut.instr, uut.alu_result,
                uut.branch, uut.alu_zero, uut.pc_next);
    end

    // ----------------------------------------------------------------
    // Loop trace:
    //   Inits  (3 cycles):  ADDI x1=4, ADDI x2=0, ADDI x3=1
    //   Iter 1 (4 cycles):  ADD x2=4,  SUB x1=3,  BEQ(NT), BEQ(T→0x0C)
    //   Iter 2 (4 cycles):  ADD x2=7,  SUB x1=2,  BEQ(NT), BEQ(T→0x0C)
    //   Iter 3 (4 cycles):  ADD x2=9,  SUB x1=1,  BEQ(NT), BEQ(T→0x0C)
    //   Iter 4 (4 cycles):  ADD x2=10, SUB x1=0,  BEQ(TAKEN→0x20), BEQ skipped
    //   Exit   (3 cycles):  ADD x4=10, NOP, NOP
    //   Total executing cycles after reset ≈ 3 + 4*4 + 3 = 22
    // ----------------------------------------------------------------
    initial begin
        pass_cnt = 0; fail_cnt = 0;
        $display("=================================================");
        $display(" TB_LOOP — RV32I BEQ Branch Loop Validation");
        $display("=================================================");
        $display(" Algorithm: x2 ← sum(4..1) = 10, x4 ← x2");
        $display("-------------------------------------------------");

        reset = 1; repeat(2) @(posedge clk); @(negedge clk); reset = 0;

        // ---- INIT PHASE (3 cycles) ----
        // Cycle 1: ADDI x1, x0, 4
        step(); chk_reg(1, 32'd4, "INIT_x1=4");

        // Cycle 2: ADDI x2, x0, 0
        step(); chk_reg(2, 32'd0, "INIT_x2=0(accum)");

        // Cycle 3: ADDI x3, x0, 1
        step(); chk_reg(3, 32'd1, "INIT_x3=1(step)");

        // ---- ITERATION 1  (x1=4→3, x2=0→4) ----
        step(); chk_reg(2, 32'd4,  "ITER1_ADD_x2=4");   // ADD x2,x2,x1
        step(); chk_reg(1, 32'd3,  "ITER1_SUB_x1=3");   // SUB x1,x1,x3
        step();                                           // BEQ x1,x0 — NOT taken (x1=3)
        step();                                           // BEQ x0,x0 — ALWAYS taken → 0x0C

        // ---- ITERATION 2  (x1=3→2, x2=4→7) ----
        step(); chk_reg(2, 32'd7,  "ITER2_ADD_x2=7");
        step(); chk_reg(1, 32'd2,  "ITER2_SUB_x1=2");
        step();                                           // BEQ — NOT taken
        step();                                           // BEQ always → 0x0C

        // ---- ITERATION 3  (x1=2→1, x2=7→9) ----
        step(); chk_reg(2, 32'd9,  "ITER3_ADD_x2=9");
        step(); chk_reg(1, 32'd1,  "ITER3_SUB_x1=1");
        step();                                           // BEQ — NOT taken
        step();                                           // BEQ always → 0x0C

        // ---- ITERATION 4  (x1=1→0, x2=9→10) ----
        step(); chk_reg(2, 32'd10, "ITER4_ADD_x2=10");
        step(); chk_reg(1, 32'd0,  "ITER4_SUB_x1=0");

        // BEQ x1, x0 — TAKEN (x1=0 = x0=0) → PC should jump to 0x20 (EXIT)
        step();
        chk_pc(32'h20, "BEQ_TAKEN_PC=0x20");

        // ---- EXIT: ADD x4, x2, x0 ----
        step(); chk_reg(4, 32'd10, "EXIT_x4=10(sum_4..1)");

        // Drain remaining NOPs
        step(); step();

        $display("-------------------------------------------------");
        $display(" Final register check:");
        $display("   x1 (counter) = 0x%08h  (expect 0x00000000)",
                  uut.u_regfile.regs[1]);
        $display("   x2 (accum)   = 0x%08h  (expect 0x0000000A)",
                  uut.u_regfile.regs[2]);
        $display("   x4 (result)  = 0x%08h  (expect 0x0000000A)",
                  uut.u_regfile.regs[4]);
        $display("-------------------------------------------------");
        $display(" TB_LOOP Results: PASS=%0d  FAIL=%0d", pass_cnt, fail_cnt);
        if (fail_cnt == 0) $display(" ALL BRANCH LOOP TESTS PASSED ✓");
        else               $display(" BRANCH TESTS FAILED — CHECK BEQ/PC_BRANCH PATH");
        $display("=================================================");
        $finish;
    end

endmodule

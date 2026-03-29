`timescale 1ns / 1ps
// ============================================================
// Testbench : tb_cpu.v
// DUT       : rv32i_cpu (cpu.v)
// Project   : RV32I Single-Cycle Processor — Phase 3
//
// Test Program (test_cpu.mem) — 11 instructions:
//   PC 0x00: ADDI x6, x0, 10       → x6  = 10
//   PC 0x04: ADDI x7, x0, 5        → x7  = 5
//   PC 0x08: ADD  x6, x6, x7       → x6  = 15
//   PC 0x0C: SW   x6, 0(x0)        → MEM[0] = 15
//   PC 0x10: LW   x6, 0(x0)        → x6  = 15  (reload)
//   PC 0x14: SUB  x6, x6, x6       → x6  = 0
//   PC 0x18: BEQ  x6, x5, +8       → TAKEN (x6=0, x5=0), skip 0x1C
//   PC 0x1C: ADDI x6, x0, 99       → SKIPPED
//   PC 0x20: ADDI x2, x0, 42       → x2  = 42
//   PC 0x24: NOP
//   PC 0x28: NOP
//
// Timing model (single-cycle, synchronous WB):
//   - Each instruction executes in 1 clock cycle
//   - RegFile write happens at posedge clk (end of cycle)
//   - Assertions sample on negedge clk (mid-cycle) AFTER the
//     posedge that committed the write → values guaranteed stable
//
// Strategy:
//   - 2-cycle synchronous reset
//   - Per-negedge $display monitor (clean mid-cycle snapshot)
//   - Assertion checks on negedge (after write commit)
//   - Final PASS/FAIL summary
// ============================================================

module tb_cpu;

    // ================================================================
    // DUT ports
    // ================================================================
    reg clk;
    reg reset;

    // ================================================================
    // Instantiate DUT — override MEM_FILE for Phase-3 test program
    // ================================================================
    rv32i_cpu #(
        .MEM_DEPTH  (256),
        .MEM_FILE   ("C:/rv32i_cpu/sim/test_programs/test_cpu.mem")
    ) uut (
        .clk   (clk),
        .reset (reset)
    );

    // ================================================================
    // Clock: 10 ns period (100 MHz), starts LOW
    // ================================================================
    initial clk = 1'b0;
    always  #5 clk = ~clk;

    // ================================================================
    // Scoreboard
    // ================================================================
    integer pass_cnt = 0;
    integer fail_cnt = 0;

    // ================================================================
    // Task: assert a register value (sampled combinationally)
    // ================================================================
    task check_reg;
        input [4:0]   reg_num;
        input [31:0]  expected;
        input [255:0] label;
        reg   [31:0]  actual;
        begin
            actual = uut.u_regfile.regs[reg_num];
            if (actual !== expected) begin
                $display("FAIL [%0s] x%0d = 0x%08h  (expected 0x%08h)",
                         label, reg_num, actual, expected);
                fail_cnt = fail_cnt + 1;
            end else begin
                $display("PASS [%0s] x%0d = 0x%08h", label, reg_num, actual);
                pass_cnt = pass_cnt + 1;
            end
        end
    endtask

    // ================================================================
    // Task: assert a data memory word
    // ================================================================
    task check_mem;
        input [31:0]  byte_addr;
        input [31:0]  expected;
        input [255:0] label;
        reg   [31:0]  actual;
        begin
            actual = uut.u_dmem.mem[byte_addr >> 2];
            if (actual !== expected) begin
                $display("FAIL [%0s] MEM[0x%03h] = 0x%08h  (expected 0x%08h)",
                         label, byte_addr, actual, expected);
                fail_cnt = fail_cnt + 1;
            end else begin
                $display("PASS [%0s] MEM[0x%03h] = 0x%08h", label, byte_addr, actual);
                pass_cnt = pass_cnt + 1;
            end
        end
    endtask

    // ================================================================
    // Helper task: advance one full instruction cycle then sample
    //   - posedge: execute + commit WB
    //   - negedge: sample stable registered values
    // ================================================================
    task step;  // advance one instruction cycle; sample on negedge
        begin
            @(posedge clk);   // WB commits here
            @(negedge clk);   // sample here — combinational reads settle
        end
    endtask

    // ================================================================
    // Per-negedge monitor — clean mid-cycle state snapshot
    // ================================================================
    always @(negedge clk) begin
        if (!reset) begin
            $display("T=%3t | PC=%08h | INSTR=%08h | rd=x%02d | ALU=%08h | Z=%b | MW=%b | RW=%b | WD=%08h",
                $time, uut.pc_out, uut.instr, uut.rd_addr,
                uut.alu_result, uut.alu_zero,
                uut.mem_write, uut.reg_write, uut.write_data);
        end
    end

    // ================================================================
    // Main stimulus + assertions
    // ================================================================
    initial begin
        $display("============================================");
        $display(" RV32I CPU — Phase 3 Integration Testbench ");
        $display("============================================");

        // ---- 2-cycle synchronous reset ----
        reset = 1'b1;
        @(posedge clk); @(negedge clk);
        @(posedge clk); @(negedge clk);
        reset = 1'b0;

        // ============================================================
        // CYCLE 1: PC=0x00 — ADDI x6, x0, 10
        //   WB: x6 ← 10 at posedge
        //   Check on negedge (values committed)
        // ============================================================
        step();   // execute ADDI x6=10
        check_reg(6, 32'd10, "ADDI_x6=10");

        // ============================================================
        // CYCLE 2: PC=0x04 — ADDI x7, x0, 5
        // ============================================================
        step();   // execute ADDI x7=5
        check_reg(7, 32'd5,  "ADDI_x7=5");

        // ============================================================
        // CYCLE 3: PC=0x08 — ADD x6, x6, x7  → x6 = 10+5 = 15
        // ============================================================
        step();   // execute ADD x6=15
        check_reg(6, 32'd15, "ADD_x6=15");

        // ============================================================
        // CYCLE 4: PC=0x0C — SW x6, 0(x0) → MEM[0] = 15
        // ============================================================
        step();   // execute SW x6→MEM[0]
        check_mem(32'h0, 32'd15, "SW_MEM0=15");

        // ============================================================
        // CYCLE 5: PC=0x10 — LW x6, 0(x0) → x6 = MEM[0] = 15
        // ============================================================
        step();   // execute LW x6=MEM[0]
        check_reg(6, 32'd15, "LW_x6=MEM0=15");

        // ============================================================
        // CYCLE 6: PC=0x14 — SUB x6, x6, x6 → x6 = 0
        // ============================================================
        step();   // execute SUB x6=0
        check_reg(6, 32'd0, "SUB_x6=0");

        // ============================================================
        // CYCLE 7: PC=0x18 — BEQ x6, x5, +8
        //   x6=0, x5=0 → branch TAKEN → PC jumps to 0x18+8 = 0x20
        //   No register write. Check PC on negedge after this step.
        // ============================================================
        step();   // execute BEQ (branch taken)
        if (uut.pc_out == 32'h20) begin
            $display("PASS [BEQ_TAKEN] PC jumped to 0x%08h", uut.pc_out);
            pass_cnt = pass_cnt + 1;
        end else begin
            $display("FAIL [BEQ_TAKEN] PC = 0x%08h (expected 0x00000020)", uut.pc_out);
            fail_cnt = fail_cnt + 1;
        end

        // ============================================================
        // CYCLE 8: PC=0x20 — ADDI x2, x0, 42  (0x1C was SKIPPED)
        // ============================================================
        step();   // execute ADDI x2=42
        check_reg(2, 32'd42, "ADDI_x2=42");
        // x6 must still be 0 — ADDI x6=99 at 0x1C was skipped
        check_reg(6, 32'd0,  "BEQ_SKIP_x6_not_99");

        // ============================================================
        // CYCLE 9-10: NOP × 2 (drain)
        // ============================================================
        step(); step();

        // ---- Final report ----
        $display("--------------------------------------------");
        $display(" Results: PASS=%0d  FAIL=%0d", pass_cnt, fail_cnt);
        if (fail_cnt == 0)
            $display(" ALL TESTS PASSED — CPU IS FUNCTIONAL ✓");
        else
            $display(" SOME TESTS FAILED — CHECK DATAPATH");
        $display("============================================");
        $finish;
    end

endmodule

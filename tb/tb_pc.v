`timescale 1ns / 1ps
// ============================================================
// Testbench : tb_pc.v
// Module    : pc.v
// Tests     : reset, sequential load, branch target, back-to-back
// ============================================================

module tb_pc;

    // ---- DUT ports ----
    reg         clk, reset;
    reg  [31:0] pc_next;
    wire [31:0] pc;

    // ---- Counters ----
    integer pass_cnt = 0;
    integer fail_cnt = 0;

    // ---- Instantiate DUT ----
    pc #(.DATA_WIDTH(32), .START_ADDR(32'h0)) uut (
        .clk(clk), .reset(reset), .pc_next(pc_next), .pc(pc)
    );

    // ---- 10 ns clock ----
    initial clk = 0;
    always #5 clk = ~clk;

    // ---- Check task ----
    task check;
        input [31:0] actual, expected;
        input [127:0] label;
        begin
            if (actual !== expected) begin
                $display("FAIL [%0s] got=%h expected=%h", label, actual, expected);
                fail_cnt = fail_cnt + 1;
            end else begin
                $display("PASS [%0s] pc=%h", label, actual);
                pass_cnt = pass_cnt + 1;
            end
        end
    endtask

    // ---- Stimulus ----
    initial begin
        $display("===== PC Testbench =====");
        reset = 1; pc_next = 32'h0;

        // TEST 1: Reset clears PC to 0
        @(posedge clk); #1;
        check(pc, 32'h0, "RESET_HOLDS");

        reset = 0;

        // TEST 2: Sequential increment (simulate pc_next = pc+4)
        pc_next = 32'h0000_0004; @(posedge clk); #1;
        check(pc, 32'h0000_0004, "INCREMENT_TO_4");

        pc_next = 32'h0000_0008; @(posedge clk); #1;
        check(pc, 32'h0000_0008, "INCREMENT_TO_8");

        // TEST 3: Branch target — jump to arbitrary address
        pc_next = 32'h0000_0020; @(posedge clk); #1;
        check(pc, 32'h0000_0020, "BRANCH_TO_0x20");

        // TEST 4: Jump backwards
        pc_next = 32'h0000_0008; @(posedge clk); #1;
        check(pc, 32'h0000_0008, "JUMP_BACK_0x8");

        // TEST 5: Reset mid-execution resets to 0
        reset = 1; @(posedge clk); #1;
        check(pc, 32'h0000_0000, "MID_RESET");

        // TEST 6: Resume after reset
        reset = 0; pc_next = 32'h0000_000C;
        @(posedge clk); #1;
        check(pc, 32'h0000_000C, "RESUME_AFTER_RESET");

        $display("---- Results: PASS=%0d  FAIL=%0d ----", pass_cnt, fail_cnt);
        if (fail_cnt == 0) $display("ALL TESTS PASSED");
        else               $display("SOME TESTS FAILED");
        $finish;
    end

endmodule

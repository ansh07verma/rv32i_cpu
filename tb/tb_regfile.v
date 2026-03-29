`timescale 1ns / 1ps
// ============================================================
// Testbench : tb_regfile.v
// Module    : regfile.v
// Tests     : write-read, x0 hardwired, we=0 no write,
//             simultaneous dual-read, overwrite
// ============================================================

module tb_regfile;

    reg         clk;
    reg         we;
    reg  [4:0]  rs1, rs2, rd;
    reg  [31:0] wd;
    wire [31:0] rd1, rd2;

    integer pass_cnt = 0;
    integer fail_cnt = 0;

    regfile #(.DATA_WIDTH(32), .REG_COUNT(32)) uut (
        .clk(clk), .we(we), .rs1(rs1), .rs2(rs2),
        .rd(rd), .wd(wd), .rd1(rd1), .rd2(rd2)
    );

    initial clk = 0;
    always #5 clk = ~clk;

    task check;
        input [31:0] actual, expected;
        input [127:0] label;
        begin
            if (actual !== expected) begin
                $display("FAIL [%0s] got=%h expected=%h", label, actual, expected);
                fail_cnt = fail_cnt + 1;
            end else begin
                $display("PASS [%0s] = %h", label, actual);
                pass_cnt = pass_cnt + 1;
            end
        end
    endtask

    task write_reg;
        input [4:0]  addr;
        input [31:0] data;
        begin
            rd = addr; wd = data; we = 1;
            @(posedge clk); #1;
            we = 0;
        end
    endtask

    initial begin
        $display("===== RegFile Testbench =====");
        we = 0; rs1 = 0; rs2 = 0; rd = 0; wd = 0;
        @(posedge clk); #1;

        // TEST 1: Write x5=0xDEAD_BEEF, read back on rs1
        write_reg(5, 32'hDEAD_BEEF);
        rs1 = 5; #1;
        check(rd1, 32'hDEAD_BEEF, "WRITE_READ_x5");

        // TEST 2: x0 always reads 0 — attempt to write it
        write_reg(0, 32'hFFFF_FFFF);
        rs1 = 0; #1;
        check(rd1, 32'h0000_0000, "X0_HARDWIRED_0");

        // TEST 3: we=0 — write should not occur
        rs1 = 5; we = 0; rd = 5; wd = 32'h1234_5678;
        @(posedge clk); #1;
        check(rd1, 32'hDEAD_BEEF, "WE0_NO_OVERWRITE_x5");

        // TEST 4: Dual simultaneous read (rs1=x5, rs2=x6)
        write_reg(6, 32'hCAFE_BABE);
        rs1 = 5; rs2 = 6; #1;
        check(rd1, 32'hDEAD_BEEF, "DUAL_READ_rs1_x5");
        check(rd2, 32'hCAFE_BABE, "DUAL_READ_rs2_x6");

        // TEST 5: Read x0 on both ports simultaneously
        rs1 = 0; rs2 = 0; #1;
        check(rd1, 32'h0, "X0_PORT1");
        check(rd2, 32'h0, "X0_PORT2");

        // TEST 6: Overwrite existing register
        write_reg(5, 32'h0000_FFFF);
        rs1 = 5; #1;
        check(rd1, 32'h0000_FFFF, "OVERWRITE_x5");

        // TEST 7: All 32-bit pattern (max value)
        write_reg(31, 32'hFFFF_FFFF);
        rs1 = 31; #1;
        check(rd1, 32'hFFFF_FFFF, "MAX_VALUE_x31");

        $display("---- Results: PASS=%0d  FAIL=%0d ----", pass_cnt, fail_cnt);
        if (fail_cnt == 0) $display("ALL TESTS PASSED");
        $finish;
    end

endmodule

`timescale 1ns / 1ps
// ============================================================
// Testbench : tb_dmem.v
// Module    : dmem.v
// Tests     : write-read round-trip, multiple addresses,
//             we=0 no-write guard, zero init, consecutive ops
// ============================================================

module tb_dmem;

    reg         clk;
    reg         we;
    reg  [31:0] addr, wd;
    wire [31:0] rd;

    integer pass_cnt = 0;
    integer fail_cnt = 0;

    dmem #(.DATA_WIDTH(32), .MEM_DEPTH(256)) uut (
        .clk(clk), .we(we), .addr(addr), .wd(wd), .rd(rd)
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

    task mem_write;
        input [31:0] a, d;
        begin
            addr = a; wd = d; we = 1;
            @(posedge clk); #1;
            we = 0;
        end
    endtask

    initial begin
        $display("===== DMEM Testbench =====");
        we = 0; addr = 0; wd = 0;
        @(posedge clk); #1;

        // TEST 1: Zero init — all locations should read 0
        addr = 32'd0; #1;
        check(rd, 32'h0, "ZERO_INIT_addr0");

        // TEST 2: Write 0xDEAD_BEEF to address 0x0, read back
        mem_write(32'h0, 32'hDEAD_BEEF);
        addr = 32'h0; #1;
        check(rd, 32'hDEAD_BEEF, "WRITE_READ_addr0");

        // TEST 3: Write to address 0x4 (word 1)
        mem_write(32'h4, 32'hCAFE_BABE);
        addr = 32'h4; #1;
        check(rd, 32'hCAFE_BABE, "WRITE_READ_addr4");

        // TEST 4: Address 0x0 still holds its value (no aliasing)
        addr = 32'h0; #1;
        check(rd, 32'hDEAD_BEEF, "NO_ALIAS_AFTER_ADDR4_WRITE");

        // TEST 5: we=0 — write should NOT happen
        addr = 32'h8; wd = 32'h1234_5678; we = 0;
        @(posedge clk); #1;
        check(rd, 32'h0, "WE0_NO_WRITE_addr8");

        // TEST 6: Write to last word address (word 255 = byte 0x3FC)
        mem_write(32'h3FC, 32'hFFFF_FFFF);
        addr = 32'h3FC; #1;
        check(rd, 32'hFFFF_FFFF, "WRITE_READ_LAST_WORD");

        // TEST 7: Overwrite address 0x4
        mem_write(32'h4, 32'h0000_0001);
        addr = 32'h4; #1;
        check(rd, 32'h0000_0001, "OVERWRITE_addr4");

        $display("---- Results: PASS=%0d  FAIL=%0d ----", pass_cnt, fail_cnt);
        if (fail_cnt == 0) $display("ALL TESTS PASSED");
        $finish;
    end

endmodule

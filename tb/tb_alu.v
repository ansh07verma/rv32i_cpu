`timescale 1ns / 1ps
// ============================================================
// Testbench : tb_alu.v
// Module    : alu.v
// Tests     : all 11 operations, zero flag, edge cases
// ============================================================

module tb_alu;

    reg  [31:0] a, b;
    reg  [3:0]  alu_ctrl;
    wire [31:0] result;
    wire        zero;

    integer pass_cnt = 0;
    integer fail_cnt = 0;

    alu #(.DATA_WIDTH(32)) uut (
        .a(a), .b(b), .alu_ctrl(alu_ctrl), .result(result), .zero(zero)
    );

    task check_result;
        input [31:0] exp_result;
        input        exp_zero;
        input [127:0] label;
        begin
            if (result !== exp_result || zero !== exp_zero) begin
                $display("FAIL [%0s] result=%h(%b) expected=%h(%b)",
                          label, result, zero, exp_result, exp_zero);
                fail_cnt = fail_cnt + 1;
            end else begin
                $display("PASS [%0s] result=%h zero=%b", label, result, zero);
                pass_cnt = pass_cnt + 1;
            end
        end
    endtask

    initial begin
        $display("===== ALU Testbench =====");

        // ---- ADD (0000) ----------------------------------------
        a=32'd15;      b=32'd10;      alu_ctrl=4'b0000; #10;
        check_result(32'd25,           0, "ADD_15+10");

        a=32'd0;       b=32'd0;       alu_ctrl=4'b0000; #10;
        check_result(32'd0,            1, "ADD_zero_flag");

        a=32'hFFFF_FFFF; b=32'd1;    alu_ctrl=4'b0000; #10;
        check_result(32'h0,            1, "ADD_overflow_wrap");

        // ---- SUB (0001) ----------------------------------------
        a=32'd20;      b=32'd7;       alu_ctrl=4'b0001; #10;
        check_result(32'd13,           0, "SUB_20-7");

        a=32'd5;       b=32'd5;       alu_ctrl=4'b0001; #10;
        check_result(32'd0,            1, "SUB_equal_zero");

        // ---- AND (0010) ----------------------------------------
        a=32'hFF00_FF00; b=32'h0F0F_0F0F; alu_ctrl=4'b0010; #10;
        check_result(32'h0F00_0F00,    0, "AND");

        // ---- OR (0011) -----------------------------------------
        a=32'hF0F0_0000; b=32'h0F0F_0000; alu_ctrl=4'b0011; #10;
        check_result(32'hFFFF_0000,    0, "OR");

        // ---- XOR (0100) ----------------------------------------
        a=32'hAAAA_AAAA; b=32'hAAAA_AAAA; alu_ctrl=4'b0100; #10;
        check_result(32'h0,            1, "XOR_same_zero");

        a=32'hAAAA_AAAA; b=32'h5555_5555; alu_ctrl=4'b0100; #10;
        check_result(32'hFFFF_FFFF,    0, "XOR_complement");

        // ---- SLL (0101) ----------------------------------------
        a=32'h0000_0001; b=32'd4;     alu_ctrl=4'b0101; #10;
        check_result(32'h0000_0010,    0, "SLL_1<<4");

        a=32'h0000_0001; b=32'd31;    alu_ctrl=4'b0101; #10;
        check_result(32'h8000_0000,    0, "SLL_1<<31");

        // ---- SRL (0110) ----------------------------------------
        a=32'hFFFF_FFFF; b=32'd4;     alu_ctrl=4'b0110; #10;
        check_result(32'h0FFF_FFFF,    0, "SRL_logical_shift");

        // ---- SRA (0111) ----------------------------------------
        a=32'hFFFF_FFFF; b=32'd4;     alu_ctrl=4'b0111; #10;
        check_result(32'hFFFF_FFFF,    0, "SRA_arithmetic_neg");

        a=32'h7FFF_FFFF; b=32'd4;     alu_ctrl=4'b0111; #10;
        check_result(32'h07FF_FFFF,    0, "SRA_arithmetic_pos");

        // ---- SLT (1000) ----------------------------------------
        a=32'hFFFF_FFFF; b=32'd1;     alu_ctrl=4'b1000; #10;  // -1 < 1
        check_result(32'd1,            0, "SLT_neg_lt_pos");

        a=32'd5;       b=32'd5;       alu_ctrl=4'b1000; #10;
        check_result(32'd0,            1, "SLT_equal");

        // ---- SLTU (1001) ---------------------------------------
        a=32'hFFFF_FFFF; b=32'd1;     alu_ctrl=4'b1001; #10;  // large < small unsigned? NO
        check_result(32'd0,            1, "SLTU_0xFFFF<1=false");

        a=32'd1; b=32'hFFFF_FFFF;     alu_ctrl=4'b1001; #10;  // 1 < large: YES
        check_result(32'd1,            0, "SLTU_1<0xFFFF=true");

        // ---- LUI pass (1010) -----------------------------------
        a=32'hDEAD_BEEF; b=32'hABCD_0000; alu_ctrl=4'b1010; #10;
        check_result(32'hABCD_0000,    0, "LUI_pass_b");

        $display("---- Results: PASS=%0d  FAIL=%0d ----", pass_cnt, fail_cnt);
        if (fail_cnt == 0) $display("ALL TESTS PASSED");
        $finish;
    end

endmodule

`timescale 1ns/1ps

// ============================================================
// Module: tb_phase5_top.sv
// Description: Advanced System-Level Unified Testbench
//   - SystemVerilog dynamically looping execution
//   - Edge Case validation (x0 protections, traps)
//   - Self-checking golden assertions
// Project: RV32I Single-Cycle Processor — Phase 5
// ============================================================

module tb_phase5_top;

    reg clk;
    reg reset;
    wire trap;

    // Instantiate Top-Level CPU
    rv32i_cpu uut (
        .clk(clk),
        .reset(reset),
        .trap(trap),
        .dbg_reg_write  (),
        .dbg_mem_read   (),
        .dbg_mem_write  (),
        .dbg_rd         (),
        .dbg_rs1        (),
        .dbg_rs2        (),
        .dbg_write_data (),
        .dbg_alu_a      (),
        .dbg_alu_b      (),
        .dbg_alu_result (),
        .dbg_zero       ()
    );

    // Dynamic array of test programs
    string tests[] = '{
        "C:/rv32i_cpu/sim/test_programs/prog_arith.mem",
        "C:/rv32i_cpu/sim/test_programs/prog_memops.mem",
        "C:/rv32i_cpu/sim/test_programs/prog_loop.mem",
        "C:/rv32i_cpu/sim/test_programs/prog_edgecases.mem"
    };

    int pass_cnt, fail_cnt;

    // 100MHz Clock Generation
    initial clk = 0;
    always #5 clk = ~clk;

    // Golden verification routines
    task check_reg(int rn, logic [31:0] exp, string lbl);
        logic [31:0] got;
        got = uut.u_regfile.regs[rn];
        if (got !== exp) begin
            $error("[FAIL] %s: x%0d = 0x%08h (expected 0x%08h)", lbl, rn, got, exp);
            fail_cnt++;
        end else begin
            $display("[PASS] %s: x%0d = 0x%08h", lbl, rn, got);
            pass_cnt++;
        end
    endtask

    task check_mem(logic [31:0] baddr, logic [31:0] exp, string lbl);
        logic [31:0] got;
        got = uut.u_dmem.mem[baddr >> 2];
        if (got !== exp) begin
            $error("[FAIL] %s: MEM[0x%08h] = 0x%08h (expected 0x%08h)", lbl, baddr, got, exp);
            fail_cnt++;
        end else begin
            $display("[PASS] %s: MEM[0x%08h] = 0x%08h", lbl, baddr, got);
            pass_cnt++;
        end
    endtask

    // Execution stepper
    task step(int cycles);
        repeat(cycles) begin
            @(posedge clk);
            if (trap) begin
               $display("[CPU EXCEPTION] Illegal Instruction trapped perfectly at PC=0x%08h", uut.pc_out);
               break; // Exit early if we intentionally hit a trap
            end
        end
        @(negedge clk); // Settle logic before asserting
    endtask

    initial begin
        $display("=================================================");
        $display(" SYSTEM-LEVEL ADVANCED UNIFIED TESTBENCH (SV)    ");
        $display("=================================================");
        pass_cnt = 0;
        fail_cnt = 0;

        foreach (tests[i]) begin
            $display("\n-------------------------------------------------");
            $display(" RUNNING PROGRAM: %s", tests[i]);
            $display("-------------------------------------------------");

            // Clear internal memories and registers dynamically to simulate hard power-on for new test
            for(int j=0; j<32; j++) uut.u_regfile.regs[j] = 0;
            
            // Load program memory
            $readmemh(tests[i], uut.imem_inst.mem);

            // CPU Hardware Reset
            reset = 1; repeat(2) @(posedge clk); @(negedge clk); reset = 0;

            if (tests[i] == "C:/rv32i_cpu/sim/test_programs/prog_arith.mem") begin
                step(1); check_reg(1, 20, "x1 Initialization");
                step(1); check_reg(2, 7,  "x2 Initialization");
                step(1); check_reg(3, 27, "ADD (20+7)");
                step(1); check_reg(4, 13, "SUB (20-7)");
                step(1); check_reg(5, 4,  "AND");
                step(1); check_reg(6, 23, "OR");
                step(1); check_reg(7, 19, "XOR");
                step(1); check_reg(8, 1,  "Immediate Load");
                step(1); check_reg(9, 54, "SLL (27<<1)");
                step(1); check_reg(10, 0, "SLT (20<7 = False)");
                step(1); check_reg(10, 1, "SLT (7<20 = True)");
            end
            else if (tests[i] == "C:/rv32i_cpu/sim/test_programs/prog_memops.mem") begin
                step(3); // Wait for sequence setup
                step(3); // Execute Stores
                check_mem(0, 32'h00A5, "Store at Base+0");
                check_mem(4, 32'h003C, "Store at Base+4");
                check_mem(8, 32'h0011, "Store at Base+8");
                step(3); // Execute Loads
                step(2); // Execute accumulating Adds
                step(1); check_mem(12, 32'h00F2, "Final Memory Result (MEM[12])");
                step(1); check_reg(14, 32'h00F2, "Memory Readback Verify (x14)");
            end
            else if (tests[i] == "C:/rv32i_cpu/sim/test_programs/prog_loop.mem") begin
                step(20); // Let the entire loop boundary run to exhaustion
                check_reg(4, 10, "Exit ADD Result (x4 matches loop accum)");
            end
            else if (tests[i] == "C:/rv32i_cpu/sim/test_programs/prog_edgecases.mem") begin
                step(1); check_reg(0, 0, "Hardware Zero Register Immutability");
                step(1); check_reg(1, 10, "x1 setup");
                step(1); check_reg(2, 32'hFFFF_FFFB, "Signed Immediate Load (-5)");
                step(1); check_reg(3, 0, "Signed SLT Check (10 < -5 = False)");
                step(1); check_reg(4, 1, "Signed SLT Check (-5 < 10 = True)");
                // The step(1) above fetched the undefined Opcode (0xFFFFFFFF) on its positive edge.
                // Since Control is combinational, trap is already asserted right now on the negative edge!
                if (trap) begin
                    $display("[PASS] CPU Identified and Trapped Illegal Opcode Perfectly");
                    pass_cnt++;
                end else begin
                    $error("[FAIL] Trap was completely missed. Control logic failure.");
                    fail_cnt++;
                end
            end

            $display("-> Completed Execution Context: %s", tests[i]);
        end

        $display("\n=================================================");
        $display(" FINAL RV32I RTL VERIFICATION RESULTS            ");
        $display(" OVERALL PASS : %0d                              ", pass_cnt);
        $display(" OVERALL FAIL : %0d                              ", fail_cnt);
        if (fail_cnt == 0) $display(" PHASE 5 VERIFICATION + OPTIMIZATION COMPLETE ✓");
        else               $error(" ASSERTIONS FAILED. CHECK THE CONSOLE STACK TRACE");
        $display("=================================================");
        $finish;
    end
endmodule

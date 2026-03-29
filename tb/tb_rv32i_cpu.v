`timescale 1ns / 1ps
// ============================================================
// Testbench: tb_rv32i_cpu.v
// Description: Top-level testbench for RV32I Single-Cycle CPU
//   - 10ns clock (100 MHz)
//   - 2-cycle reset
//   - 50-cycle simulation window
//   - Per-cycle $display monitor
//   - VCD waveform dump for GTKWave / Vivado
// Project: RV32I Single-Cycle Processor
// ============================================================

module tb_rv32i_cpu;

    // ---- DUT Ports ----
    reg clk;
    reg reset;

    // ---- Instantiate DUT ----
    rv32i_cpu uut (
        .clk   (clk),
        .reset (reset)
    );

    // ---- Clock: 10ns period = 100 MHz ----
    initial clk = 1'b0;
    always #5 clk = ~clk;

    // ---- Reset Sequence ----
    initial begin
        reset = 1'b1;
        @(posedge clk); // Wait one rising edge
        @(posedge clk); // Hold reset for 2 cycles
        reset = 1'b0;
    end

    // ---- Simulation End ----
    initial begin
        #500;
        $display("=== SIMULATION COMPLETE ===");
        $finish;
    end

    // ---- Waveform Dump (for GTKWave or Vivado) ----
    initial begin
        $dumpfile("tb_rv32i_cpu.vcd");
        $dumpvars(0, tb_rv32i_cpu);
    end

    // ---- Per-Cycle Monitor ----
    always @(posedge clk) begin
        if (!reset) begin
            $display("T=%0t | PC=%h | INSTR=%h | RegWrite=%b | MemWrite=%b | ALU_Result=%h",
                $time,
                uut.pc_out,
                uut.instr,
                uut.reg_write,
                uut.mem_write,
                uut.alu_result
            );
        end
    end

endmodule

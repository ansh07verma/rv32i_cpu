// ============================================================
// Module: imem.v
// Description: Instruction Memory — parameterized combinational ROM
//   - MEM_DEPTH words of 32-bit instructions
//   - Loaded from MEM_FILE via $readmemh at simulation start
//   - Word-addressed: addr[9:2] selects the 32-bit word
//   - Combinational (single-cycle) read — no clock required
//
// Parameters:
//   MEM_DEPTH : number of 32-bit words (default 256 = 1 KB)
//   MEM_FILE  : path to .mem file (passed by top-level or testbench)
//
// Project: RV32I Single-Cycle Processor — Phase 4
// ============================================================

module imem #(
    parameter MEM_DEPTH = 256,
    parameter MEM_FILE  = "C:/rv32i_cpu/sim/test_programs/prog_arith.mem"
)(
    input  wire [31:0] addr,
    output wire [31:0] instr
);

    reg [31:0] mem [0:MEM_DEPTH-1];

    integer i;
    initial begin
        // Zero-initialise first so uninitialised words are predictable
        for (i = 0; i < MEM_DEPTH; i = i + 1)
            mem[i] = 32'h0000_0013;   // NOP (ADDI x0,x0,0)

        // Load program image.  $readmemh accepts relative OR absolute paths.
        // In Vivado xsim the CWD is deep inside the project tree, so always
        // pass an absolute path from the top-level parameter or $readmemh call.
        $readmemh(MEM_FILE, mem);
        $display("[IMEM] Loaded '%s'  mem[0]=%h  mem[1]=%h  mem[2]=%h",
                  MEM_FILE, mem[0], mem[1], mem[2]);
    end

    // Combinational word-addressed read
    // addr[9:2] = word index (byte address >> 2), upper bits ignored at this depth
    assign instr = mem[addr[9:2]];

endmodule

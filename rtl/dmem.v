// ============================================================
// Module: dmem.v
// Description: Data Memory — 256 x 32-bit SRAM model
//   - Combinational read
//   - Synchronous write (on rising clock edge)
// Project: RV32I Single-Cycle Processor
// ============================================================

module dmem (
    input  wire        clk,
    input  wire        we,          // MemWrite — write enable
    input  wire [31:0] addr,        // Byte address (from ALU result)
    input  wire [31:0] wd,          // Write data (rs2_data)
    output wire [31:0] rd           // Read data (to WB mux)
);

    reg [31:0] mem [0:255];

    integer i;
    initial begin
        for (i = 0; i < 256; i = i + 1)
            mem[i] = 32'b0;
    end

    // Synchronous write
    always @(posedge clk) begin
        if (we)
            mem[addr[9:2]] <= wd;
    end

    // Combinational read (word-addressed)
    assign rd = mem[addr[9:2]];

endmodule

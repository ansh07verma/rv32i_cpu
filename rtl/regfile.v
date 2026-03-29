// ============================================================
// Module: regfile.v
// Description: Register File — 32 x 32-bit
//   - 2 async read ports (rs1, rs2)
//   - 1 sync write port  (rd)
//   - x0 (register 0) hardwired to 0
// Project: RV32I Single-Cycle Processor
// ============================================================

module regfile (
    input  wire        clk,
    input  wire        we,          // RegWrite — write enable
    input  wire [4:0]  rs1,         // Read address 1
    input  wire [4:0]  rs2,         // Read address 2
    input  wire [4:0]  rd,          // Write address
    input  wire [31:0] wd,          // Write data
    output wire [31:0] rd1,         // Read data 1
    output wire [31:0] rd2          // Read data 2
);

    reg [31:0] regs [0:31];

    integer i;
    initial begin
        for (i = 0; i < 32; i = i + 1)
            regs[i] = 32'b0;
    end

    // Synchronous write — x0 is never written
    always @(posedge clk) begin
        if (we && (rd != 5'b0)) begin
            regs[rd] <= wd;
        end else if (we && (rd == 5'b0)) begin
            $error("[REGFILE/ASSERT] Illegal attempt to write to x0 (wd = 0x%08h). Write ignored.", wd);
        end
    end

    // Asynchronous read — x0 always returns 0
    assign rd1 = (rs1 == 5'b0) ? 32'b0 : regs[rs1];
    assign rd2 = (rs2 == 5'b0) ? 32'b0 : regs[rs2];

endmodule

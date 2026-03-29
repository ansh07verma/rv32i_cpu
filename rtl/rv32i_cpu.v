// ============================================================
// Module: rv32i_cpu.v
// Description: Top-Level — RV32I Single-Cycle Processor
//   Structural instantiation of all datapath blocks.
//
// Parameters:
//   MEM_DEPTH : IMEM/DMEM word depth (default 256 = 1 KB each)
//   MEM_FILE  : Absolute path to .mem program image (passed to imem)
//
// Project: RV32I Single-Cycle Processor — Phase 4
// ============================================================

module rv32i_cpu #(
    parameter integer MEM_DEPTH = 256,
    parameter         MEM_FILE  = "C:/rv32i_cpu/sim/test_programs/prog_arith.mem"
)(
    input  wire clk,
    input  wire reset,
    output wire trap,

    // ============================================================
    // Debug Visibility / Telemetry Ports
    // ============================================================
    output wire        dbg_reg_write,
    output wire        dbg_mem_read,
    output wire        dbg_mem_write,
    output wire [4:0]  dbg_rd,
    output wire [4:0]  dbg_rs1,
    output wire [4:0]  dbg_rs2,
    output wire [31:0] dbg_write_data,
    output wire [31:0] dbg_alu_a,
    output wire [31:0] dbg_alu_b,
    output wire [31:0] dbg_alu_result,
    output wire        dbg_zero
);

    // ============================================================
    // Internal Wires — Datapath Interconnects
    // ============================================================

    // --- PC Stage ---
    wire [31:0] pc_out;         // Current PC
    wire [31:0] pc_next;        // Next PC (to PC register)
    wire [31:0] pc_plus4;       // PC + 4
    wire [31:0] pc_branch;      // PC + imm_ext (branch/JAL target)

    // --- Instruction Decode ---
    wire [31:0] instr;          // Raw 32-bit instruction from IMEM
    wire [6:0]  opcode;         // instr[6:0]
    wire [4:0]  rd_addr;        // instr[11:7]
    wire [2:0]  funct3;         // instr[14:12]
    wire [4:0]  rs1_addr;       // instr[19:15]
    wire [4:0]  rs2_addr;       // instr[24:20]
    wire        funct7_5;       // instr[30]

    // --- Register File ---
    wire [31:0] rs1_data;       // Read data 1
    wire [31:0] rs2_data;       // Read data 2
    wire [31:0] write_data;     // Data written back to register file

    // --- Immediate Generator ---
    wire [31:0] imm_ext;        // Sign-extended immediate

    // --- ALU ---
    wire [31:0] alu_b;          // ALU B operand (after MUX_ALUSrc)
    wire [31:0] alu_result;     // ALU computation result
    wire        alu_zero;       // ALU zero flag (for branch)
    wire [3:0]  alu_ctrl_sig;   // 4-bit ALU operation selector

    // --- Data Memory ---
    wire [31:0] mem_read_data;  // Data read from DMEM

    // --- Control Signals ---
    wire        reg_write;
    wire [2:0]  imm_src;
    wire        alu_src;
    wire        mem_write;
    wire [1:0]  result_src;
    wire        branch;
    wire        jump;
    wire [2:0]  alu_op;

    // --- PC Source Logic ---
    wire        pc_src_branch;  // branch taken: branch & zero (BEQ)
    wire [1:0]  pc_src;         // MUX_PC selector

    // ============================================================
    // Instruction Field Extraction (Combinational)
    // ============================================================
    assign opcode   = instr[6:0];
    assign rd_addr  = instr[11:7];
    assign funct3   = instr[14:12];
    assign rs1_addr = instr[19:15];
    assign rs2_addr = instr[24:20];
    assign funct7_5 = instr[30];

    // ============================================================
    // PC Next Logic
    // ============================================================
    assign pc_plus4      = pc_out + 32'd4;
    assign pc_branch     = pc_out + imm_ext;           // branch / JAL offset
    assign pc_src_branch = branch & alu_zero;           // BEQ taken when zero
    assign pc_src        = (jump | pc_src_branch) ? 2'b01 : 2'b00;
    assign pc_next       = (pc_src == 2'b01) ? pc_branch : pc_plus4;

    // Write-back MUX (MUX_WB)
    assign write_data = (result_src == 2'b00) ? alu_result   :
                        (result_src == 2'b01) ? mem_read_data :
                                                pc_plus4;      // JAL/JALR link

    // ALU Source MUX (MUX_ALUSrc)
    assign alu_b = alu_src ? imm_ext : rs2_data;

    // ============================================================
    // Module Instantiations
    // ============================================================

    // --- Program Counter ---
    pc pc_inst (
        .clk     (clk),
        .reset   (reset),
        .pc_next (pc_next),
        .pc      (pc_out)
    );

    // --- Instruction Memory (parameterized) ---
    imem #(
        .MEM_DEPTH (MEM_DEPTH),
        .MEM_FILE  (MEM_FILE)
    ) imem_inst (
        .addr  (pc_out),
        .instr (instr)
    );

    // --- Main Control Unit ---
    control ctrl_inst (
        .opcode     (opcode),
        .reg_write  (reg_write),
        .imm_src    (imm_src),
        .alu_src    (alu_src),
        .mem_write  (mem_write),
        .result_src (result_src),
        .branch     (branch),
        .jump       (jump),
        .alu_op     (alu_op),
        .trap       (trap)
    );

    // --- Register File ---
    regfile u_regfile (
        .clk  (clk),
        .we   (reg_write),
        .rs1  (rs1_addr),
        .rs2  (rs2_addr),
        .rd   (rd_addr),
        .wd   (write_data),
        .rd1  (rs1_data),
        .rd2  (rs2_data)
    );

    // --- Immediate Generator ---
    imm_gen imm_gen_inst (
        .instr   (instr),
        .imm_src (imm_src),
        .imm_ext (imm_ext)
    );

    // --- ALU Control Sub-Decoder ---
    alu_ctrl alu_ctrl_inst (
        .alu_op   (alu_op),
        .funct3   (funct3),
        .funct7_5 (funct7_5),
        .alu_ctrl (alu_ctrl_sig)
    );

    // --- ALU ---
    alu alu_inst (
        .a        (rs1_data),
        .b        (alu_b),
        .alu_ctrl (alu_ctrl_sig),
        .result   (alu_result),
        .zero     (alu_zero)
    );

    // --- Data Memory ---
    dmem u_dmem (
        .clk  (clk),
        .we   (mem_write),
        .addr (alu_result),
        .wd   (rs2_data),
        .rd   (mem_read_data)
    );

    // ============================================================
    // Debug Telemetry Routing
    // ============================================================
    assign dbg_reg_write  = reg_write;
    assign dbg_mem_read   = (result_src == 2'b01);  // MemRead active when WB MUX selects Memory
    assign dbg_mem_write  = mem_write;
    assign dbg_rd         = rd_addr;
    assign dbg_rs1        = rs1_addr;
    assign dbg_rs2        = rs2_addr;
    assign dbg_write_data = write_data;
    assign dbg_alu_a      = rs1_data;
    assign dbg_alu_b      = alu_b;
    assign dbg_alu_result = alu_result;
    assign dbg_zero       = alu_zero;

endmodule

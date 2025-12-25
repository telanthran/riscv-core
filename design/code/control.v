module control 
(
    input wire reset,
    input wire [6:0]    opcode,
    input wire [2:0]    funct3,
    input wire [6:0]    funct7,
    output reg          alu_src_A,
    output reg          alu_src_B,
    output reg [3:0]    ALUSel,
    output reg          MemRW,
    output reg [1:0]    access_size,
    output reg          RegWEn,
    output reg [1:0]    WBSel  // source of writeback (alu, memory, or pc+4 from a jump)
);

`include "defines.vh"

// we want to vary how the pc increments and whether to wb depending on op.
always @(*) begin
    alu_src_A = `ALU_A_DONTCARE;
    alu_src_B = `ALU_B_DONTCARE;
    ALUSel = `ALU_DONTCARE;
    RegWEn = `REG_NOWRITE;
    WBSel = `WB_DONTCARE;
    MemRW = `DMEM_NOWRITE;
    access_size = `DMEM_SIZE_DONTCARE;
    case (opcode)
        `OPCODE_R: begin 
            // rd = rs1 _ rs2
            alu_src_A = `ALU_A_RS1;
            alu_src_B = `ALU_B_RS2;
            MemRW = `DMEM_NOWRITE;
            RegWEn = `REG_WRITE;
            WBSel = `WB_ALU;
            access_size = `DMEM_SIZE_DONTCARE;

            case (funct3)
                `FUNCT3_ADDSUB: ALUSel = (funct7 == `FUNCT7_SUB) ? `ALU_SUB : `ALU_ADD;
                `FUNCT3_XOR: ALUSel = `ALU_XOR;
                `FUNCT3_OR: ALUSel = `ALU_OR;
                `FUNCT3_AND: ALUSel = `ALU_AND;
                `FUNCT3_SLL: ALUSel = `ALU_SLL;
                `FUNCT3_SRLSRA: ALUSel = (funct7 == `FUNCT7_SRL) ? `ALU_SRL : `ALU_SRA;
                `FUNCT3_SLT: ALUSel = `ALU_SLT;
                `FUNCT3_SLTU: ALUSel = `ALU_SLTU;
            default: ALUSel = `ALU_ADD; // no reasoning, just prevent latch
            endcase
        end
        `OPCODE_I_IMM: begin
            // rd = rs1 _ imm
            alu_src_A = `ALU_A_RS1;
            alu_src_B = `ALU_B_IMM;
            MemRW = `DMEM_NOWRITE;
            RegWEn = `REG_WRITE;
            WBSel = `WB_ALU;

            case(funct3)
                `FUNCT3_ADDI: ALUSel = `ALU_ADD;
                `FUNCT3_XORI: ALUSel = `ALU_XOR;
                `FUNCT3_ORI: ALUSel = `ALU_OR;
                `FUNCT3_ANDI: ALUSel = `ALU_AND;
                `FUNCT3_SLLI: ALUSel = `ALU_SLL;
                `FUNCT3_SRLISRAI: ALUSel = (funct7 == `FUNCT7_SRLI) ? `ALU_SRL : `ALU_SRA;
                `FUNCT3_SLTI: ALUSel = `ALU_SLT;
                `FUNCT3_SLTIU: ALUSel = `ALU_SLTU;
            default: ALUSel = `ALU_ADD; // no reasoning, just prevent latch
            endcase
        end
        `OPCODE_I_LOAD: begin
            // rd = M[rs1 + imm] (just displacement addr calculation)
            alu_src_A = `ALU_A_RS1;
            alu_src_B = `ALU_B_IMM;
            ALUSel = `ALU_ADD;
            MemRW = `DMEM_NOWRITE;
            RegWEn = `REG_WRITE;
            WBSel = `WB_MEM; // the data comes from memory

            case(funct3)
                `FUNCT3_LW:  access_size = `DMEM_SIZE_WORD;
                `FUNCT3_LH:  access_size = `DMEM_SIZE_HALF;
                `FUNCT3_LB:  access_size = `DMEM_SIZE_BYTE;
                `FUNCT3_LHU: access_size = `DMEM_SIZE_HALF;
                `FUNCT3_LBU: access_size = `DMEM_SIZE_BYTE;
            default: access_size = `DMEM_SIZE_WORD;
            endcase
        end
        `OPCODE_I_JALR: begin
            // rd = rs1 + imm (just jump target addr calculation)
            alu_src_A = `ALU_A_RS1;
            alu_src_B = `ALU_B_IMM;
            ALUSel = `ALU_ADD;
            MemRW = `DMEM_NOWRITE;
            RegWEn = `REG_WRITE;
            WBSel = `WB_PC4; // save link
        end
        `OPCODE_S: begin
            // M[rs1 + imm] (just displacement addr calculation)
            alu_src_A = `ALU_A_RS1;
            alu_src_B = `ALU_B_IMM;
            ALUSel = `ALU_ADD;
            MemRW = `DMEM_WRITE;
            RegWEn = `REG_NOWRITE; // stores DO NOT write to register
            WBSel = `WB_DONTCARE; // any no write = don't care

            case(funct3)
                `FUNCT3_SW: access_size = `DMEM_SIZE_WORD;
                `FUNCT3_SH: access_size = `DMEM_SIZE_HALF;
                `FUNCT3_SB: access_size = `DMEM_SIZE_BYTE;
            default: access_size = `DMEM_SIZE_WORD;
            endcase
        end
        `OPCODE_B: begin
            // pc = pc + imm (just branch target addr calculation)
            // may or may not use this addr depending on branch comp
            alu_src_A = `ALU_A_PC;
            alu_src_B = `ALU_B_IMM;
            ALUSel = `ALU_ADD;
            MemRW = `DMEM_NOWRITE;
            RegWEn = `REG_NOWRITE; // branching DOES NOT write to register
            WBSel = `WB_DONTCARE;
            access_size = `DMEM_SIZE_HALF;
        end
        `OPCODE_U_LUI: begin
            // rd = imm
            alu_src_A = `ALU_A_RS1; // who cares lah
            alu_src_B = `ALU_B_IMM;
            ALUSel = `ALU_COPY_B;
            MemRW = `DMEM_NOWRITE;
            RegWEn = `REG_WRITE;
            WBSel = `WB_ALU;
        end
        `OPCODE_U_AUIPC: begin
            // rd = pc + imm
            alu_src_A = `ALU_A_PC;
            alu_src_B = `ALU_B_IMM;
            ALUSel = `ALU_ADD;
            MemRW = `DMEM_NOWRITE;
            RegWEn = `REG_WRITE;
            WBSel = `WB_ALU;
        end
        `OPCODE_J: begin
            // pc = pc + imm
            alu_src_A = `ALU_A_PC;
            alu_src_B = `ALU_B_IMM;
            ALUSel = `ALU_ADD;
            MemRW = `DMEM_NOWRITE;
            RegWEn = `REG_WRITE;
            WBSel = `WB_PC4; // save link
        end
        `OPCODE_FENCE: begin
            // FENCE is essentially a NOP that writes to rd
            alu_src_A = `ALU_A_DONTCARE;
            alu_src_B = `ALU_B_DONTCARE;
            ALUSel = `ALU_ADD;
            MemRW = `DMEM_NOWRITE;
            RegWEn = `REG_WRITE;
            WBSel = `WB_ALU;
        end
        `OPCODE_SYSTEM: begin
            // ECALL, EBREAK, etc. - treat as NOP (no write)
            alu_src_A = `ALU_A_DONTCARE;
            alu_src_B = `ALU_B_DONTCARE;
            ALUSel = `ALU_ADD;
            MemRW = `DMEM_NOWRITE;
            RegWEn = `REG_NOWRITE;
            WBSel = `WB_DONTCARE;
        end
        default: begin
            alu_src_A = `ALU_A_DONTCARE;
            alu_src_B = `ALU_B_DONTCARE;
            ALUSel = `ALU_DONTCARE;
            MemRW = `DMEM_NOWRITE;
            access_size = `DMEM_SIZE_DONTCARE;
            RegWEn = `REG_NOWRITE;
            WBSel = `WB_DONTCARE;
        end
    endcase

    if (reset) begin
        RegWEn = 1'b0;
    end
end
endmodule
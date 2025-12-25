
/* Your Code Below! Enable the following define's 
 * and replace ??? with actual wires */
// ----- signals -----
// You will also need to define PC properly
`define F_PC                pc
`define F_INSN              F_instruction

`define D_PC                FD_pc
`define D_OPCODE            D_opcode
`define D_RD                D_rd_addr
`define D_RS1               D_rs1_addr
`define D_RS2               D_rs2_addr
`define D_FUNCT3            D_funct3
`define D_FUNCT7            D_funct7
`define D_IMM               D_imm
`define D_SHAMT             D_shamt

// write ports connected to writeback stage
`define R_WRITE_ENABLE      MW_RegWEn
`define R_WRITE_DESTINATION MW_rd_addr
`define R_WRITE_DATA        MW_wb_data
// read ports connected to decode stage
`define R_READ_RS1          D_rs1_addr
`define R_READ_RS2          D_rs2_addr
`define R_READ_RS1_DATA     D_rs1_data
`define R_READ_RS2_DATA     D_rs2_data

`define E_PC                DX_pc
`define E_ALU_RES           X_alu_result
`define E_BR_TAKEN          X_br_taken

`define M_PC                XM_pc
`define M_ADDRESS           XM_alu_result
`define M_RW                XM_MemRW
`define M_SIZE_ENCODED      XM_access_size
`define M_DATA              M_dmem_data_in

`define W_PC                MW_pc
`define W_ENABLE            MW_RegWEn
`define W_DESTINATION       MW_rd_addr
`define W_DATA              MW_wb_data

// ----- signals -----

// ----- design -----
`define TOP_MODULE                 pd
// ----- design -----

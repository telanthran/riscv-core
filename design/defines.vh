/***** DECODER *****/
`define OPCODE_R        7'b0110011 //0x33

`define OPCODE_I_IMM    7'b0010011 // 0x13
`define OPCODE_I_LOAD   7'b0000011 // 0x03
`define OPCODE_I_JALR   7'b1100111 // 0x67

`define OPCODE_S        7'b0100011 // 0x23
`define OPCODE_B        7'b1100011 // 0x63

`define OPCODE_U_LUI    7'b0110111 // 0x37
`define OPCODE_U_AUIPC  7'b0010111 // 0x17

`define OPCODE_J        7'b1101111 // 0x6F

`define OPCODE_FENCE    7'b0001111 // 0x0F
`define OPCODE_SYSTEM   7'b1110011 // 0x73

/***** CONTROL *****/
// R-type
`define FUNCT3_ADDSUB       3'h0
`define FUNCT7_ADD          7'h0
`define FUNCT7_SUB          7'h20

`define FUNCT3_XOR          3'h4
`define FUNCT3_OR           3'h6
`define FUNCT3_AND          3'h7
`define FUNCT3_SLL          3'h1

`define FUNCT3_SRLSRA       3'h05
`define FUNCT7_SRL          7'h00
`define FUNCT7_SRA          7'h20

`define FUNCT3_SLT          3'h02
`define FUNCT3_SLTU         3'h03

// I-type
`define FUNCT3_ADDI         3'h0
`define FUNCT3_XORI         3'h4
`define FUNCT3_ORI          3'h6
`define FUNCT3_ANDI         3'h7
`define FUNCT3_SLLI         3'h1

`define FUNCT3_SRLISRAI     3'h5
`define FUNCT7_SRLI         7'h0
`define FUNCT7_SRAI         7'h20

`define FUNCT3_SLTI         3'h2
`define FUNCT3_SLTIU        3'h3

/***** BRANCH TAKER *****/
`define BR_TAKEN        1'b1
`define BR_NOTTAKEN     1'b0

// Control doesn't need below for parsing, only used by branch taker
`define FUNCT3_BEQ      3'h0
`define FUNCT3_BNE      3'h1
`define FUNCT3_BLT      3'h4
`define FUNCT3_BGE      3'h5
`define FUNCT3_BLTU     3'h6
`define FUNCT3_BGEU     3'h7

/***** ALU STUFF *****/
`define ALU_A_RS1       1'b0
`define ALU_A_PC        1'b1
`define ALU_A_DONTCARE  1'b0
`define ALU_B_RS2       1'b0
`define ALU_B_IMM       1'b1
`define ALU_B_DONTCARE  1'b0

`define ALU_ADD         4'b0000
`define ALU_SUB         4'b0001
`define ALU_AND         4'b0010
`define ALU_OR          4'b0011
`define ALU_XOR         4'b0100
`define ALU_SLL         4'b0101
`define ALU_SRL         4'b0110
`define ALU_SRA         4'b0111
`define ALU_SLT         4'b1000
`define ALU_SLTU        4'b1001
`define ALU_COPY_B      4'b1010
`define ALU_DONTCARE    4'b0000

/***** DMEMORY *****/
`define DMEM_WRITE      1'b1
`define DMEM_NOWRITE    1'b0

// check addr[1]
// lower half addrs: h'0, h'4, h'8, h'c (00, 100, 1000, 1100) => addr[1] = 0
`define DMEM_ADDR_HALF_LOWER    1'b0
// lower half addrs: h'2, h'6, h'b, h'f (10, 110, 1011, 1111) => addr[1] = 1
`define DMEM_ADDR_HALF_UPPER    1'b1

// macros from first (lowest) to fourth (highest) byte
// 2b'00, 2'b01, 2'b10, 2'b11
`define DMEM_ADDR_BYTE_FIRST    2'b00
`define DMEM_ADDR_BYTE_SECOND   2'b01
`define DMEM_ADDR_BYTE_THIRD    2'b10
`define DMEM_ADDR_BYTE_FOURTH   2'b11

// funct3 code is equal to its corr. access size! for ease
`define DMEM_SIZE_WORD      2'b10
`define DMEM_SIZE_HALF      2'b01
`define DMEM_SIZE_BYTE      2'b00
`define DMEM_SIZE_DONTCARE  2'b00

`define FUNCT3_SW       3'h2
`define FUNCT3_SH       3'h1
`define FUNCT3_SB       3'h0

`define FUNCT3_LW       3'h2
`define FUNCT3_LH       3'h1
`define FUNCT3_LB       3'h0
`define FUNCT3_LHU      3'h5
`define FUNCT3_LBU      3'h4

/***** WRITEBACK *****/
`define REG_WRITE   1'b1
`define REG_NOWRITE 1'b0

`define WB_ALU      2'b00 // The computed ALU result
`define WB_MEM      2'b01 // From memory
`define WB_PC4      2'b10 // PC+4 (for jumps, save place we jumped from)
`define WB_DONTCARE 2'b00

`define FWD_NONE    2'b00
`define FWD_MX      2'b01
`define FWD_WX      2'b10
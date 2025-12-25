module decoder 
(
    input wire [31:0]   instruction,
    output wire [6:0]   opcode,
    output reg [4:0]   rd,
    output reg [4:0]    rs1,
    output reg [4:0]    rs2,
    output wire [2:0]   funct3,
    output wire [6:0]   funct7,
    output wire [4:0]   shamt,
    output reg [31:0]   imm
);

`include "defines.vh"

// let's decode!
assign opcode   = instruction[6:0];
// assign rd       = instruction[11:7];
assign funct3   = instruction[14:12];
assign funct7   = instruction[31:25];
assign shamt    = instruction[24:20];

always @(*) begin
    // allow combinational assignment to rs1/rs2
    // their decoder may force rs1/rs2 to 0
    // rs1 = instruction[19:15];
    // rs2 = instruction[24:20];
    imm = 32'b0;
    rd  = 5'b0;
    rs1 = 5'b0;
    rs2 = 5'b0;
    case (opcode)
        `OPCODE_R: begin
            // no immediates! don't care
            rd  = instruction[11:7];
            rs1 = instruction[19:15];
            rs2 = instruction[24:20];
            imm = 0;
        end
        `OPCODE_I_IMM,
        `OPCODE_I_LOAD,
        `OPCODE_I_JALR: begin
            rd  = instruction[11:7];
            rs1 = instruction[19:15];
            rs2 = 5'b0;
            if (opcode == `OPCODE_I_IMM && (funct3 == `FUNCT3_SLLI || funct3 == `FUNCT3_SRLISRAI)) begin
                // for slli, srli, srai, imm is the shamt at (24:20)
                imm = {27'b0, instruction[24:20]};
            end else begin
                imm = {{20{instruction[31]}},   // sign-extend b11 (sign bit) 20x in top half
                        instruction[31:20]};
            end
        end
        `OPCODE_S: begin
            // imm[11:5] (31:25)... imm[4:0] (11:7)
            rd  = 5'b0; // Correctly zero out rd
            rs1 = instruction[19:15];
            rs2 = instruction[24:20];
            imm = {{20{instruction[31]}},   // sign-extend b11 20x
                    instruction[31:25],     // b11-5
                    instruction[11:7]};     // b4-0
                                            // 20 + 7 + 5 = 32
        end
        `OPCODE_B: begin
            // imm[12|10:5] (31:25)... imm[4:1|11] (11:7)
            rd  = 5'b0; // Correctly zero out rd
            rs1 = instruction[19:15];
            rs2 = instruction[24:20];
            imm = {{20{instruction[31]}},   // sign-extend b12 20x
                    instruction[7],         // b11
                    instruction[30:25],     // b10-5
                    instruction[11:8],      // b4-1
                    1'b0};                  // pad 0 to make 4 bytes
                                            // 20 + 1 + 6 + 4 + 1 = 32
        end
        `OPCODE_U_LUI: begin
             // unsigned, don't extend!
            // imm[31:12] (31:12)
            rd  = instruction[11:7];
            rs1 = 5'b0; // Correctly zero out rs1
            rs2 = 5'b0; // Correctly zero out rs2

            imm = {instruction[31:12],      // b31-12
                    12'b0};                 // pad lower half with 0s to make 4 bytes
                                            // 20 + 12 = 32
        end
        `OPCODE_U_AUIPC: begin
            // unsigned, don't extend!
            // imm[31:12] (31:12)
            rd  = instruction[11:7];
            rs1 = 5'b0; // Correctly zero out rs1
            rs2 = 5'b0; // Correctly zero out rs2
            imm = {instruction[31:12],      // b31-12
                    12'b0};                 // pad lower half with 0s to make 4 bytes
                                            // 20 + 12 = 32
        end
        `OPCODE_J: begin
            /**
            "The JAL and JALR instructions will generate an instruction-address-misaligned
            exception if the target address is not aligned to a four-byte boundary.""
            */
            // imm[20|10:1|11|19:12] (31:12)
            rd  = instruction[11:7];
            rs1 = 5'b0; // Correctly zero out rs1
            rs2 = 5'b0; // Correctly zero out rs2
            imm = {{12{instruction[31]}},   // sign-extend b20 12x in top half
                    instruction[19:12],
                    instruction[20],        // b11
                    instruction[30:21],     // b10-1
                    1'b0};                  // pad 0 to make 4-bytes
                                            // 12 + 8 + 1 + 10 + 1 = 32
        end
        default: begin
            // don't care about any other kind of opcode
            rd  = 5'b0;
            rs1 = 5'b0;
            rs2 = 5'b0;
            imm = 0;
        end
    endcase
end

endmodule
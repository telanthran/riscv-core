module alu 
(
    input wire [31:0]   src_A,
    input wire [31:0]   src_B,
    input wire [3:0]    ALUSel,
    output reg  [31:0]  result
);

always @(*) begin
    result = 32'b0;

    case (ALUSel)
        `ALU_ADD: result = src_A + src_B;
        `ALU_SUB: result = src_A - src_B;
        `ALU_AND: result = src_A & src_B;
        `ALU_OR:  result = src_A | src_B;
        `ALU_XOR: result = src_A ^ src_B;

        // shifts: rd = rs1 _ imm[0:4]
        `ALU_SLL: result = src_A << src_B[4:0];
        `ALU_SRL: result = src_A >> src_B[4:0];
        `ALU_SRA: result = $signed(src_A) >>> src_B[4:0];
        `ALU_SLT: result = ($signed(src_A) < $signed(src_B)) ? 32'd1 : 32'd0;
        `ALU_SLTU: result = (src_A < src_B) ? 32'd1 : 32'd0;

        // LUI is a straight copy as we already positioned in decoder
        `ALU_COPY_B: result = src_B;

        default: result = 32'b0;
    endcase
end

endmodule
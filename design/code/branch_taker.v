module branch_taker
(
    input wire [6:0]    opcode,
    input wire [2:0]    funct3,
    input wire [31:0]   data_rs1,
    input wire [31:0]   data_rs2,
    output reg          br_taken
);

`include "defines.vh"

wire is_equal = (data_rs1 == data_rs2);
wire is_less_than = ($signed(data_rs1) < $signed(data_rs2));
wire is_less_than_u = (data_rs1 < data_rs2);

always @(*) begin
    br_taken = `BR_NOTTAKEN; // PLZ STOP COMPLAINING ABT LATCH
    if (opcode == `OPCODE_B) begin
        case (funct3)
            `FUNCT3_BEQ: br_taken = (is_equal) ? `BR_TAKEN : `BR_NOTTAKEN;
            `FUNCT3_BNE: br_taken = (!is_equal) ? `BR_TAKEN : `BR_NOTTAKEN;
            `FUNCT3_BLT: br_taken = (is_less_than) ? `BR_TAKEN : `BR_NOTTAKEN;
            `FUNCT3_BGE: br_taken = (!is_less_than) ? `BR_TAKEN : `BR_NOTTAKEN;
            `FUNCT3_BLTU: br_taken = (is_less_than_u) ? `BR_TAKEN : `BR_NOTTAKEN;
            `FUNCT3_BGEU: br_taken = (!is_less_than_u) ? `BR_TAKEN : `BR_NOTTAKEN;
            default: br_taken = `BR_NOTTAKEN;
        endcase
    end
end

endmodule
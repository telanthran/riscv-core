module register_file #()
(
    input wire clock,
    input wire [4:0]    addr_rs1,       // input to select the first source register
    input wire [4:0]    addr_rs2,       // input to select the second source register
    input wire [4:0]    addr_rd,        // input to select the destination register
    input wire [31:0]   data_rd,        // input to write into the destination register
    input wire          write_enable,   // input to write the contents of destination register specified by addr_rd
                                        // If write_enable is not asserted, then the register file does not do any writes.
                                        // Read to 0, Write = 1

    output wire [31:0]  data_rs1,       // output of the contents of register specified by addr_rs1
    output wire [31:0]  data_rs2        // output of the contents of register specified by addr_rs2
);

reg [31:0] registers [0:31];

// set all registers to 0 except x2 (sp)
initial begin
    integer i;
    for (i = 0; i < 32; i = i + 1) begin
        registers[i] = 0;
    end

    registers[2] = 32'h01000000 + `MEM_DEPTH;
end

// reads in the register file are combinational
assign data_rs1 = registers[addr_rs1];
assign data_rs2 = registers[addr_rs2];

// writes in the register file are sequential
// trying to write to x0 does nothing, x0 keeps default value of 0
always @(posedge clock) begin
    if (write_enable && addr_rd != 0) begin
        registers[addr_rd] <= data_rd;
    end
end

endmodule

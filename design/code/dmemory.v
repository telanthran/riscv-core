module dmemory #(
    parameter DEPTH = `MEM_DEPTH,
    parameter BASE_ADDRESS = 32'h01000000
)
(
    input wire          clock,
    input wire [31:0]   address,
    input wire [31:0]   data_in,
    input wire          read_write,  // 0 = read, 1 = write
    input wire [1:0]    access_size,
    output reg [31:0]   data_out
);

reg [7:0] mem_array [0:DEPTH-1];
reg [31:0] temp_mem_array [0:(DEPTH/4)-1];

initial begin
    $readmemh(`MEM_PATH, temp_mem_array);

    for (integer i = 0; i < DEPTH/4; i = i+1) begin
        mem_array[i*4]   = temp_mem_array[i][7:0];
        mem_array[i*4+1] = temp_mem_array[i][15:8];
        mem_array[i*4+2] = temp_mem_array[i][23:16];
        mem_array[i*4+3] = temp_mem_array[i][31:24];
    end
end

// MEM_DEPTH specifies depth in bytes
wire [31:0] eff_address = address - BASE_ADDRESS;
// word-aligned base address for all memory access
wire [31:0] aligned_eff_address = {eff_address[31:2], 2'b00};

always @(*) begin
    if (aligned_eff_address < DEPTH - 3) begin
        data_out[7:0]   = mem_array[aligned_eff_address];
        data_out[15:8]  = mem_array[aligned_eff_address+1];
        data_out[23:16] = mem_array[aligned_eff_address+2];
        data_out[31:24] = mem_array[aligned_eff_address+3];
    end else begin
        data_out = 32'h8BADF00D;
    end
end

always @(posedge clock) begin
    if (eff_address < DEPTH - 3) begin
        if (read_write) begin
            case (access_size)
                `DMEM_SIZE_WORD: begin
                    mem_array[aligned_eff_address]   <= data_in[7:0];
                    mem_array[aligned_eff_address+1] <= data_in[15:8];
                    mem_array[aligned_eff_address+2] <= data_in[23:16];
                    mem_array[aligned_eff_address+3] <= data_in[31:24];
                end
                `DMEM_SIZE_HALF: begin
                    if (eff_address[1] == `DMEM_ADDR_HALF_LOWER) begin
                        mem_array[aligned_eff_address]   <= data_in[7:0];
                        mem_array[aligned_eff_address+1] <= data_in[15:8];
                    end else begin
                        mem_array[aligned_eff_address+2] <= data_in[7:0];
                        mem_array[aligned_eff_address+3] <= data_in[15:8];
                    end
                end
                `DMEM_SIZE_BYTE: begin
                    case (eff_address[1:0])
                        `DMEM_ADDR_BYTE_FIRST:  mem_array[aligned_eff_address]   <= data_in[7:0];
                        `DMEM_ADDR_BYTE_SECOND: mem_array[aligned_eff_address+1] <= data_in[7:0];
                        `DMEM_ADDR_BYTE_THIRD:  mem_array[aligned_eff_address+2] <= data_in[7:0];
                        `DMEM_ADDR_BYTE_FOURTH: mem_array[aligned_eff_address+3] <= data_in[7:0];
                    endcase
                end
                default: begin
                    // Do nothing
                end
            endcase
        end
    end
end

endmodule
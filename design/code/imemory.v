module imemory #(
    parameter DEPTH = `MEM_DEPTH,
    parameter BASE_ADDRESS = 32'h01000000
) 
(
    input wire clock,               // 1
    input wire [31:0]   address,    // 32
    input wire [31:0]   data_in,    // 32 / bytes to be written to address
    input wire          read_write, // 1  / 0 = read, 1 = write
    output reg [31:0]   data_out    // 32 / bytes retrieved from address
);

// Due to the new test_rf_init test, we can't rely on LINE_COUNT anymore!
localparam NUM_WORDS  = DEPTH / 4;
localparam ADDR_WIDTH = $clog2(NUM_WORDS);

reg [31:0] mem_array [0:NUM_WORDS-1];
initial begin
    $readmemh(`MEM_PATH, mem_array);
end

wire [31:0] eff_address = address - BASE_ADDRESS;
wire [ADDR_WIDTH-1:0] word_address = eff_address[ADDR_WIDTH+1:2];
wire [1:0] byte_offset = eff_address[1:0];

// For unaligned reads we may need 2 words
wire [31:0] word0 = mem_array[word_address];
wire [31:0] word1 = ({14'b0, word_address} < NUM_WORDS - 1) ? mem_array[word_address + 1] : 32'h0;

// Word-based memory behaves like a byte-addressable one
always @(*) begin
    if (eff_address < DEPTH - 3) begin
        case (byte_offset)
            2'b00: data_out = word0;                         // aligned, read full word
            2'b01: data_out = {word1[7:0], word0[31:8]};     // unaligned by 1 byte, get 3 from word0, 1 from word1
            2'b10: data_out = {word1[15:0], word0[31:16]};   // unaligned by 2 bytes, get 2 from word0, 2 from word1
            2'b11: data_out = {word1[23:0], word0[31:24]};   // unaligned by 3 bytes, get 1 from word0, 3 from word1
            default: data_out = 32'h4BADF00D;
        endcase
    end else begin
        data_out = 32'h4BADF00D;
    end
end

always @(posedge clock) begin
    if (read_write && (eff_address < DEPTH)) begin
        mem_array[word_address] <= data_in;
    end
end

endmodule
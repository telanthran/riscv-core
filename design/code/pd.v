module pd(
  input clock,
  input reset
);

`include "defines.vh"

//******************************//
//       FETCH STAGE ONLY       //
//******************************//
reg [31:0] pc;
wire [31:0] pc_add_four = pc + 4;
wire [31:0] F_instruction;

//******************************//
// PIPELINE REGS BETWEEN IF/ID  //
//******************************//
reg [31:0] FD_pc;
reg [31:0] FD_pc_add_four;
reg [31:0] FD_instruction;
wire is_ecall = (MW_instruction == 32'h00000073);

always @(posedge clock) begin
    if (reset) begin
        pc <= 32'h01000000;
    end else begin
        if (is_ecall) begin
            // Preserve PC and keep infinite loop for debugging
            // $finish;
            pc <= pc;
        end else if ((D_is_jump && !pipeline_stall) || X_br_taken) begin
            // Jumps resolve in Decode stage (but only when not stalled)
            // Branches resolve in Execute stage (must happen even during stalls to prevent wrong path)
            if (D_is_jump) begin
                pc <= D_jump_target;
            end else begin
                // Branch taken - use ALU result from Execute stage
                pc <= X_alu_result;
            end
        end else if (!pipeline_stall) begin
            // Normal PC increment (only when not stalling)
            pc <= pc + 4;
        end
        // Else: stall with no branch - PC stays the same
    end
end

imemory # (
    .DEPTH(`MEM_DEPTH),
    .BASE_ADDRESS(32'h01000000)
) imemory_ins (
    .clock(clock),
    .address(pc),
    .data_in(0),
    .read_write(0),
    .data_out(F_instruction)
);


//******************************//
//       DECODE STAGE ONLY      //
//******************************//
//******************************//
//          HAZARD UNIT         //
//******************************//
// Detects data hazards and generates stall signals
// Three types of hazards handled:
// 1. Load-use hazard: Load in Execute writing to register needed by Decode
// 2. JALR hazard: JALR in Decode needs rs1 from instruction in Execute
// 3. WD structural hazard: Writeback writing to register being read by Decode
// Other RAW hazards are resolved by forwarding (no stall needed)
//******************************//

// Helper signals to identify instruction types
wire is_load_in_EX = (DX_WBSel == `WB_MEM);
wire is_load_in_MEM = (XM_WBSel == `WB_MEM);
wire is_store_in_DECODE = (D_opcode == `OPCODE_S);
wire is_load_in_DECODE = (D_opcode == `OPCODE_I_LOAD);
wire is_jalr_in_DECODE = (D_opcode == `OPCODE_I_JALR);

// 1. Load-use hazard: Load in Execute writing to register needed by Decode
//    - Stall because load data not available until Memory stage (can't forward from Execute)
//    - Applies to: loads writing to rs1 (any instruction) or rs2 (stores only)
//    - Branches use forwarding paths so they don't stall
wire rs1_hazard_EX = (DX_rd_addr == D_rs1_addr) && (D_rs1_addr != 5'b0);
wire rs2_hazard_EX = (DX_rd_addr == D_rs2_addr) && (D_rs2_addr != 5'b0) && is_store_in_DECODE;
wire load_use_hazard = is_load_in_EX && DX_RegWEn && (rs1_hazard_EX || rs2_hazard_EX);

// 2. JALR hazard: JALR in Decode needs rs1 from ANY instruction in Execute
//    - Stall because JALR needs rs1 immediately to calculate jump target in Decode
//    - Result not available until Execute completes (moves to Memory stage)
//    - Then can forward from Memory stage to Decode via MX forwarding
wire jalr_hazard = (DX_rd_addr == D_rs1_addr) && (D_rs1_addr != 5'b0) && is_jalr_in_DECODE && DX_RegWEn;

// 3. WD structural hazard: Writeback writing to register being read by Decode
//    - Register file has combinational reads but sequential writes
//    - Without stall, Decode would read old value while Writeback writes new value
//    - Stall one cycle to let write complete before reading
wire wd_rs1_hazard = (MW_rd_addr == D_rs1_addr) && (MW_rd_addr != 5'b0);
wire wd_rs2_hazard = (MW_rd_addr == D_rs2_addr) && (MW_rd_addr != 5'b0);
wire wd_structural_hazard = MW_RegWEn && (wd_rs1_hazard || wd_rs2_hazard);

// Pipeline stall signal: Stall when any hazard detected
wire pipeline_stall = load_use_hazard || jalr_hazard || wd_structural_hazard;

// Flush when jump detected in Decode (and not stalled) or branch taken in Execute
// This prevents wrong instructions from executing after control flow changes
wire flush_D_stage = ((D_is_jump && !pipeline_stall) || X_br_taken);

wire [6:0]   D_opcode;
wire [4:0]   D_rd_addr;
wire [4:0]   D_rs1_addr;
wire [4:0]   D_rs2_addr;
wire [2:0]   D_funct3;
wire [6:0]   D_funct7;
wire [31:0]  D_imm;
wire [4:0]   D_shamt;

wire [3:0]  D_ALUSel;
wire        D_alu_src_A_raw;
wire        D_alu_src_B_raw;

wire        D_RegWEn;
wire [31:0] D_rs1_data;
wire [31:0] D_rs2_data;

wire        D_MemRW;
wire [1:0]  D_access_size;

wire [1:0]  D_WBSel;
wire D_is_jump = (D_opcode == `OPCODE_J) || (D_opcode == `OPCODE_I_JALR);

//******************************//
//   DECODE STAGE JUMP LOGIC    //
//******************************//
// JALR forwarding: Only MX forwarding needed in Decode stage
// - MX (Memory to Decode): Forward from Memory stage when instruction there is writing to JALR's rs1
// - WX (Writeback to Decode): Handled by WD structural hazard detection + stall (not forwarding)
// - EX (Execute to Decode): Handled by JALR stall logic - stalls until Execute completes
wire ForwardD_MX;
assign ForwardD_MX = XM_RegWEn && (XM_rd_addr != 5'b0) && (XM_rd_addr == D_rs1_addr);

// Select forwarded rs1 value for JALR
// Note: MX_forward_data is defined later with Execute forwarding logic (shared logic)
wire [31:0] D_rs1_forwarded;
assign D_rs1_forwarded = ForwardD_MX ? MX_forward_data : D_rs1_data;

// Calculate jump target in Decode stage
wire [31:0] D_jump_target_raw;
assign D_jump_target_raw =
    (D_opcode == `OPCODE_J) ? (FD_pc + D_imm) :           // JAL: PC + imm
    (D_opcode == `OPCODE_I_JALR) ? (D_rs1_forwarded + D_imm) :  // JALR: rs1 + imm
    32'h0;

// JALR requires clearing LSB of target address
wire [31:0] D_jump_target;
assign D_jump_target =
    (D_opcode == `OPCODE_I_JALR) ? (D_jump_target_raw & 32'hFFFFFFFE) :
    D_jump_target_raw;

decoder decoder_ins (
    .instruction(FD_instruction),
    .opcode(D_opcode),
    .rd(D_rd_addr),
    .rs1(D_rs1_addr),
    .rs2(D_rs2_addr),
    .funct3(D_funct3),
    .funct7(D_funct7),
    .shamt(D_shamt),
    .imm(D_imm)
);

control control_ins (
    .reset(reset),
    .opcode(D_opcode),
    .funct3(D_funct3),
    .funct7(D_funct7),
    .alu_src_A(D_alu_src_A_raw),
    .alu_src_B(D_alu_src_B_raw),
    .ALUSel(D_ALUSel),
    .MemRW(D_MemRW),
    .access_size(D_access_size),
    .RegWEn(D_RegWEn),
    .WBSel(D_WBSel)
);

register_file register_file_is (
    .clock(clock),
    .addr_rs1(D_rs1_addr),
    .addr_rs2(D_rs2_addr),
    .addr_rd(MW_rd_addr),       // writeback
    .data_rd(MW_wb_data),       // writeback
    .write_enable(MW_RegWEn),   // writeback
    .data_rs1(D_rs1_data),
    .data_rs2(D_rs2_data)
);

//******************************//
// PIPELINE REGS BETWEEN ID/EX  //
//******************************//
reg [31:0] DX_pc;
reg [31:0] DX_pc_add_four;
reg [31:0] DX_instruction;

reg [4:0]   DX_rd_addr;
reg [4:0]   DX_rs1_addr;
reg [4:0]   DX_rs2_addr;

reg [6:0]   DX_opcode;
reg [2:0]   DX_funct3;
reg [6:0]   DX_funct7;
reg [4:0]   DX_shamt;
reg [31:0]  DX_imm;

reg [3:0]  DX_ALUSel;
reg        DX_alu_src_A_raw;
reg        DX_alu_src_B_raw;

reg        DX_RegWEn;
reg [31:0] DX_rs1_data;
reg [31:0] DX_rs2_data;

reg        DX_MemRW;
reg [1:0]  DX_access_size;

reg [1:0]  DX_WBSel;

//******************************//
//       EXECUTE STAGE ONLY     //
//******************************//
//******************************//
//       FORWARDING UNIT        //
//******************************//
// Execute stage forwarding: Handles MX and WX forwarding for rs1 and rs2
// - MX (Memory to Execute): Forward from Memory stage (higher priority)
// - WX (Writeback to Execute): Forward from Writeback stage (lower priority)
// - Forwarding is used for both ALU operations and branch comparisons
//******************************//

reg [1:0] ForwardA;  // Forwarding control for rs1
reg [1:0] ForwardB;  // Forwarding control for rs2

always @(*) begin
    ForwardA = `FWD_NONE;
    ForwardB = `FWD_NONE;

    // Check WX forwarding first (lower priority)
    // Writeback stage is writing to a register needed by Execute stage
    if (MW_RegWEn && (MW_rd_addr != 5'b0)) begin
        if (MW_rd_addr == DX_rs1_addr) begin
            ForwardA = `FWD_WX;
        end
        if (MW_rd_addr == DX_rs2_addr) begin
            ForwardB = `FWD_WX;
        end
    end

    // Check MX forwarding second (higher priority, overwrites WX)
    // Memory stage is writing to a register needed by Execute stage
    if (XM_RegWEn && (XM_rd_addr != 5'b0)) begin
        if (XM_rd_addr == DX_rs1_addr) begin
            ForwardA = `FWD_MX;
        end
        if (XM_rd_addr == DX_rs2_addr) begin
            ForwardB = `FWD_MX;
        end
    end
end

// MX forwarding data selector (shared by both Execute stage and Decode stage JALR forwarding)
// - For loads: forward the loaded data from memory (M_dmem_result)
// - For others: forward the ALU result from Memory stage (XM_alu_result)
wire [31:0] MX_forward_data = is_load_in_MEM ? M_dmem_result : XM_alu_result;

wire [31:0] alu_input_A;
wire [31:0] alu_input_B;
assign alu_input_A = (ForwardA == `FWD_NONE) ? DX_rs1_data :       // Use data from regfile
                     (ForwardA == `FWD_MX) ? MX_forward_data :     // MX: forward correct data (mem or ALU)
                                            MW_wb_data;            // WX: forward final data from WB stage

assign alu_input_B = (ForwardB == `FWD_NONE) ? DX_rs2_data :
                     (ForwardB == `FWD_MX) ? MX_forward_data :
                                           MW_wb_data;

wire [31:0] X_alu_src_A = (DX_alu_src_A_raw == `ALU_A_RS1) ? alu_input_A : DX_pc;
wire [31:0] X_alu_src_B = (DX_alu_src_B_raw == `ALU_B_RS2) ? alu_input_B : DX_imm;
wire [3:0]  X_ALUSel = DX_ALUSel;
wire [31:0] X_alu_result;

alu alu_ins (
  .src_A(X_alu_src_A),
  .src_B(X_alu_src_B),
  .ALUSel(X_ALUSel),
  .result(X_alu_result)
);

wire X_br_taken;
branch_taker branch_taker_ins (
  .opcode(DX_opcode),
  .funct3(DX_funct3),
  .data_rs1(alu_input_A),
  .data_rs2(alu_input_B),
  .br_taken(X_br_taken)
);

//******************************//
// PIPELINE REGS BETWEEN EX/MEM //
//******************************//
reg [31:0] XM_pc;
reg [31:0] XM_pc_add_four;
reg [6:0]  XM_opcode;
reg [31:0] XM_instruction;

reg [31:0] XM_alu_result;
reg [4:0]  XM_rs2_addr;
reg [31:0] XM_rs2_data;

reg        XM_RegWEn;
reg [1:0]  XM_WBSel;
reg [4:0]  XM_rd_addr;
reg [2:0]  XM_funct3;

reg        XM_MemRW;
reg [1:0]  XM_access_size;

reg        XM_br_taken;

//******************************//
//       MEMORY STAGE ONLY      //
//******************************//
//******************************//
//       FORWARDING UNIT        //
//******************************//
// Memory stage forwarding: Handles WM forwarding for stores
// - WM (Writeback to Memory): Forward writeback data to store's rs2
// - Store-to-load forwarding: Forward store data to load when addresses match
//******************************//

// WM forwarding for store data: Forward from Writeback to Memory stage store's rs2
wire ForwardM_WM = MW_RegWEn && (MW_rd_addr != 5'b0) && (MW_rd_addr == XM_rs2_addr);
wire [31:0] M_dmem_data_in = ForwardM_WM ? MW_wb_data : XM_rs2_data;

// Store-to-load forwarding: When a load in Memory reads from same address as completing store
// Forward the store's data directly to avoid reading stale data from memory
wire is_store_completing = (MW_instruction[6:0] == `OPCODE_S);
wire is_load_in_MEM_stage = (XM_instruction[6:0] == `OPCODE_I_LOAD);
wire store_load_addr_match = (MW_alu_result == XM_alu_result);
wire store_to_load_forward = is_store_completing && is_load_in_MEM_stage && store_load_addr_match;

wire        M_MemRW = XM_MemRW;
wire [31:0] M_dmem_result_raw;

dmemory # (
  .DEPTH(`MEM_DEPTH),
  .BASE_ADDRESS(32'h01000000)
) dmemory_ins (
  .clock(clock),
  .address(XM_alu_result),
  .data_in(M_dmem_data_in),
  .read_write(XM_MemRW),
  .access_size(XM_access_size),
  .data_out(M_dmem_result_raw)
);

// Store-to-load forwarding mux: use store's data if addresses match, otherwise use memory
wire [31:0] M_dmem_result = store_to_load_forward ? MW_store_data : M_dmem_result_raw;

//******************************//
// PIPELINE REGS BETWEEN MEM/WB //
//******************************//
reg [31:0] MW_pc;
reg [31:0] MW_pc_add_four;
reg [31:0] MW_instruction;

reg [31:0] MW_alu_result;
reg [31:0] MW_dmem_result;
reg [31:0] MW_store_data;  // Store data for WM forwarding

reg        MW_RegWEn;
reg [1:0]  MW_WBSel;
reg [4:0]  MW_rd_addr;
reg [2:0]  MW_funct3;
reg [31:0] MW_wb_data;


always @(*) begin
    MW_wb_data = MW_alu_result;
    case (MW_WBSel)
        `WB_ALU: MW_wb_data = MW_alu_result;
        `WB_PC4: MW_wb_data = MW_pc_add_four;
        `WB_MEM: begin
            case (MW_funct3)
                `FUNCT3_LW: MW_wb_data = MW_dmem_result;
                `FUNCT3_LH: begin
                    if (MW_alu_result[1] == 1'b0) // lower half
                        MW_wb_data = {{16{MW_dmem_result[15]}}, MW_dmem_result[15:0]};
                    else // upper half
                        MW_wb_data = {{16{MW_dmem_result[31]}}, MW_dmem_result[31:16]};
                end
                `FUNCT3_LB: begin
                    case (MW_alu_result[1:0])
                        2'b00: MW_wb_data = {{24{MW_dmem_result[7]}}, MW_dmem_result[7:0]};
                        2'b01: MW_wb_data = {{24{MW_dmem_result[15]}}, MW_dmem_result[15:8]};
                        2'b10: MW_wb_data = {{24{MW_dmem_result[23]}}, MW_dmem_result[23:16]};
                        2'b11: MW_wb_data = {{24{MW_dmem_result[31]}}, MW_dmem_result[31:24]};
                    endcase
                end
                `FUNCT3_LHU: begin
                    if (MW_alu_result[1] == 1'b0)
                        MW_wb_data = {16'b0, MW_dmem_result[15:0]};
                    else
                        MW_wb_data = {16'b0, MW_dmem_result[31:16]};
                end
                `FUNCT3_LBU: begin
                    case (MW_alu_result[1:0])
                        2'b00: MW_wb_data = {24'b0, MW_dmem_result[7:0]};
                        2'b01: MW_wb_data = {24'b0, MW_dmem_result[15:8]};
                        2'b10: MW_wb_data = {24'b0, MW_dmem_result[23:16]};
                        2'b11: MW_wb_data = {24'b0, MW_dmem_result[31:24]};
                    endcase
                end
                default: MW_wb_data = MW_dmem_result;
            endcase
        end
        default: MW_wb_data = MW_alu_result;
    endcase
end

always @(posedge clock) begin
    if (reset) begin
        FD_pc <= 0;
        FD_pc_add_four <= 0;
        FD_instruction <= 0;

        //******************************//

        DX_pc <= 0;
        DX_pc_add_four <= 0;
        DX_instruction <= 0;

        DX_rd_addr <= 0;
        DX_rs1_addr <= 0;
        DX_rs2_addr <= 0;

        DX_opcode <= 0;
        DX_funct3 <= 0;
        DX_funct7 <= 0;
        DX_shamt  <= 0;
        DX_imm    <= 0;

        DX_ALUSel <= 0;
        DX_alu_src_A_raw <= 0;
        DX_alu_src_B_raw <= 0;

        DX_RegWEn <= 0;
        DX_rs1_data <= 0;
        DX_rs2_data <= 0;

        DX_MemRW <= 0;
        DX_access_size <= 0;

        DX_WBSel <= 0;

        //******************************//

        XM_pc <= 0;
        XM_pc_add_four <= 0;
        XM_opcode <= 0;
        XM_instruction <= 0;

        XM_alu_result <= 0;
        XM_rs2_data <= 0;
        XM_rd_addr <= 0;
        XM_funct3 <= 0;
        XM_br_taken <= 0;
        XM_RegWEn <= 0;
        XM_WBSel <= 0;
        XM_MemRW <= 0;
        XM_access_size <= 0;

        //******************************//
        MW_pc <= 0;
        MW_pc_add_four <= 0;
        MW_instruction <= 0;

        MW_alu_result <= 0;
        MW_dmem_result <= 0;
      
        MW_RegWEn <= 0;
        MW_WBSel <= 0;
        MW_rd_addr <= 0;
        MW_funct3 <= 0;
    end else begin
        XM_pc <= DX_pc;
        XM_pc_add_four <= DX_pc_add_four;
        XM_opcode <= DX_opcode;
        XM_instruction <= DX_instruction;

        XM_alu_result <= X_alu_result;
        XM_rs2_data <= alu_input_B;
        XM_rs2_addr <= DX_rs2_addr;

        XM_RegWEn <= DX_RegWEn;
        XM_WBSel <= DX_WBSel;
        XM_rd_addr <= DX_rd_addr;
        XM_funct3 <= DX_funct3;

        XM_MemRW <= DX_MemRW;
        XM_access_size <= DX_access_size;

        XM_br_taken <= X_br_taken;

        //******************************//

        MW_pc <= XM_pc;
        MW_pc_add_four <= XM_pc_add_four;
        MW_instruction <= XM_instruction;

        MW_alu_result <= XM_alu_result;
        MW_dmem_result <= M_dmem_result;
        MW_store_data <= M_dmem_data_in;  // Save store data for WM forwarding

        MW_RegWEn <= XM_RegWEn;
        MW_WBSel <= XM_WBSel;
        MW_rd_addr <= XM_rd_addr;
        MW_funct3 <= XM_funct3;

      // Update DX registers BEFORE FD registers to avoid capturing
      // the next instruction's decoded values
      if (pipeline_stall || X_br_taken) begin
        // Stall: Insert bubble (NOP) into Execute, keep Decode instruction frozen
        // Branch taken: Insert bubble (NOP) into Execute, squash wrong-path instruction
        // NOP = addi x0, x0, 0 (all zeros with RegWEn=1 writing to x0)
        DX_pc <= 0;
        DX_pc_add_four <= 0;
        DX_instruction <= 0;

        DX_RegWEn <= 1;  // Bubble writes to x0 (harmless since x0 is hardwired to 0)
        DX_MemRW  <= 0;

        DX_rd_addr <= 0;  // Write to x0 (no effect)
        DX_rs1_addr <= 0;
        DX_rs2_addr <= 0;
        DX_rs1_data <= 0;
        DX_rs2_data <= 0;
        DX_imm <= 0;
        DX_opcode <= 0;
        DX_funct3 <= 0;
        DX_funct7 <= 0;
        DX_shamt <= 0;

        DX_WBSel <= `WB_ALU;
        DX_ALUSel <= `ALU_ADD;
        DX_alu_src_A_raw <= `ALU_A_RS1;
        DX_alu_src_B_raw <= `ALU_B_RS2;
      end else begin
        // Else advance...
        DX_pc <= FD_pc;
        DX_pc_add_four <= FD_pc_add_four;
        DX_instruction <= FD_instruction;

        DX_rd_addr <= D_rd_addr;
        DX_rs1_addr <= D_rs1_addr;
        DX_rs2_addr <= D_rs2_addr;

        DX_opcode <= D_opcode;
        DX_funct3 <= D_funct3;
        DX_funct7 <= D_funct7;
        DX_shamt  <= D_shamt;
        DX_imm    <= D_imm;

        DX_ALUSel <= D_ALUSel;
        DX_alu_src_A_raw <= D_alu_src_A_raw;
        DX_alu_src_B_raw <= D_alu_src_B_raw;
        DX_rs1_data <= D_rs1_data;
        DX_rs2_data <= D_rs2_data;
        DX_MemRW <= D_MemRW;
        DX_RegWEn <= D_RegWEn;
        DX_access_size <= D_access_size;
        DX_WBSel <= D_WBSel;
      end

      // Flush should happen even during stalls!
      // When a branch/jump is taken, we must squash the speculatively fetched instruction
      if (flush_D_stage) begin
        // Only flush FD stage - DX was already updated above from the OLD FD
        // The jump/branch instruction in DX will advance to XM naturally
        // Next cycle, DX will get the flushed FD (NOP) automatically
        FD_pc <= 0;
        FD_pc_add_four <= 0;
        FD_instruction <= 0;
      end else if (!pipeline_stall) begin
        FD_pc <= pc;
        FD_pc_add_four <= pc_add_four;
        FD_instruction <= F_instruction;
      end
      // Else: stall without flush - FD keeps its current value
        
    end
end
endmodule

// [D] pc_address opcode rd rs1 rs2 funct3 funct7 imm shamt
// [R] addr_rs1 addr_rs2 data_rs1 data_rs2 
// [E] pc_address alu_result branch_taken
// [M] pc_address memory_address read_write access_size memory_data
// [W] pc_address RegWEn write_rd data_rd

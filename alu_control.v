// =============================================================================
// alu_control.v
// Classic RISC-V single-cycle-datapath ALU control decoder.
// Converts {ALUOp, funct7[5], funct3} into the 4-bit ALUControl signal
// consumed by alu_32bit.v. This mirrors the textbook (Harris & Harris)
// two-stage decode: the main decoder produces a coarse ALUOp, and this
// unit produces the precise ALU operation.
//
// ALUOp (from main/instruction decoder):
//   00 -> ADD          (loads, stores, AUIPC/JAL address calc)
//   01 -> SUB          (branches: compare via subtraction)
//   10 -> R/I-type ALU op, decoded from funct3 + funct7[5]
//   11 -> pass B        (LUI)
// =============================================================================

`timescale 1ns / 1ps

module alu_control (
    input  wire [1:0] ALUOp,
    input  wire [2:0] funct3,
    input  wire       funct7_5,   // bit 30 of the instruction (0=logical/add, 1=arith/sub variant)
    input  wire       is_mul,     // 1 when funct7==0000001 (RV32M) selects mul/div/rem family
    output reg  [3:0] ALUControl
);

    localparam ALU_ADD  = 4'b0000;
    localparam ALU_SUB  = 4'b0001;
    localparam ALU_AND  = 4'b0010;
    localparam ALU_OR   = 4'b0011;
    localparam ALU_XOR  = 4'b0100;
    localparam ALU_SLL  = 4'b0101;
    localparam ALU_SRL  = 4'b0110;
    localparam ALU_SRA  = 4'b0111;
    localparam ALU_SLT  = 4'b1000;
    localparam ALU_SLTU = 4'b1001;
    localparam ALU_NOR  = 4'b1010;
    localparam ALU_MUL  = 4'b1011;
    localparam ALU_DIV  = 4'b1100;
    localparam ALU_REM  = 4'b1101;
    localparam ALU_PASSB= 4'b1110;

    always @(*) begin
        case (ALUOp)
            2'b00: ALUControl = ALU_ADD;   // loads / stores
            2'b01: ALUControl = ALU_SUB;   // branches
            2'b11: ALUControl = ALU_PASSB; // LUI
            2'b10: begin                   // R-type / I-type arithmetic
                if (is_mul) begin
                    case (funct3)
                        3'b000: ALUControl = ALU_MUL;  // mul
                        3'b100: ALUControl = ALU_DIV;  // div
                        3'b110: ALUControl = ALU_REM;  // rem
                        default: ALUControl = ALU_MUL;
                    endcase
                end else begin
                    case (funct3)
                        3'b000: ALUControl = funct7_5 ? ALU_SUB : ALU_ADD; // SUB / ADD(I)
                        3'b001: ALUControl = ALU_SLL;
                        3'b010: ALUControl = ALU_SLT;
                        3'b011: ALUControl = ALU_SLTU;
                        3'b100: ALUControl = ALU_XOR;
                        3'b101: ALUControl = funct7_5 ? ALU_SRA : ALU_SRL; // SRA / SRL(I)
                        3'b110: ALUControl = ALU_OR;
                        3'b111: ALUControl = ALU_AND;
                        default: ALUControl = ALU_ADD;
                    endcase
                end
            end
            default: ALUControl = ALU_ADD;
        endcase
    end

endmodule

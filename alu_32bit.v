// =============================================================================
// alu_32bit.v
// Full-featured 32-bit ALU, RISC-V (RV32I + basic M-extension) style.
//
// ALUControl encoding (4 bits):
//   0000 : ADD               Result = A + B
//   0001 : SUB               Result = A - B
//   0010 : AND               Result = A & B
//   0011 : OR                Result = A | B
//   0100 : XOR               Result = A ^ B
//   0101 : SLL               Result = A << B[4:0]              (logical left)
//   0110 : SRL               Result = A >> B[4:0]              (logical right)
//   0111 : SRA               Result = A >>> B[4:0]             (arithmetic right)
//   1000 : SLT               Result = (signed)A < (signed)B ? 1 : 0
//   1001 : SLTU              Result = (unsigned)A < (unsigned)B ? 1 : 0
//   1010 : NOR               Result = ~(A | B)
//   1011 : MUL               Result = (A * B)[31:0]  (low word of product)
//   1100 : DIV               Result = (signed)A / (signed)B
//   1101 : REM               Result = (signed)A % (signed)B
//   1110 : PASSB             Result = B                        (for LUI etc.)
//   1111 : PASSA             Result = A
//
// Flags:
//   Zero      - Result == 0
//   Negative  - Result[31] (MSB of result, sign bit)
//   CarryOut  - carry/borrow out of bit 31, valid for ADD/SUB only
//   Overflow  - signed overflow, valid for ADD/SUB only
// =============================================================================

`timescale 1ns / 1ps

module alu_32bit (
    input  wire [31:0] A,
    input  wire [31:0] B,
    input  wire [3:0]  ALUControl,

    output reg  [31:0] Result,
    output wire        Zero,
    output wire        Negative,
    output reg         CarryOut,
    output reg         Overflow
);

    // Local params for readability
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
    localparam ALU_PASSA= 4'b1111;

    // Extended add/sub result used to derive carry out cleanly
    wire [32:0] add_ext = {1'b0, A} + {1'b0, B};
    wire [32:0] sub_ext = {1'b0, A} - {1'b0, B};

    wire signed [31:0] A_signed = A;
    wire signed [31:0] B_signed = B;

    always @(*) begin
        // Defaults (only meaningful for ADD/SUB, but keep deterministic)
        CarryOut = 1'b0;
        Overflow = 1'b0;

        case (ALUControl)
            ALU_ADD: begin
                Result   = add_ext[31:0];
                CarryOut = add_ext[32];
                // signed overflow: operands same sign, result different sign
                Overflow = (A[31] == B[31]) && (Result[31] != A[31]);
            end

            ALU_SUB: begin
                Result   = sub_ext[31:0];
                CarryOut = sub_ext[32]; // borrow indicator (1 = borrow occurred)
                // signed overflow: operands different sign, result sign != A sign
                Overflow = (A[31] != B[31]) && (Result[31] != A[31]);
            end

            ALU_AND:  Result = A & B;
            ALU_OR:   Result = A | B;
            ALU_XOR:  Result = A ^ B;
            ALU_SLL:  Result = A << B[4:0];
            ALU_SRL:  Result = A >> B[4:0];
            ALU_SRA:  Result = $signed(A) >>> B[4:0];

            ALU_SLT:  Result = (A_signed < B_signed) ? 32'd1 : 32'd0;
            ALU_SLTU: Result = (A < B) ? 32'd1 : 32'd0;

            ALU_NOR:  Result = ~(A | B);

            ALU_MUL:  Result = A * B; // low 32 bits of product (sign-agnostic)

            ALU_DIV: begin
                // NOTE: intentionally using if/else (not ?:) here. Mixing an
                // unsigned literal with a signed division inside a single
                // conditional expression forces the whole expression to be
                // evaluated as unsigned under Verilog's expression-typing
                // rules, silently corrupting the signed division. if/else
                // avoids that trap.
                if (B == 32'd0)
                    Result = 32'hFFFFFFFF; // RISC-V DIV-by-zero convention
                else
                    Result = A_signed / B_signed;
            end

            ALU_REM: begin
                if (B == 32'd0)
                    Result = A;             // RISC-V REM-by-zero convention
                else
                    Result = A_signed % B_signed;
            end

            ALU_PASSB: Result = B;
            ALU_PASSA: Result = A;

            default:  Result = 32'hXXXXXXXX;
        endcase
    end

    assign Zero     = (Result == 32'b0);
    assign Negative = Result[31];

endmodule

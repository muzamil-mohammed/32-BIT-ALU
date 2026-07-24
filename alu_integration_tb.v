// =============================================================================
// alu_integration_tb.v
// Demonstrates the intended real-world usage: instruction fields feed
// alu_control, which drives alu_32bit -- exactly as in a RISC-V datapath.
// =============================================================================
`timescale 1ns / 1ps

module alu_integration_tb;

    reg  [31:0] A, B;
    reg  [1:0]  ALUOp;
    reg  [2:0]  funct3;
    reg         funct7_5;
    reg         is_mul;
    wire [3:0]  ALUControl;

    wire [31:0] Result;
    wire        Zero, Negative, CarryOut, Overflow;

    integer errors = 0;
    integer tests  = 0;

    alu_control ctrl (
        .ALUOp(ALUOp), .funct3(funct3), .funct7_5(funct7_5), .is_mul(is_mul),
        .ALUControl(ALUControl)
    );

    alu_32bit dut (
        .A(A), .B(B), .ALUControl(ALUControl),
        .Result(Result), .Zero(Zero), .Negative(Negative),
        .CarryOut(CarryOut), .Overflow(Overflow)
    );

    task check;
        input [127:0] name;
        input [31:0] expected;
        begin
            tests = tests + 1;
            if (Result !== expected) begin
                errors = errors + 1;
                $display("FAIL [%0s] ALUOp=%b f3=%b f7_5=%b -> ALUControl=%b Result=%h expected=%h",
                          name, ALUOp, funct3, funct7_5, ALUControl, Result, expected);
            end else begin
                $display("PASS [%0s] ALUControl=%b Result=%h", name, ALUControl, Result);
            end
        end
    endtask

    initial begin
        $display("=== ALU + ALU-Control Integration Testbench ===");

        // lw/sw address calc: opcode class -> ALUOp=00 -> ADD
        A = 32'd100; B = 32'd8; ALUOp = 2'b00; funct3 = 3'bxxx; funct7_5 = 1'bx; is_mul = 0; #1;
        check("Load/Store address ADD", 32'd108);

        // beq: ALUOp=01 -> SUB, branch taken when Zero
        A = 32'd42; B = 32'd42; ALUOp = 2'b01; funct3 = 3'bxxx; funct7_5 = 1'bx; is_mul = 0; #1;
        check("Branch compare SUB", 32'd0);
        if (!Zero) begin errors = errors + 1; $display("FAIL branch zero flag"); end
        tests = tests + 1;

        // R-type ADD: funct3=000, funct7_5=0
        A = 32'd7; B = 32'd3; ALUOp = 2'b10; funct3 = 3'b000; funct7_5 = 1'b0; is_mul = 0; #1;
        check("R-type ADD", 32'd10);

        // R-type SUB: funct3=000, funct7_5=1
        A = 32'd7; B = 32'd3; ALUOp = 2'b10; funct3 = 3'b000; funct7_5 = 1'b1; is_mul = 0; #1;
        check("R-type SUB", 32'd4);

        // R-type AND / OR / XOR
        A = 32'hF0F0F0F0; B = 32'h0FF00FF0; ALUOp = 2'b10; funct3 = 3'b111; funct7_5 = 1'b0; is_mul = 0; #1;
        check("R-type AND", 32'h00F000F0);

        A = 32'hF0F0F0F0; B = 32'h0FF00FF0; ALUOp = 2'b10; funct3 = 3'b110; funct7_5 = 1'b0; is_mul = 0; #1;
        check("R-type OR", 32'hFFF0FFF0);

        A = 32'hF0F0F0F0; B = 32'h0FF00FF0; ALUOp = 2'b10; funct3 = 3'b100; funct7_5 = 1'b0; is_mul = 0; #1;
        check("R-type XOR", 32'hFF00FF00);

        // R-type SLL / SRL / SRA
        A = 32'h1; B = 32'd4; ALUOp = 2'b10; funct3 = 3'b001; funct7_5 = 1'b0; is_mul = 0; #1;
        check("R-type SLL", 32'h10);

        A = 32'h80000000; B = 32'd4; ALUOp = 2'b10; funct3 = 3'b101; funct7_5 = 1'b0; is_mul = 0; #1;
        check("R-type SRL", 32'h08000000);

        A = 32'h80000000; B = 32'd4; ALUOp = 2'b10; funct3 = 3'b101; funct7_5 = 1'b1; is_mul = 0; #1;
        check("R-type SRA", 32'hF8000000);

        // R-type SLT / SLTU
        A = 32'hFFFFFFFF; B = 32'd1; ALUOp = 2'b10; funct3 = 3'b010; funct7_5 = 1'b0; is_mul = 0; #1;
        check("R-type SLT", 32'd1);

        A = 32'hFFFFFFFF; B = 32'd1; ALUOp = 2'b10; funct3 = 3'b011; funct7_5 = 1'b0; is_mul = 0; #1;
        check("R-type SLTU", 32'd0);

        // RV32M: MUL / DIV / REM
        A = 32'd6; B = 32'd7; ALUOp = 2'b10; funct3 = 3'b000; funct7_5 = 1'b0; is_mul = 1; #1;
        check("RV32M MUL", 32'd42);

        A = -32'd20; B = 32'd6; ALUOp = 2'b10; funct3 = 3'b100; funct7_5 = 1'b0; is_mul = 1; #1;
        check("RV32M DIV", -32'd3);

        A = -32'd20; B = 32'd6; ALUOp = 2'b10; funct3 = 3'b110; funct7_5 = 1'b0; is_mul = 1; #1;
        check("RV32M REM", -32'd2);

        // LUI: ALUOp=11 -> pass B straight through
        A = 32'hDEADBEEF; B = 32'h12345000; ALUOp = 2'b11; funct3 = 3'bxxx; funct7_5 = 1'bx; is_mul = 0; #1;
        check("LUI PASSB", 32'h12345000);

        $display("=============================================");
        $display("Tests run: %0d, Failures: %0d", tests, errors);
        if (errors == 0)
            $display(">>> ALL INTEGRATION TESTS PASSED <<<");
        else
            $display(">>> %0d TEST(S) FAILED <<<", errors);
        $display("=============================================");

        $finish;
    end

endmodule

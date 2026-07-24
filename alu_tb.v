// =============================================================================
// alu_tb.v - Self-checking testbench for alu_32bit.v
// =============================================================================
`timescale 1ns / 1ps

module alu_tb;

    reg  [31:0] A, B;
    reg  [3:0]  ALUControl;
    wire [31:0] Result;
    wire        Zero, Negative, CarryOut, Overflow;

    integer errors = 0;
    integer tests  = 0;

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
                $display("FAIL [%0s] A=%h B=%h ALUControl=%b -> Result=%h expected=%h",
                          name, A, B, ALUControl, Result, expected);
            end else begin
                $display("PASS [%0s] Result=%h", name, Result);
            end
        end
    endtask

    task check_flag;
        input [127:0] name;
        input got, expected;
        begin
            tests = tests + 1;
            if (got !== expected) begin
                errors = errors + 1;
                $display("FAIL FLAG [%0s] got=%b expected=%b", name, got, expected);            end
        end
    endtask

    initial begin
	$dumpfile("alu.vcd");
	$dumpvars(0, alu_tb); 
	$display("=== 32-bit ALU Testbench ===");
        // ---- ADD ----
        A = 32'd15; B = 32'd10; ALUControl = 4'b0000; #1;
        check("ADD 15+10", 32'd25);

        A = 32'hFFFFFFFF; B = 32'd1; ALUControl = 4'b0000; #1; // -1 + 1 = 0, carry out
        check("ADD wrap to zero", 32'd0);
        check_flag("ADD carry out", CarryOut, 1'b1);
        check_flag("ADD zero flag", Zero, 1'b1);

        A = 32'h7FFFFFFF; B = 32'd1; ALUControl = 4'b0000; #1; // max positive + 1 -> overflow
        check("ADD signed overflow value", 32'h80000000);
        check_flag("ADD overflow flag", Overflow, 1'b1);

        // ---- SUB ----
        A = 32'd20; B = 32'd7; ALUControl = 4'b0001; #1;
        check("SUB 20-7", 32'd13);

        A = 32'd5; B = 32'd5; ALUControl = 4'b0001; #1;
        check("SUB equal -> zero", 32'd0);
        check_flag("SUB zero flag", Zero, 1'b1);

        A = 32'h80000000; B = 32'd1; ALUControl = 4'b0001; #1; // min negative - 1 -> overflow
        check("SUB signed overflow value", 32'h7FFFFFFF);
        check_flag("SUB overflow flag", Overflow, 1'b1);

        // ---- Bitwise ----
        A = 32'hF0F0F0F0; B = 32'h0FF00FF0; ALUControl = 4'b0010; #1;
        check("AND", 32'h00F000F0);

        A = 32'hF0F0F0F0; B = 32'h0FF00FF0; ALUControl = 4'b0011; #1;
        check("OR", 32'hFFF0FFF0);

        A = 32'hF0F0F0F0; B = 32'h0FF00FF0; ALUControl = 4'b0100; #1;
        check("XOR", 32'hFF00FF00);

        A = 32'hF0F0F0F0; B = 32'h0FF00FF0; ALUControl = 4'b1010; #1;
        check("NOR", ~(32'hF0F0F0F0 | 32'h0FF00FF0));

        // ---- Shifts ----
        A = 32'h00000001; B = 32'd4; ALUControl = 4'b0101; #1;
        check("SLL 1<<4", 32'h00000010);

        A = 32'h80000000; B = 32'd4; ALUControl = 4'b0110; #1;
        check("SRL logical", 32'h08000000);

        A = 32'h80000000; B = 32'd4; ALUControl = 4'b0111; #1;
        check("SRA arithmetic (sign extend)", 32'hF8000000);

        // ---- Comparisons ----
        A = 32'hFFFFFFFF; B = 32'd1; ALUControl = 4'b1000; #1; // -1 < 1 signed -> true
        check("SLT signed (-1 < 1)", 32'd1);

        A = 32'hFFFFFFFF; B = 32'd1; ALUControl = 4'b1001; #1; // huge unsigned < 1 -> false
        check("SLTU unsigned (0xFFFFFFFF < 1)", 32'd0);

        // ---- Mul/Div/Rem ----
        A = 32'd6; B = 32'd7; ALUControl = 4'b1011; #1;
        check("MUL 6*7", 32'd42);

        A = -32'd20; B = 32'd6; ALUControl = 4'b1100; #1; // signed division truncates toward zero
        check("DIV -20/6", -32'd3);

        A = -32'd20; B = 32'd6; ALUControl = 4'b1101; #1;
        check("REM -20%6", -32'd2);

        A = 32'd10; B = 32'd0; ALUControl = 4'b1100; #1; // divide by zero convention
        check("DIV by zero", 32'hFFFFFFFF);

        A = 32'd10; B = 32'd0; ALUControl = 4'b1101; #1; // rem by zero convention
        check("REM by zero", 32'd10);

        // ---- Pass-through ----
        A = 32'hDEADBEEF; B = 32'h12345678; ALUControl = 4'b1110; #1;
        check("PASSB", 32'h12345678);

        A = 32'hDEADBEEF; B = 32'h12345678; ALUControl = 4'b1111; #1;
        check("PASSA", 32'hDEADBEEF);

        // ---- Negative flag ----
        A = 32'd1; B = 32'd2; ALUControl = 4'b0001; #1; // 1 - 2 = -1
        check_flag("Negative flag set", Negative, 1'b1);

        $display("=============================================");
        $display("Tests run: %0d, Failures: %0d", tests, errors);
        if (errors == 0)
            $display(">>> ALL TESTS PASSED <<<");
        else
            $display(">>> %0d TEST(S) FAILED <<<", errors);
        $display("=============================================");

        $finish;
    end

endmodule

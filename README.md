# 32-bit RISC-V-Style ALU (Verilog)

A complete, verified 32-bit ALU in Verilog, styled after the RV32I(+M)
instruction set, with a self-checking testbench and a real instruction-decode
control unit.

## Files

| File | Purpose |
|---|---|
| `alu_32bit.v` | The ALU core. 32-bit `A`, `B` in; 4-bit `ALUControl` selects the op. Outputs `Result`, `Zero`, `Negative`, `CarryOut`, `Overflow`. |
| `alu_control.v` | Decodes `{ALUOp, funct3, funct7[5], is_mul}` (the fields a real RISC-V instruction word supplies) into the 4-bit `ALUControl` signal. |
| `alu_tb.v` | Unit testbench — drives the ALU directly with 28 checks covering every op and edge case (overflow, carry, div-by-zero, negative numbers, etc). |
| `alu_integration_tb.v` | Integration testbench — drives `alu_control` → `alu_32bit` together, the way a real datapath would, across 17 checks. |

## Supported operations (`ALUControl`)

| Code | Op | Result |
|---|---|---|
| `0000` | ADD | `A + B` |
| `0001` | SUB | `A - B` |
| `0010` | AND | `A & B` |
| `0011` | OR | `A \| B` |
| `0100` | XOR | `A ^ B` |
| `0101` | SLL | `A << B[4:0]` |
| `0110` | SRL | `A >> B[4:0]` (logical) |
| `0111` | SRA | `A >>> B[4:0]` (arithmetic, sign-extending) |
| `1000` | SLT | `1` if `A < B` (signed) else `0` |
| `1001` | SLTU | `1` if `A < B` (unsigned) else `0` |
| `1010` | NOR | `~(A \| B)` |
| `1011` | MUL | low 32 bits of `A * B` |
| `1100` | DIV | `A / B` (signed, truncating toward zero) |
| `1101` | REM | `A % B` (signed) |
| `1110` | PASSB | `B` (used for `LUI`) |
| `1111` | PASSA | `A` |

Flags: `Zero` (result is 0), `Negative` (sign bit of result), and
`CarryOut`/`Overflow` (meaningful for `ADD`/`SUB` only — carry/borrow out of
bit 31, and signed two's-complement overflow, respectively).

`DIV`/`REM` follow the RISC-V convention for division by zero: `DIV` returns
all-ones (`-1`), `REM` returns the dividend `A` unchanged.

## How `alu_control` decodes instructions

This mirrors the classic single-cycle RISC-V datapath (as in Harris &
Harris, *Digital Design and Computer Architecture: RISC-V Edition*):

- The main instruction decoder (not included here — it decodes `opcode`)
  produces a coarse 2-bit `ALUOp`:
  - `00` → loads/stores/AUIPC/JAL → force `ADD`
  - `01` → branches → force `SUB` (branch taken/not-taken read off `Zero`)
  - `10` → R-type/I-type ALU instructions → decode precisely from `funct3` +
    bit 30 of the instruction (`funct7_5`)
  - `11` → `LUI` → pass `B` straight through
- `is_mul` stands in for `funct7 == 7'b0000001`, i.e. the RV32M extension
  (`MUL`/`DIV`/`REM`), further selected by `funct3`.

## Running the simulations

Requires [Icarus Verilog](http://iverilog.icarus.com/) (`iverilog`/`vvp`).

```bash
# Unit tests (ALU only)
iverilog -g2012 -o alu_sim alu_32bit.v alu_tb.v
vvp alu_sim

# Integration tests (control decoder + ALU together)
iverilog -g2012 -o alu_int_sim alu_32bit.v alu_control.v alu_integration_tb.v
vvp alu_int_sim
```

Both currently report:
```
Tests run: 28, Failures: 0   (unit)
Tests run: 17, Failures: 0   (integration)
```

## Design notes / gotchas worth knowing

- **Carry/overflow via a 33-bit extended add/sub.** `{1'b0,A} + {1'b0,B}`
  gives a clean carry-out bit without relying on tricky sign-extension
  rules for subtraction.
- **Signed overflow detection** uses the standard rule: for `ADD`, overflow
  occurs when both operands share a sign but the result's sign differs; for
  `SUB`, when the operands have different signs and the result's sign
  differs from `A`'s.
- **Signed division pitfall:** don't write
  `Result = (B==0) ? 32'hFFFFFFFF : (A_signed / B_signed);` — because one
  branch of that ternary is an unsigned literal, Verilog's expression-typing
  rules make the *entire* conditional expression unsigned, silently turning
  the signed division into unsigned division. The fix used here is a plain
  `if/else` instead of `?:`.
- Shift amounts use only `B[4:0]` (5 bits), matching the RISC-V spec for
  32-bit shifts (shift amount is taken mod 32).

## Extending this further

- Add a `funct7 == 0100000` check if you want the M-extension folded into
  `funct7_5` instead of a separate `is_mul` input.
- Wrap `alu_32bit` + `alu_control` + a register file + program counter to
  get a minimal single-cycle RV32I core.
- For FPGA synthesis, note `MUL`/`DIV`/`REM` will infer a hardware
  multiplier/divider (fine on most FPGAs, but divide is usually multi-cycle
  in real hardware — a single-cycle combinational divider here is for
  simulation clarity, not synthesis efficiency).
  
  # Waveform Generation
  
<img width="1188" height="821" alt=" ALU 32-waveform" src="https://github.com/user-attachments/assets/327a76c7-cd59-4fc5-885e-0de906134913" />

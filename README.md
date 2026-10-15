# CS240 Lab 1 – C Programming and RISC-V Toolchain / Compilation

**Program:** `GCD.c` computes the greatest common divisor of two statically defined globals (`a = 54`, `b = 48`) using the Euclidean algorithm (`while (b != 0) { r = a % b; a = b; b = r; }`) and prints the result.

All results are in `ex1/` and `ex2/`.

---

## Exercise 1 – Compiling and inspecting a RISC-V executable

**Step 2 – Compile:** `riscv32-unknown-elf-gcc GCD.c -o GCD`
One command runs the whole pipeline (compile → assemble → link) and produces a RISC-V executable. It cannot run directly on my laptop because the laptop uses a different ISA (x86/ARM).

**Step 3 – `cat GCD`** (`ex1/step3_cat.txt`)
The output is unreadable because the file is binary machine code, not text. `cat` prints every byte as a character and most bytes are not printable. A few readable parts appear, such as `ELF` at the beginning and the printf format string.

**Step 4 – `file GCD`** (`ex1/step4_file.txt`)
`ELF 32-bit LSB executable, UCB RISC-V, soft-float ABI, statically linked, with debug_info, not stripped`
- **ELF:** standard executable format on Linux/Unix.
- **32-bit:** built for RV32 (32-bit registers and addresses).
- **LSB:** little-endian (least significant byte stored first).
- **executable:** fully linked and ready to run.
- **UCB RISC-V:** target ISA is RISC-V.
- **soft-float ABI:** floating point is done in software (no FPU registers).
- **statically linked:** all library code (e.g. `printf`) is copied into the file.
- **not stripped:** symbol names like `main` and `gcd` are kept.

**Step 5 – `readelf -a GCD`** (`ex1/step5_readelf.txt`)
- Magic number `7f 45 4c 46` = `0x7f 'E' 'L' 'F'`, which identifies an ELF file.
- Entry point `0x100f8` is the startup code (`_start`), not `main`. `_start` sets up the stack/global pointer and then calls `main`.
- Important sections:
  - `.text` – machine code (flags AX = loaded, executable). About 70 KB because `printf` and library code are statically linked.
  - `.rodata` – read-only data, e.g. the printf string (at `0x21150`).
  - `.sdata` – small initialized globals; `a` and `b` are here.
  - `.bss/.sbss` – uninitialized globals (NOBITS: no space in the file, zeroed at load).
  - `.debug_*` – debug info, not loaded into memory.
- Code and data are in the same memory at different addresses (stored-program / von Neumann idea).

**Step 6 – `objdump -D GCD`** (`ex1/step6_objdump.txt`)
Each line shows address, machine code in hex, and the assembly instruction. Mapping `gcd` to my C code:
- `addi sp,sp,-48`, `sw ra`, `sw s0` – prologue: create the stack frame and save registers.
- `sw a0` / `sw a1` – arguments `a` and `b` arrive in registers a0/a1 and are saved on the stack.
- `rem a5,a4,a5` – the `%` operator.
- `bnez a5, ...` – the `while (b != 0)` check; branches back to the loop body.
- `mv a0,a5` + `ret` – return value goes in a0.

In `main`, `a` and `b` are loaded with `lw ...(gp)` (global pointer), passed in a0/a1, `jal gcd` calls the function, and `jal printf` prints the result with arguments in a0–a3.
`-D` disassembles all sections, so data sections also appear as meaningless "instructions"; `-d` would show only code.

**Step 7 – `spike --isa=rv32i GCD`** (`ex1/step7_spike.txt`)
Error: `Memory address 0x10000 is invalid`. Without pk, Spike is a bare machine with no OS and its RAM starts at `0x80000000`. The program is linked to load at `0x10000`, where no memory exists. Even if it loaded, nothing would handle `printf`'s system call.

**Step 8 – `spike --isa=rv32i pk GCD`** (`ex1/step8_spike_pk.txt`)
Output: `GCD of 54 and 48 is 6`. pk (proxy kernel) is a minimal OS: it loads the program at the addresses it expects, runs it in user mode, and forwards system calls (like `write` from `printf`) to the host computer, so the text appears in my terminal.

---

## Exercise 2 – Assembly generation and linking step by step

**Step 1 – `riscv32-unknown-elf-gcc -S GCD.c -o GCD.S`** (`ex2/step1_GCD.S`)
`-S` stops after compilation and produces RISC-V assembly text. Compared with objdump:
- Only my code (`gcd`, `main`, `a`, `b`), no library code or `_start`.
- No addresses or machine code; uses labels (`.L2`, `.L3`, `.LC0`) instead.
- Contains assembler directives (`.text`, `.section .sdata`, `.word 54`, `.globl`, `.string`).
- Uses placeholders `%hi()/%lo()` for addresses decided later by the linker, and pseudo-instructions like `call printf`, `jr ra`.
- `.attribute arch, "rv32i2p1_m2p0"` shows the compiler targeted RV32I + M extension, which is why `rem` is used.
- Globals are loaded with `lui + lw` in GCD.S but with a single `lw ...(gp)` in the final executable: the linker shortened it (linker relaxation).

**Step 2 – `riscv32-unknown-elf-as GCD.S -o GCD.o`** (`ex2/step2_file.txt`)
`file` reports `ELF 32-bit LSB relocatable`. The object file contains machine code for my code only, addresses are not final (start at 0), and references to `printf`, `a`, `b`, `.LC0` are left as relocations for the linker. It cannot run yet.

**Step 3 – Linking** (`ex2/step3_*.txt`)
- Plain `riscv32-unknown-elf-ld GCD.o` fails: `undefined reference to printf` and no `_start` entry symbol, because `ld` only links what it is given and GCD.o has no C library or startup code.
- The full `ld` command adds `crt0.o` (`_start`), `crtbegin.o/crtend.o` (init/fini arrays), `-lc` (C library, printf), `-lgloss` (system call glue), `-lgcc` (compiler helpers). This produced `GCD_linked`: `ELF 32-bit LSB executable, statically linked`.
- In `GCD_linked`, `gcd` is at `0x100f8` (in Exercise 1 it was at a different address and `0x100f8` was `_start`). This is because GCD.o was listed first in the ld command, so the linker placed my code first: link order decides placement.

**Step 4 – `spike --isa=rv32i pk GCD_linked`** (`ex2/step4_spike_pk.txt`)
Output: `GCD of 54 and 48 is 6`, same as Exercise 1. Doing compile, assemble and link manually gives the same kind of program as one `gcc` command.

**Step 5 – Debug mode: `spike -d --isa=rv32i pk GCD_linked`** (`ex2/step5_debug.txt`)
Used `until pc 0 100f8` to stop at `gcd`, then `r 1` to run one instruction at a time, `reg 0 <reg>` and `mem 0 <addr>` to inspect state. At entry: a0 = 0x36 (54), a1 = 0x30 (48), sp = 0x7ffffd80.

| PC | Instruction | Effect |
|---|---|---|
| 0x100f8 | `addi sp,sp,-48` | sp: 0x7ffffd80 → 0x7ffffd50 (stack frame created) |
| 0x100fc | `sw ra,44(sp)` | memory[sp+44] = return address |
| 0x10100 | `sw s0,40(sp)` | memory[sp+40] = old s0 |
| 0x10104 | `addi s0,sp,48` | s0 = 0x7ffffd80 (frame pointer) |
| 0x10108 | `sw a0,-36(s0)` | memory[0x7ffffd5c] = 54 (a) |
| 0x1010c | `sw a1,-40(s0)` | memory[0x7ffffd58] = 48 (b) |
| 0x10110 | `j pc+0x24` | PC jumps to 0x10134 (loop condition) |
| 0x10134 | `lw a5,-40(s0)` | a5 = 48 (b) |
| 0x10138 | `bnez a5,pc-36` | b ≠ 0 → PC jumps back to 0x10114 (loop body) |
| 0x10114 | `lw a4,-36(s0)` | a4 = 54 (a) |
| 0x1011c | `rem a5,a4,a5` | illegal instruction trap (see below); result a5 = 6 |
| ... | `sw`/`lw`/`sw` | r stored, then a = b, b = r |

After one iteration memory shows a = 0x30 (48) and b = 0x6 (6), i.e. (54, 48) → (48, 6). The PC normally increases by 4 (each instruction is 4 bytes) except at jumps/branches.

**Observation – `rem` trap:** at `rem`, the PC jumped to `0x80000008`, pk's trap handler, which read `mcause` (illegal instruction). `rem` belongs to the M extension, but Spike was run with `--isa=rv32i` (no M). pk caught the exception, emulated the remainder in software, and returned to my program, so the result was still correct. In machine mode, `mem` on 0x7ffffd5c failed with a load access fault because that is a user virtual address; it worked again after returning to the program.

---

*AI use: I used Claude for concept explanations and debugging help, as allowed by the course policy.*

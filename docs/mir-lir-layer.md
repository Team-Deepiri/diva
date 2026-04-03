# MIR / LIR layer

The MIR layer ([`compiler/mir/src/mir.diri`](../compiler/mir/src/mir.diri)) is the backend boundary between semantic analysis and code generation.

Goals:

- Stable text dump for golden tests (like `emit-ir` today, but Di-owned IR)
- Explicit control flow, calls, locals, and memory operations
- Lowering targets: LLVM (optional), ELF/x86_64 object emission, or assembler text

This replaces ad-hoc LLVM-shaped structures in a future Di-implemented compiler.

# x86_64 ELF64 backend roadmap (no clang)

Primary path for [`docs/no-clang-contract.md`](no-clang-contract.md):

1. **ELF64 ET_REL** object writer: sections `.text`, `.data`, `.rodata`, symbol table, relocations (R_X86_64_*).
2. **SysV x86_64** calling convention in emitted prologues/epilogues.
3. Link with `cc`/`ld` only as **linker** (no `clang` compiler driver for `.ll`).

Fallback lane (still no clang):

- Emit **GNU assembler** syntax to a `.s` file and invoke **`as`** + **`ld`**.

Constants and versioning live in [`compiler/backend/src/elf_x86_64.di`](../compiler/backend/src/elf_x86_64.di).

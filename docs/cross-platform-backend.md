# Cross-platform backend expansion

Order of record (after Linux x86_64 ELF is stable):

1. **Linux aarch64** — ELF64 AArch64 relocations and ABI.
2. **macOS** — Mach-O object format and platform linker conventions (separate track).
3. **Windows PE/COFF** — object format + MSVC or LLD-style linking (separate track).

Shared design:

- Target triple string on the compiler CLI (`di --target` future flag).
- MIR remains OS-neutral; object emission is per-target in `compiler/backend/<arch>/`.

WSL shares the Linux x86_64 backend with the host kernel; only toolchain path differences belong in [`docs/install-and-usage.md`](install-and-usage.md).

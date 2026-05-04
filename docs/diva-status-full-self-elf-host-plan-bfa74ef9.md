---
name: Diva full ELF self-host
overview: "Finish the self-host loop: fix or replace ELF materialization so the driver does not depend on Python for chunks, rebuild a trusted gcc-linked stage2, produce a pure-ELF compiler with that driver, promote it to the pinned bootstrap, then collapse tests to a single seed and run full verification."
todos:
  - id: fix-write-elf-chunk
    content: Debug and re-land write_elf_chunk (runtime_extra + pure id 32 + main.diva + codegen sizes/bounds + host.diva); verify stage2 build/run ret0, print2, vec_demo
    status: completed
  - id: cc-link-stage2
    content: Run build-compiler-cc-link.sh → build/diva-stage2-boot; smoke native build compiler/ with skip env if needed
    status: completed
  - id: pure-build-promote
    content: DRIVER=stage2 build-compiler-pure-elf.sh; promote bootstrap/diva-linux-amd64 per bootstrap/README; tighten verify script skip-env
    status: completed
  - id: collapse-tests
    content: "tests/run.sh: single seed path after goldens green; optional DIVA_TEST_FAST=0 run"
    status: completed
  - id: gen-bytes-script
    content: scripts/gen-pure-host-builtin-bytes.sh for .s → objcopy → paste bytes
    status: completed
isProject: false
---

# Diva full ELF self-host (finish line)

## Current repo state (verified)

- Pure builtins: real `[emit_pure_host_getenv](diri-lang/compiler/src/pure_elf_builtins.diva)` / `[emit_pure_host_system](diri-lang/compiler/src/pure_elf_builtins.diva)`, ids **26/27** with matching sizes in `[pure_builtin_call_size_hi_misc](diri-lang/compiler/src/codegen_x86.diva)`; **unlink/chmod** ids **30/31**; **no** `write_elf_chunk` (id 32 removed).
- `[native_write_exe](diri-lang/compiler/src/main.diva)`: `**unlink` + `chmod_executable` + python `host_system` hex append** (python path restored after regression).
- **Vec / second `print_int`**: fixed in `[emit_pure_builtin_call_5](diri-lang/compiler/src/codegen_x86.diva)` (red-zone buffer, `xor edx` before each `div`, size **64**); matches `[compiler/res/pure_print_int.s](diri-lang/compiler/res/pure_print_int.s)`.
- Bootstrap gap: `[native_require_no_externs](diri-lang/compiler/src/main.diva)` can short-circuit when `**DIVA_SKIP_NATIVE_EXTERN_CHECK`** is set; `[scripts/install.sh](diri-lang/scripts/install.sh)` exports it for the seed `build` step. `[scripts/verify-pure-compiler-build.sh](diri-lang/scripts/verify-pure-compiler-build.sh)` does **not** set it yet—verify may still fail against an old seed if extern lists diverge.
- Tests still use **dual seeds** in `[tests/run.sh](diri-lang/tests/run.sh)` (`INTEGRATION_SEED` vs `EARLY_PIPELINE_SEED`) with comments about `native_write_exe` / vec issues—vec fix should allow collapsing once one driver passes goldens.

## Goal

**One pure-ELF driver** builds `compiler/` without cc/ld, with `**DI_STDLIB_DIR` / `host_getenv` / `host_system`** only where intended, `**native_write_exe`** not requiring Python long-term, and **pinned `bootstrap/diva-linux-amd64`** updated to match that codegen.

## Phase 1 — ELF write path (replace Python)

**Problem (session evidence):** A first attempt at `di_runtime_write_elf_chunk` (malloc + `di_runtime_int_vec_get` loop + open/write) caused **immediate segfault** on trivial `diva build`/`run` when linked into gcc-linked stage2; the implementation was reverted.

**Approach (pick one and prove with minimal tests):**

1. **Reintroduce `write_elf_chunk` (or rename) with a minimal, audited implementation** in `[compiler/res/legacy/runtime_extra.s](diri-lang/compiler/res/legacy/runtime_extra.s)`:
  - Re-add `.extern malloc`, `free`, `di_runtime_int_vec_get` only for this symbol.
  - **Harden indexing:** use **64-bit** index `pos + i` in a single register when calling `di_runtime_int_vec_get` (avoid subtle `r12d`/`esi` overflow or wrong extension); keep buffer fill as `movb %al, (%rbp,%rcx,1)`.
  - **Optional:** add a **temporary** `fprintf(stderr, ...)`-style trace behind `#ifdef` or a tiny `write(2, ...)` probe during bring-up, then remove.
2. **Re-wire Diva side:** restore `extern func write_elf_chunk(...)` in `[stdlib/std/host.diva](diri-lang/stdlib/std/host.diva)`, `[pure_elf_builtins.diva](diri-lang/compiler/src/pure_elf_builtins.diva)` (id **32**, emit blob from `[compiler/res/pure_write_elf_chunk.s](diri-lang/compiler/res/pure_write_elf_chunk.s)`), `[pure_builtin_call_size_hi_misc](diri-lang/compiler/src/codegen_x86.diva)` **221**, `[emit_pure_builtin_call](diri-lang/compiler/src/codegen_x86.diva)` bound `**> 32`**, `[asm_runtime_label](diri-lang/compiler/src/codegen_x86.diva)` → `di_runtime_write_elf_chunk`, `[native_require_no_externs](diri-lang/compiler/src/main.diva)` + `[native_write_exe](diri-lang/compiler/src/main.diva)` loop with `is_first` truncate/append.
3. **Gas alias:** keep `**write_elf_chunk`** / `**unlink`** / `**chmod_executable**` `jmp` stubs in `runtime_extra.s` so older seeds’ `call` names still link (as before).

**Exit criteria:** `cc`-linked `build/diva-stage2-boot` runs `diva build examples/ret0.diva`, `run examples/print2.diva`, `**run examples/vec_demo.diva`** without SIGSEGV; then `diva build compiler/` with `**DIVA_SKIP_NATIVE_EXTERN_CHECK=1`** only if seed still lags (ideally remove skip once bootstrap promoted).

## Phase 2 — Bootstrap ladder (cc-link → pure → promote)

```mermaid
flowchart LR
  seed[bootstrap diva-linux-amd64]
  asm[cc-link merged.s + runtime_extra + runtime.o]
  stage2[build/diva-stage2-boot]
  pure[pure ELF /tmp/diva-native-exe]
  pin[bootstrap/diva-linux-amd64 promoted]

  seed --> asm --> stage2
  stage2 -->|"DRIVER=stage2 scripts/build-compiler-pure-elf.sh"| pure
  pure --> pin
```



1. Run `[scripts/legacy/build-compiler-cc-link.sh](diri-lang/scripts/legacy/build-compiler-cc-link.sh)` (ASM timeout already configurable) → `**build/diva-stage2-boot**`.
2. Run `[scripts/build-compiler-pure-elf.sh](diri-lang/scripts/build-compiler-pure-elf.sh)` with `**DRIVER=build/diva-stage2-boot**` and sufficient `**BUILD_TIMEOUT_SECS**` → copy output to `**build/diva-compiler-pure-elf**`.
3. Follow `[bootstrap/README.md](diri-lang/bootstrap/README.md)` / existing promote scripts: replace committed `**bootstrap/diva-linux-amd64**` (and document backup filename), so day-to-day `**verify-pure-compiler-build.sh**` uses the new trust root **without** skip-env hacks long-term.
4. Add `**DIVA_SKIP_NATIVE_EXTERN_CHECK=1`** to `[scripts/verify-pure-compiler-build.sh](diri-lang/scripts/verify-pure-compiler-build.sh)` **only until** promotion, or remove once seed matches—document in `[docs/seed-codegen-workarounds.md](diri-lang/docs/seed-codegen-workarounds.md)` if touched.

## Phase 3 — Tests and dual-seed removal

- In `[tests/run.sh](diri-lang/tests/run.sh)`: once `**vec_demo`** and integration goldens pass with the **large** self-built driver, **collapse** `INTEGRATION_SEED` / `EARLY_PIPELINE_SEED` to a **single** `DIVA_TEST_SEED` / default bootstrap path; delete obsolete `.bak-*` default if inappropriate.
- Run `**DIVA_TEST_FAST=0`** full harness and `verify-pure-compiler-build.sh` with `**DRIVER`** set to the pure artifact.

## Phase 4 — Maintainer ergonomics

- Add `[scripts/gen-pure-host-builtin-bytes.sh](diri-lang/scripts/gen-pure-host-builtin-bytes.sh)`: assemble `compiler/res/*.s` → `objcopy -O binary -j .text` → print **length + C/Diva-style** byte list for pasting into `pure_elf_builtins.diva` / `codegen_x86.diva` (per original plan).

## Risks / constraints

- **Stack red zone** `print_int` is Linux-ABI–dependent; acceptable for the pure driver target but document if non-Linux hosts matter.
- **Bootstrap chicken-and-egg:** seed `asm` always uses **seed’s** embedded codegen; skip-env + cc-link + pure build is the supported ladder until the promoted binary catches up.
- **WSL2:** re-validate `host_getenv` stack walk and `vfork`/`execve` path on target Linux.


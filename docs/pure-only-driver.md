# Pure-only driver (integration matrix)

This document matches the “pure-only driver” exit criteria from the product plan: run the **same** driver binary that `diva build compiler/` emits (pure ELF, no gcc-linked `runtime.o` in the artifact), not the libexec overlay of `build/diva-stage2`.

## Current status

- **Smoke:** `diva lex` / `diva parse` on a one-line program work with the pure driver (`ROOT_DIR` + `DI_STDLIB_DIR` set).
- **Pipeline (`ir`, `asm`, `run`, …):** the pure-built driver can still **SIGSEGV** early (e.g. `ir` on a tiny file). Kernel logs show **`RIP == 0`** (null address) with **`r15`** often still pointing at a plausible stack — i.e. not only the earlier `host_getenv` / **`r15`** environ-anchor bug.
- **`r15` / `read_file` / `file_size`:** inline pure builtins for `read_file` and `file_size` must **preserve `r15`** (see `emit_pure_read_file` / `emit_pure_file_size` in `compiler/src/pure_elf_builtins.diva`). Without that, `merge_file_sources` could call `read_file` before `loader_newline` → `host_getenv` and walk a bogus environ. **`merge_file_sources` / `merge_package_sources`** also resolve `DI_STDLIB_DIR` / newline **before** the primary `read_file` to reduce ordering hazards.
- **Entry stub (`cg_module_to_bin`):** the RX entry no longer uses **`jmp main`** alone (no return address). It uses **`mov r15,rsp` → `call main` → `mov rdi,rax` → `syscall` (exit)** so a stray `ret` from `main` lands on the trampoline instead of popping garbage (**18**-byte stub; pass1 `current_offset` matches).
- **Refreshing `build/diva-stage2` after builtin-byte edits:** syscall blobs are emitted by whatever compiler built **`build/diva-stage2`**. After changing `emit_pure_*` bodies or `pure_builtin_call_size_*`, rebuild the cc-linked driver so the seed emits fresh gas, e.g. `sh scripts/legacy/build-compiler-cc-link.sh`, then `DIVA_SKIP_NATIVE_EXTERN_CHECK=1 build/diva-stage2 build compiler/`.
- **Codegen:** `cg_module_to_bin` asserts **pass1 and pass2 total code length match** (`instr_total` vs `int_vec_len(out)` after emitting functions). That check **passes** when building `/tmp/diva-native-exe`, so the failure is **not** a simple global inline-builtin size mismatch.
- **Defensive guards:** pure blobs for `str_builder_append`, `str_builder_len`, `str_builder_to_str`, `str_builder_free`, and `int_vec_*` include **null / low-pointer** checks where relevant; keep them even while debugging the ret-to-0 issue.

## Repro matrix (manual)

| Goal | Command sketch |
|------|----------------|
| Tests without libexec overlay | `DIVA_TESTS_LIBEXEC_OVERLAY=0` (see `tests/run.sh`) so the installed driver under test is **not** replaced by `build/diva-stage2` when it is not the pinned seed. |
| Strict pure list | `tests/run-strict-pure.sh` — override driver with **`DIVA_PURE_DRIVER=/tmp/diva-native-exe`** after refreshing the pure exe (below). |
| Refresh pure driver | `DIVA_SKIP_NATIVE_EXTERN_CHECK=1 build/diva-stage2 build compiler/ /tmp/diva-native-exe` (from repo root; needs gcc-linked `build/diva-stage2` until the seed implements all native externs). |
| Curated smoke | `scripts/verify-pure-only-driver.sh` — **default:** `lex` + `parse` only. **Full gate:** `DIVA_PURE_FULL=1 ./scripts/verify-pure-only-driver.sh` (includes `ir` / `asm`; fails until the crash is fixed). |

## gdb / addr2line (host)

When `gdb` is available:

```sh
gdb -batch -ex run -ex bt --args env ROOT_DIR="$PWD" DI_STDLIB_DIR="$PWD/stdlib" /tmp/diva-native-exe ir /path/to/file.diva
```

Use `addr2line -e /tmp/diva-native-exe 0x…` on PCs from `bt` if symbols are thin (PIE: add load base if needed).

Without gdb, a minimal ptrace helper can print **rip / rsp / [rsp]** at `SIGSEGV` (compile once with `gcc -o /tmp/rip_segv rip_segv.c`):

```c
/* fork + PTRACE_TRACEME + execve driver; on SIGSEGV PTRACE_GETREGS + PTRACE_PEEKDATA rsp */
```

## Pure codegen note: `str_len` after host/pure extern calls

The in-process pure backend can mis-schedule **`str_len(x)`** when **`x`** is the **immediate** return value of **`read_file`**, **`merge_file_sources`**, **`merge_package_sources`**, or similar externs (value still in transient registers). **Workaround in Diva source:** bind the string, then bind the length, then branch, e.g. `var src = read_file(p)` / `var n = str_len(src)` / `if n == 0 { … }`. The loader and driver commands use this pattern so `merge` + `ir`/`asm`/`emit-ir`/`build`/`run`/`check` stay stable on the pure driver once the ret-to-0 issue is resolved.

## Exit criteria (definition of done)

- `DIVA_TESTS_LIBEXEC_OVERLAY=0` + `DIVA_TEST_FAST=1` **`tests/run.sh`** green using **only** the driver produced by `diva build compiler/` (pure output).
- `scripts/promote-bootstrap-seed.sh` second-stage **`bootstrap/diva-linux-amd64` `build compiler/`** green **without** restoring the backup seed, and without `DIVA_SKIP_NATIVE_EXTERN_CHECK` unless the pin intentionally lags (see `bootstrap/README.md`).

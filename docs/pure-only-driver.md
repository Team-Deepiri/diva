# Pure-only driver (integration matrix)

This document matches the “pure-only driver” exit criteria from the product plan: run the **same** driver binary that `diva build compiler/` emits (pure ELF, no gcc-linked `runtime.o` in the artifact), not a forced libexec overlay of a gcc-linked `build/diva-stage2`.

## Status — exit criteria met (Issue #55)

| Gate | Result |
|------|--------|
| `DIVA_PURE_FULL=1 ./scripts/verify-pure-only-driver.sh` | **OK** (`lex` / `parse` / `ir` / `asm` + fail-case rc) |
| `promote-bootstrap-seed.sh` second-stage without `DIVA_SKIP_NATIVE_EXTERN_CHECK` | **OK** |
| `tests/run.sh` with `DIVA_TESTS_LIBEXEC_OVERLAY=0` on pure-built driver | **OK** (fast path) |
| Default install / self-host / verify scripts | no longer force `DIVA_SKIP_NATIVE_EXTERN_CHECK=1` |
| Max RSS `build compiler/` (tip) | ~243 MiB (`/usr/bin/time`); see note below vs historical ~168 MiB arena leave-off |

Historical crash notes (ret-to-0 / `r15` / entry trampoline) remain below as **forensics** — the tip pure driver no longer SIGSEGVs on the full verify gate.

## Historical forensics (fixed on tip)

- **Pipeline (`ir`, `asm`, …):** earlier tip builds could **SIGSEGV** with **`RIP == 0`**. Entry stub now uses **`mov r15,rsp` → `call main` → exit trampoline** (not bare `jmp main`).
- **`r15` / `read_file` / `file_size`:** pure builtins must **preserve `r15`** (`emit_pure_read_file` / `emit_pure_file_size`). Loader resolves `DI_STDLIB_DIR` / newline before primary `read_file`.
- **Codegen:** `cg_module_to_bin` asserts pass1/pass2 length match.
- **Defensive guards:** null / low-pointer checks in pure `str_builder_*` / `int_vec_*` blobs remain.

## Repro matrix (manual)

| Goal | Command sketch |
|------|----------------|
| Tests without libexec overlay | `DIVA_TESTS_LIBEXEC_OVERLAY=0 DIVA_PURE_BUILD_DRIVER=$PWD/build/diva-compiler-pure-elf DIVA_TEST_FAST=1 sh tests/run.sh` |
| Strict pure list | `tests/run-strict-pure.sh` — override with **`DIVA_PURE_DRIVER=…`** |
| Refresh pure driver | `./scripts/build-compiler-pure-elf.sh` (no skip flag required on promoted seed) |
| Curated smoke / full gate | `./scripts/verify-pure-only-driver.sh` — set **`DIVA_PURE_FULL=1`** for `ir` / `asm` |
| Promote trust root | `DI_STDLIB_DIR=$PWD/stdlib DI_RUNTIME_O=$PWD/bootstrap/runtime-linux-amd64.o ./scripts/promote-bootstrap-seed.sh` |

## Pure codegen note: `str_len` after host/pure extern calls

Bind extern string results before `str_len`: `var src = read_file(p)` / `var n = str_len(src)` / `if n == 0 { … }`. Loader and driver follow this pattern.

## RSS note

`docs/LEAVE_OFF.md` recorded ~168 MiB max RSS for an earlier arena fixed point. Tip `build compiler/` measures ~243 MiB (`max_rss_kb≈248552`) with a larger language surface on the same arena — not a return to multi‑GiB string maps. Re-baseline leave-off if a dedicated RSS PR lands.

## Exit criteria (definition of done) — **closed**

- [x] `DIVA_PURE_FULL=1` verify-pure-only-driver (`ir` / `asm`)
- [x] `DIVA_TESTS_LIBEXEC_OVERLAY=0` + pure driver `tests/run.sh` (fast)
- [x] Promote second-stage without forced skip
- [x] Docs updated; skip no longer default in install / verify / selfhost

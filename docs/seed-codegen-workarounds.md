# Seed / stage2 codegen workarounds (Diva → asm → GCC)

The pinned **seed** (`bootstrap/diva-linux-amd64`) turns merged Diva into GNU as syntax; **GCC** then builds `build/diva-stage2`. Under some shapes of generated C/asm, the resulting **native** `diva-stage2` misbehaves at **runtime** (busy loop or apparent hang) even though the Diva source is logically correct.

These issues are **not** fixed inside the closed seed binary; the **mitigation is entirely in Diva** by keeping certain functions small and shallow.

## 1. Long `str_eq` chains in one function

**Symptom:** CPU spins forever when `pure_builtin_extern_id` (or similar) contained many sequential `if str_eq(nm, "…")` branches, including the pattern `host_argc`, `host_argv`, then a third `str_eq` in the **same** function.

**Mitigation:** Split name matching into small helpers, e.g. `pure_builtin_extern_id_hi_vec`, `pure_builtin_extern_id_hi_io`, `pure_builtin_extern_id_hi_host`, orchestrated by `pure_builtin_extern_id_hi` (`compiler/src/pure_elf_builtins.diva`). The thin wrapper `pure_builtin_extern_id` in `codegen_x86.diva` keeps builtins 1–8 and defers the rest.

## 2. Large `emit_pure_builtin_call` (low ids + high dispatch)

**Symptom:** `diva-stage2 build` hung on larger programs (e.g. `examples/json_demo.diva`) when one function contained both the full emit bodies for ids 1–8 **and** dispatch to the pure-ELF high builtins.

**Mitigation:** Move ids 1–8 into `emit_pure_builtin_call_lo`; `emit_pure_builtin_call` only routes (`compiler/src/codegen_x86.diva`). High ids dispatch through `emit_pure_builtin_high_*` in `pure_elf_builtins.diva`.

## 3. `cg_module_to_str` on the pure-ELF build path

**Symptom:** With `DIVA_NO_EXTERNAL=1`, building string-heavy programs could hang in `cg_module_to_str` even though pure mode only needs `cg_module_to_bin`.

**Mitigation:** Emit gas text only when linking `runtime.o`; skip `cg_module_to_str` on the pure-ELF path (`compiler/src/main.diva`).

## Related

- Strict pure CI list: `tests/strict-pure.list` (single-file examples that fit the native subset and pure extern set).
- `tests/run-strict-pure.sh` reads that list.

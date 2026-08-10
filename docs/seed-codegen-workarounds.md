# Seed / stage2 codegen workarounds (Diva → asm → GCC)

There are **two** ways you end up with a native compiler binary:

1. **`scripts/build-compiler-cc-link.sh`** — seed emits **gas**, **GCC** links `merged.o` + CRT + `runtime-linux-amd64.o` → `build/diva-stage2`. That binary is what exposed the **runaway / hang** on certain giant functions (GCC’s codegen of the emitted asm/C-like output), so we **reshape Diva** (§1–§2) so GCC emits sane code.
2. **Pure ELF path** in `native_compile_and_link` — no `runtime.o`, no `cc`/`ld` for **your** program: only `cg_module_to_bin` + the in-Diva ELF writer (`native_write_exe` still uses `sh` / `python3` / `chmod` to stream bytes to disk). The pinned **seed** and `scripts/build-bootstrap-driver-merged.sh` / `scripts/promote-bootstrap-seed.sh` are written to use this path for **`diva build compiler/`** when the hosted link is not used.

You **cannot** patch the opaque seed ELF in git to “fix GCC.” You **can** (a) keep Diva in shapes GCC tolerates, and/or (b) **stop using GCC for the compiler artifact** by building and promoting the pure-ELF driver (below).

## 1. Long `str_eq` chains in one function

**Symptom:** CPU spins forever when `pure_builtin_extern_id` (or similar) contained many sequential `if str_eq(nm, "…")` branches, including the pattern `host_argc`, `host_argv`, then a third `str_eq` in the **same** function.

**Mitigation:** Split name matching into small helpers, e.g. `pure_builtin_extern_id_hi_vec`, `pure_builtin_extern_id_hi_io`, `pure_builtin_extern_id_hi_host`, orchestrated by `pure_builtin_extern_id_hi` (`compiler/src/pure_elf_builtins.diva`). The thin wrapper `pure_builtin_extern_id` in `codegen_x86.diva` keeps builtins 1–8 and defers the rest.

## 2. Large `emit_pure_builtin_call` (low ids + high dispatch)

**Symptom:** `diva-stage2 build` hung on larger programs (e.g. `examples/json_demo.diva`) when one function contained both the full emit bodies for ids 1–8 **and** dispatch to the pure-ELF high builtins.

**Mitigation:** Move ids 1–8 into `emit_pure_builtin_call_lo`; `emit_pure_builtin_call` only routes (`compiler/src/codegen_x86.diva`). High ids dispatch through `emit_pure_builtin_high_*` in `pure_elf_builtins.diva`.

## 3. `cg_module_to_str` on the pure-ELF build path

**Symptom:** With `DIVA_NO_EXTERNAL=1`, building string-heavy programs could hang in `cg_module_to_str` even though pure mode only needs `cg_module_to_bin`.

**Mitigation:** Emit gas text only when linking `runtime.o`; skip `cg_module_to_str` on the pure-ELF path (`compiler/src/main.diva`).

## 4. End state you want: compiler binary without C / link (**Diva-emitted ELF only**)

**Goal:** The trust-root / stage2 executable’s **`.text` is only what Diva’s backend wrote** (`cg_module_to_bin` + ELF headers), not a GCC-linked `merged.o`.

**Do this (C toolchain only optional for one-off experiments elsewhere):**

1. Ensure `native_compile_and_link` takes the **pure ELF** branch for the build you care about: omit **`DIVA_ALLOW_HOSTED_LINK`**, set **`DIVA_NO_EXTERNAL=1`**, or unset / hide **`DI_RUNTIME_O`** / `bootstrap/runtime-linux-amd64.o` so the driver does not select the hosted `cc` path (see `compiler/src/main.diva`).
2. Build the merged driver with the **seed** only:  
   `sh scripts/build-bootstrap-driver-merged.sh build/diva-driver-merged`  
   or promote: `sh scripts/promote-bootstrap-seed.sh` (see comments in that script — it prefers the seed’s `diva build compiler/` output).
3. Install the result as `bootstrap/diva-linux-amd64` and use **that** binary day-to-day. Your **language + compiler logic** stays `.diva`; the **blob on disk** is Diva-generated machine code + static ELF layout, not “a C program.”

You still need a **normal host** for `native_write_exe` (shell + Python to append hex to the file) until that step is rewritten in Diva too. Chunk size is tuned for Linux’s **per‑argv‑string** limit (~128KiB): each chunk is hex‑encoded in one `python3 -c` argument, so multi‑MiB ELFs still use far fewer subprocesses than tiny chunks.

**Prove the full pure compiler build:** `sh scripts/verify-pure-compiler-build.sh` (writes `build/.pure-elf-compiler/verify-build.log`; can take many CPU‑minutes — that is expected, not a hang).

## 5. “Fix it for real” in the GCC pipeline (optional, if you keep `build-compiler-cc-link.sh`)

If you insist on **gas + GCC** for `diva-stage2`:

- **Minimize** `build/.compiler-cc-link/merged.s` from a hanging build with `diva asm`, bisect which **function** triggers the spin, file a **GCC** bug with that `.s` (or the C if your pipeline lowers to C), **or**
- **Clang** instead of GCC for the same asm link step — often enough to dodge a single-backend bug without changing Diva.

That path does **not** make the final artifact “all Diva”; it only fixes the broken toolchain step.

## 6. Parser surface: avoid `>=` / `<=` in conditions

The pinned seed / native subset parser rejects **`>=` and `<=` in `if` conditions** (you get `unexpected token … EQ`). Use **`!(id < n)`** / **`!(id > n)`** instead (see `emit_pure_builtin_call` in `codegen_x86.diva`).

## 7. `str_len` on the return of an extern / merge call (pure codegen)

**Symptom:** SIGSEGV or wrong control flow on the **pure-ELF** driver when code does `if str_len(read_file(…)) == 0` or `str_len(merge_file_sources(…))` with **no** intermediate `str` / `int` binding.

**Why:** The in-process pure backend can leave the string value in a **transient** register path; using it **immediately** as the sole argument to **`str_len`** can mis-schedule and corrupt the value used in the call.

**Mitigation in Diva source:** always bind, then length, then branch, e.g. `var s = read_file(p); var n = str_len(s); if n == 0 { … }` (same idea for `merge_file_sources` / `merge_package_sources` / `read_source` results). The compiler **loader** and **driver** (`compiler/src/loader.diva`, `compiler/src/main.diva`) follow this pattern.

## Related

- Strict pure CI list: `tests/strict-pure.list` (single-file examples that fit the native subset and pure extern set).
- `tests/run-strict-pure.sh` reads that list.
- Bootstrap / promotion: `bootstrap/README.md`, `scripts/promote-bootstrap-seed.sh`, `scripts/build-bootstrap-driver-merged.sh`.
- One-shot pure compiler ELF (no `cc` on the build path): `scripts/build-compiler-pure-elf.sh` (uses `DIVA_NO_EXTERNAL=1`; full `compiler/` can take a long time).
- Full pure `compiler/` build check (log + exit status): `scripts/verify-pure-compiler-build.sh`.
- Pure-only driver matrix and exit criteria: `docs/pure-only-driver.md`, `scripts/verify-pure-only-driver.sh`.

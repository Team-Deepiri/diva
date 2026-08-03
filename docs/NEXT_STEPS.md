# Next steps — pure ELF bootstrap (2026-08-03)

## Artifact rule (do not break this)

**Never** rely on `/tmp/diva-native-exe`. `/tmp` gets wiped; we already lost a good build that way.

| Role | Persistent path |
|------|-----------------|
| Hosted stage2 (cc-link) | `build/diva-stage2-from-cc` |
| Latest pure driver (stage2 → pure) | `build/diva-compiler-pure-elf` |
| Second-stage pure (pure → pure) | `build/diva-compiler-pure-elf-stage2` |
| Promoted trust root | `bootstrap/diva-linux-amd64` |

**Promote only from the latest successful persistent binary** — prefer `build/diva-compiler-pure-elf-stage2` once that exists; until then `build/diva-compiler-pure-elf`. Always `cp -a` that file → `bootstrap/diva-linux-amd64` after verifying it.

```sh
# canonical build outs (no /tmp)
DIVA_SKIP_NATIVE_EXTERN_CHECK=1 DIVA_NO_EXTERNAL=1 \
  ./build/diva-stage2-from-cc build compiler/ "$PWD/build/diva-compiler-pure-elf"

DIVA_PURE_DRIVER="$PWD/build/diva-compiler-pure-elf" ./scripts/verify-pure-only-driver.sh
ROOT_DIR="$PWD" DI_STDLIB_DIR="$PWD/stdlib" \
  ./build/diva-compiler-pure-elf check compiler/
```

## Where we are right now

1. **Stage2 refresh** (cc-link with **16 MiB** mmap fix) — **done**
2. **Stage2 → pure ELF** (`build/diva-compiler-pure-elf`) — **done** (lex/parse + `check compiler/` green)
3. **Second stage** (pure rebuilds itself) — **blocked**: SIGSEGV ~100s into `build compiler/` (past mmap; `RIP≈0` class — `docs/pure-only-driver.md`)
4. **Promote + push** — first-stage pure is in `bootstrap/diva-linux-amd64` (`a8ac9ae` / status `70f8c28`). Re-promote **after** second-stage produces `build/diva-compiler-pure-elf-stage2`.

## Brainstorm — how to get past the SIGSEGV

Hypothesis stack (attack in this order; each is falsifiable):

### A. Confirm the crash class (30–60 min)

1. Reproduce with the **persistent** driver only:
   ```sh
   ROOT_DIR="$PWD" DI_STDLIB_DIR="$PWD/stdlib" \
     DIVA_SKIP_NATIVE_EXTERN_CHECK=1 DIVA_NO_EXTERNAL=1 \
     gdb -batch -ex run -ex bt --args \
       ./build/diva-compiler-pure-elf build compiler/ "$PWD/build/diva-compiler-pure-elf-stage2"
   ```
2. Record **RIP, RSP, `[RSP]`, R15**. If `RIP==0` and `[RSP]==0`, this is the documented ret-to-null path, not mmap.
3. Also try the smaller gate first (isolates merge/codegen without full package):
   ```sh
   DIVA_PURE_DRIVER="$PWD/build/diva-compiler-pure-elf" DIVA_PURE_FULL=1 \
     ./scripts/verify-pure-only-driver.sh   # ir/asm on tiny file
   ```
   - If **tiny `ir`/`asm` SIGSEGV**: bug is in general pure codegen / entry / call, not “compiler package too big”.
   - If **tiny OK but `build compiler/` SIGSEGV**: bug is scale/merge/package-specific (ordering, a hot function, or a late builtin).

### B. Likely root causes (from in-tree notes)

| Suspect | Why | What to try |
|---------|-----|-------------|
| **Stray `ret` → RIP 0** | Entry stub was fixed to `call main`+exit trampoline, but some path still `ret`s with empty/null return addr | Audit `cg_p2_ret` / non-main funcs; ensure every call site pushes a real return; re-check stub size vs pass1 |
| **`r15` clobber** | Environ / stack anchor; `read_file`/`file_size` must preserve `r15` | Grep emit blobs for `r15`; any new builtin that touches syscall args without save/restore |
| **`str_len` on transient regs** | Known pure mis-schedule | Audit `build`/`merge` paths for missing `_hold` bindings (`docs/seed-codegen-workarounds.md`) |
| **Pass1/pass2 size drift on one opcode** | Global check can pass while a single site emits wrong size → bad branch | Add per-opcode asserts; bisect last emitted func before crash |
| **`write_elf_chunk` / host_system** | Materializing ELF mid-build | Confirm id 32 blob + path; segfault during write vs during compile |
| **Still-silent int_vec full** | Unlikely at 16 MiB, but push still fails quiet | Temporary: abort/print on push when `len==cap` instead of no-op |

### C. Debug tactics that scale

1. **Shrink the input** — `build` a single `compiler/src/*.diva` (or merged subset) until SIGSEGV disappears; binary-search which file/function triggers it.
2. **Ptrace helper** — if gdb symbols are thin, use the rip/[rsp] peek from `docs/pure-only-driver.md`.
3. **Compare hosted vs pure on same IR** — stage2 `ir`/`asm` on the failing unit vs pure; where pure diverges is the smoking gun.
4. **Instrument** — print to stderr at start of `native_compile_and_link`, after merge, after `cg_module_to_bin`, before `write_elf_chunk` so we know the last live phase (~100s timing suggests deep into compile, not instant entry).

### D. Definition of “past the SIGSEGV”

```sh
# must all succeed using persistent paths only
./build/diva-compiler-pure-elf build compiler/ "$PWD/build/diva-compiler-pure-elf-stage2"
./build/diva-compiler-pure-elf-stage2 check compiler/
./build/diva-compiler-pure-elf-stage2 build compiler/ "$PWD/build/diva-compiler-pure-elf-stage3"
# then promote the latest converged binary:
cp -a build/diva-compiler-pure-elf-stage2 bootstrap/diva-linux-amd64   # or stage3 if bit-identical / accepted
```

## Do next (priority)

1. **Execute brainstorm §A–C** — land a fix for pure `build` / `ir` SIGSEGV; keep artifacts under `build/`.
2. **Second-stage → `build/diva-compiler-pure-elf-stage2`** — prove pure rebuilds pure.
3. **Promote that latest binary** to `bootstrap/diva-linux-amd64` (not an old `/tmp` copy); commit + push.
4. **Drop `DIVA_SKIP_NATIVE_EXTERN_CHECK`** when seed lists all pure externs.
5. **`DIVA_PURE_FULL=1`** verify green.
6. **Real realloc** for pure push/append.
7. Cleanup: `./scripts/cleanup-dev-artifacts.sh` (`--all` clears stale `/tmp/diva-*` leftovers only).

## Rebuild recipe (emit_* / mmap blob edits)

```sh
# 1) bake emitters into hosted stage2 (required after pure_elf_builtins.diva blob edits)
ASM_TIMEOUT_SECS=7200 ./scripts/legacy/build-compiler-cc-link.sh build/diva-stage2-from-cc

# 2) latest pure — ALWAYS under build/
DIVA_SKIP_NATIVE_EXTERN_CHECK=1 DIVA_NO_EXTERNAL=1 \
  ./build/diva-stage2-from-cc build compiler/ "$PWD/build/diva-compiler-pure-elf"

# 3) self-host gate — latest second stage under build/
DIVA_SKIP_NATIVE_EXTERN_CHECK=1 DIVA_NO_EXTERNAL=1 \
  ./build/diva-compiler-pure-elf build compiler/ "$PWD/build/diva-compiler-pure-elf-stage2"

# 4) promote the newest successful pure binary
cp -a build/diva-compiler-pure-elf-stage2 bootstrap/diva-linux-amd64
```

## Done this session

- 16 MiB exact-fit mmap caps; math check script.
- Stage2 refresh + first-stage pure; promoted to seed.
- Cleanup script; this status / brainstorm / artifact policy.

# Next steps — pure ELF bootstrap (2026-08-03)

## Done this session

- Fixed pure `int_vec` / `str_builder` mmap math: **16 MiB** exact-fit caps (`0x1000000`), after 4 MiB proved too small for full-compiler codegen (1 int slot per machine byte → `ir_br_cond expected=21 got=0`).
- `tok_esc_cr` already correct (ASCII 13) on this branch.
- Hosted stage2 refreshed via `scripts/legacy/build-compiler-cc-link.sh` so emit blobs bake into the pure driver.
- First-stage pure ELF built, smoke `lex`/`parse` + `check compiler/` green.
- **Promoted** that pure ELF to `bootstrap/diva-linux-amd64` (statically linked pure driver).
- Added `scripts/check-pure-mmap-math.py` and `scripts/cleanup-dev-artifacts.sh` (`cleanup.sh` wraps it).

## Blocked — not yet self-sustaining

**Second-stage** (`pure build compiler/` → new pure ELF) still **SIGSEGV** ~100s in. That is past the mmap/capacity bug; it matches the known pure codegen / `RIP≈0` failure mode in `docs/pure-only-driver.md` (full `ir`/`build` path).

Until that is fixed, the seed **cannot** rebuild itself. Day-to-day: lex/parse/check work; `diva build compiler/` on the pure seed does not.

## Do next (priority)

1. **Debug pure `build` SIGSEGV** — gdb/ptrace on  
   `ROOT_DIR=$PWD DI_STDLIB_DIR=$PWD/stdlib DIVA_SKIP_NATIVE_EXTERN_CHECK=1 /tmp/diva-native-exe build compiler/`  
   Goal: no `RIP==0`; then second-stage green.
2. **Converge seed** — once second-stage works:  
   `cp` stage2 output → `bootstrap/diva-linux-amd64`, re-run build without restore.
3. **Drop skip** — clear `DIVA_SKIP_NATIVE_EXTERN_CHECK` in install/CI when seed lists all pure externs.
4. **`DIVA_PURE_FULL=1 ./scripts/verify-pure-only-driver.sh`** when ir/asm stop crashing.
5. **Real realloc** for pure push/append (stop fixed mmap caps).
6. Cleanup when messy: `./scripts/cleanup-dev-artifacts.sh` (`--all` for tmp/docker/bak).

## Rebuild recipe (after emit_* changes)

```sh
# emit_* live in stage2 — must cc-link again after blob edits
ASM_TIMEOUT_SECS=7200 ./scripts/legacy/build-compiler-cc-link.sh build/diva-stage2-from-cc
DIVA_SKIP_NATIVE_EXTERN_CHECK=1 DIVA_NO_EXTERNAL=1 \
  ./build/diva-stage2-from-cc build compiler/ /tmp/diva-native-exe
# only promote after: /tmp/diva-native-exe build compiler/ succeeds
```

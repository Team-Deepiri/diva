# Next steps — pure ELF bootstrap (2026-08-03 evening)

## Status: second-stage self-host is green

| Step | Result |
|------|--------|
| Tiny pure `build` | green (no SIGSEGV) |
| Stage2 → pure (`build/diva-compiler-pure-elf`) | green ~708KiB ELF, CLI out path |
| Pure → pure (`build/diva-compiler-pure-elf-stage2`) | **green** ~708KiB ELF (`\\x7fELF`) |
| Stage2 `check compiler/` + tiny `build` | green |
| Promoted seed | `bootstrap/diva-linux-amd64` ← stage2 pure |

## Artifact rule (do not break this)

**Never** rely on `/tmp/diva-native-exe`. Canonical outs:

- `diva build <src> <out>` (second positional)
- else `DIVA_NATIVE_EXE_OUT`
- else `$ROOT_DIR/build/diva-native-exe`

| Role | Path |
|------|------|
| Hosted stage2 (cc-link) | `build/diva-stage2-from-cc` |
| Stage2 → pure | `build/diva-compiler-pure-elf` |
| Pure → pure | `build/diva-compiler-pure-elf-stage2` |
| Trust root | `bootstrap/diva-linux-amd64` |

## Fixes landed this session (need all three)

1. **Inlined `ret` in unlink/chmod** — caused RIP=`0xff` SIGSEGV after ELF writeout. Fall-through only; unlink size 33→30.
2. **`/tmp` hardcode** — `build` ignored CLI out path. Now honors out / env / `build/diva-native-exe`.
3. **`write_elf_chunk` clobbered `is_first` (`r8`)** — mmap set `r8=-1`, so every chunk used `O_TRUNC`; only last chunk survived (`708608 % 64000 = 4608` bytes of ASCII junk). **Save `is_first` on stack across mmap**; blob size 224→234.

## Rebuild recipe (after emit_* / size edits)

**Critical:** update `emit_pure_*` **and** `pure_builtin_call_size` **before** starting cc-link (parallel edit+rebuild raced once → pass1/pass2 mismatch +10).

```sh
# 1) Hosted stage2 — use bak SEED if current stage2 SIGSEGVs on full `asm`
SEED="$PWD/build/diva-stage2-from-cc.bak-before-retfix-20260803163133" \
  ASM_TIMEOUT_SECS=7200 \
  sh scripts/legacy/build-compiler-cc-link.sh build/diva-stage2-from-cc-new
mv -f build/diva-stage2-from-cc-new build/diva-stage2-from-cc

# 2) Stage2 → pure (pipefail so tee doesn't mask failures)
set -o pipefail
ROOT_DIR="$PWD" DI_STDLIB_DIR="$PWD/stdlib" \
  DIVA_SKIP_NATIVE_EXTERN_CHECK=1 DIVA_NO_EXTERNAL=1 \
  ./build/diva-stage2-from-cc build compiler/ "$PWD/build/diva-compiler-pure-elf"

# 3) Pure → pure (second stage)
./build/diva-compiler-pure-elf build compiler/ "$PWD/build/diva-compiler-pure-elf-stage2"
file build/diva-compiler-pure-elf-stage2   # must be ELF, ~708KiB
./build/diva-compiler-pure-elf-stage2 check compiler/
./build/diva-compiler-pure-elf-stage2 build build/tiny-ret0.diva "$PWD/build/diva-tiny-s2"

# 4) Promote
cp -a build/diva-compiler-pure-elf-stage2 bootstrap/diva-linux-amd64
```

## Do next (pick up here)

1. **Drop `DIVA_SKIP_NATIVE_EXTERN_CHECK`** when seed lists all pure externs; confirm `check`/`build` still green.
2. **`DIVA_PURE_FULL=1`** / `scripts/verify-pure-compiler-build.sh` / `tests/run-strict-pure.sh` — end-to-end CI green on promoted seed.
3. **Hosted stage2 full-`asm` SEGV** — current ret-fixed stage2 can die on `asm` of merged.diva; bak seed works. Root-cause or always document bak SEED.
4. **Real realloc** for pure `int_vec`/`str_builder` push/append (still fixed mmap, silent full).
5. **Optional:** third-stage identity check (`stage2` build of compiler ≈ bit-identical or run-identical to itself).
6. Cleanup: `./scripts/cleanup-dev-artifacts.sh` — do **not** delete bak seeds you still need for cc-link.

## Known footguns

| Symptom | Cause |
|---------|--------|
| Tiny `build` SIGSEGV, RIP≈`0xff` | Inlined `ret` in pure builtin |
| Success but ~4608-byte non-ELF | `is_first` clobber → always `O_TRUNC` |
| `pass1/pass2` mismatch by blob delta | Size table out of sync with `emit_pure_*` (or rebuild race) |
| Seed `asm` looks for `tokens.diva` beside merged file | Pure seed can’t drive cc-link; use hosted bak SEED |
| `cmd \| tee; echo $?` is 0 on failure | Use `set -o pipefail` / `${PIPESTATUS[0]}` |

# Leave-off — pure ELF self-host (2026-08-03)

## Done (pick up after this)

Second-stage **and** third-stage pure self-host are green. Seed promoted.

| Gate | Result |
|------|--------|
| Tiny pure `build` | green (no SIGSEGV) |
| Stage2 → pure | `build/diva-compiler-pure-elf` ~708KiB |
| Pure → pure | `build/diva-compiler-pure-elf-stage2` ~708KiB ELF |
| Stage3 (stage2→itself) | `build/diva-compiler-pure-elf-stage3` — **bit-identical** to stage2 (`md5 455fe3e8…`) |
| Without `DIVA_SKIP_NATIVE_EXTERN_CHECK` | `check compiler/`, tiny `build`, full `build compiler/` all green on promoted seed |
| `verify-pure-only-driver.sh` | OK |
| `DIVA_PURE_FULL=1` verify | OK |
| Promoted seed | `bootstrap/diva-linux-amd64` ← stage2 pure |

## Three bugs that blocked self-host (all fixed)

1. **Inlined `ret` in unlink/chmod** → RIP=`0xff` SIGSEGV after writeout.
2. **`build` hardcoded `/tmp/diva-native-exe`** → lost good artifacts; now CLI out / `DIVA_NATIVE_EXE_OUT` / `$ROOT_DIR/build/diva-native-exe`.
3. **`write_elf_chunk` clobbered `is_first` (`r8`)** via mmap → every chunk `O_TRUNC` → only last chunk (`n % 64000`, often 4608 bytes of junk). Save `is_first` on stack; blob **224→234**.

Also earlier: **16 MiB** pure mmap caps (4 MiB too small for ~700KiB codegen slots).

## Artifact paths

| Role | Path |
|------|------|
| Hosted cc-link stage2 | `build/diva-stage2-from-cc` |
| Stage2 → pure | `build/diva-compiler-pure-elf` |
| Pure → pure | `build/diva-compiler-pure-elf-stage2` |
| Third stage | `build/diva-compiler-pure-elf-stage3` |
| Trust root | `bootstrap/diva-linux-amd64` |

**Never** depend on `/tmp` for keepers.

## Rebuild (after emit_* / size edits)

Update **both** `emit_pure_*` and `pure_builtin_call_size` **before** cc-link (race once caused pass1/pass2 +10 mismatch).

```sh
# Hosted stage2 — use bak SEED if current stage2 SIGSEGVs on full `asm`
SEED="$PWD/build/diva-stage2-from-cc.bak-before-retfix-20260803163133" \
  ASM_TIMEOUT_SECS=7200 \
  sh scripts/legacy/build-compiler-cc-link.sh build/diva-stage2-from-cc-new
mv -f build/diva-stage2-from-cc-new build/diva-stage2-from-cc

set -o pipefail
ROOT_DIR="$PWD" DI_STDLIB_DIR="$PWD/stdlib" DIVA_NO_EXTERNAL=1 \
  ./build/diva-stage2-from-cc build compiler/ "$PWD/build/diva-compiler-pure-elf"
./build/diva-compiler-pure-elf build compiler/ "$PWD/build/diva-compiler-pure-elf-stage2"
# optional identity: stage2 build again → stage3; md5 should match stage2
cp -a build/diva-compiler-pure-elf-stage2 bootstrap/diva-linux-amd64
```

Skip is no longer required for current seed externs; keep `DIVA_SKIP_NATIVE_EXTERN_CHECK=1` only when the pin lags new builtins.

## Do next (remaining work)

1. **Real realloc** for pure `int_vec` / `str_builder` (still fixed 16 MiB mmap; silent full at cap).
2. **Hosted stage2 full-`asm` SEGV** — ret-fixed stage2 can die on `asm` of merged.diva; bak SEED works. Root-cause or keep bak as documented SEED.
3. **`tests/run-strict-pure.sh` / fuller CI** on promoted seed (lex/parse/ir/asm already covered by `DIVA_PURE_FULL=1`).
4. Cleanup: `./scripts/cleanup-dev-artifacts.sh` — **keep** `bootstrap/*.bak-*` and `build/*bak*` seeds needed for cc-link.

## Footguns

| Symptom | Cause |
|---------|--------|
| Tiny `build` SIGSEGV RIP≈`0xff` | Inlined `ret` in pure builtin |
| ~4608-byte non-ELF “success” | `is_first` / always `O_TRUNC` |
| pass1/pass2 mismatch by blob Δ | Size table ≠ emit (or edit/rebuild race) |
| Pure seed `asm` wants `tokens.diva` beside merge | Use hosted bak SEED for cc-link |
| `cmd \| tee; echo $?` lies | `set -o pipefail` / `${PIPESTATUS[0]}` |

See also `docs/NEXT_STEPS.md` (same handoff, shorter checklist).

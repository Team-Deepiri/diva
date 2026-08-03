# Next steps — pure ELF bootstrap

**Leave-off detail:** `docs/LEAVE_OFF.md` (2026-08-03 evening).

## Status (green)

| Gate | Result |
|------|--------|
| Tiny / package `build` (pure) | green |
| Second-stage pure→pure | green ~708KiB |
| Third-stage | **bit-identical** to stage2 |
| No `DIVA_SKIP_NATIVE_EXTERN_CHECK` | `check` + tiny + full `build compiler/` green on seed |
| `verify-pure-only-driver.sh` + `DIVA_PURE_FULL=1` | OK |
| Seed | `bootstrap/diva-linux-amd64` ← stage2 |

## Do next

1. Real **realloc** for pure `int_vec` / `str_builder` (fixed 16 MiB mmap today).
2. Root-cause **hosted stage2 full-`asm` SEGV** (workaround: `build/diva-stage2-from-cc.bak-before-retfix-*` as `SEED=`).
3. Broader CI: `tests/run-strict-pure.sh` on promoted seed.
4. Cleanup junk under `build/` / `/tmp`; **keep** bak seeds for cc-link.

## Artifact rule

`diva build <src> <out>` · or `DIVA_NATIVE_EXE_OUT` · or `$ROOT_DIR/build/diva-native-exe` — **never** keep outputs only in `/tmp`.

## Rebuild after emit/size edits

Sync `emit_pure_*` **and** `pure_builtin_call_size` before cc-link; use bak `SEED=` if stage2 `asm` SEGV; `set -o pipefail` on long builds. Full recipe in `docs/LEAVE_OFF.md`.

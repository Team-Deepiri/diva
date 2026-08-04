# Leave-off — string arena RSS (2026-08-04)

**Parent:** PR #12. **This PR:** #13.

**Self-host:** yes — seed is pure ELF grow (`bootstrap/diva-linux-amd64`).

## Finding

INIT shrink did not move ~28 GiB Max RSS. Cost was **page-rounded** `mmap(len+1)` in `str_builder_to_str`, `int_to_str`, and `str_slice`.

## Fix

Packed bump arena at `0x520000000000` (2 GiB) for those three builtins.

## Result

| Metric | Before | After |
|--------|--------|-------|
| Max RSS full `build compiler/` | ~28 GiB | **~567 MiB** |
| stage2≡stage3 | — | `c9913062…` |
| tiny `<4096` mmaps | ~1M+ | **0** |

Seed promoted to fixed-point pure binary.

## Residual

~135k live 4 KiB `int_vec` pages ≈ RSS floor. Next: AST bump arena.

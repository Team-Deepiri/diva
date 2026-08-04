# Leave-off — pure ELF self-host (2026-08-04)

## Done

| Gate | Result |
|------|--------|
| Second + third-stage pure self-host (abort-on-full seed) | green; stage2≡stage3 |
| Hosted full-package `asm` | **fixed** — `runtime_int_to_str.c` |
| Handle-table grow (sources + smoke) | **green** — vec/builder + `write_elf_chunk` resolve; EEXIST=`-17` |
| `tests/run-strict-pure.sh` | **31/31** on grow stage2 |
| Pure driver builds/runs hello + vec_demo | green |
| Pure second-stage full `compiler/` | **blocked** — `parse failed` on ~300KiB merged package (hosted grow OK) |

Seed still **abort-on-full** (~750KiB); grow seed promote waits on package-parse fix.


## Grow design

- Fixed handle table @ `0x500000000000` (MAP_FIXED_NOREPLACE; any fail ⇒ table ready)
- Handles = indices; objects start **1 MiB**, double via `mremap(MAYMOVE)`
- `scripts/smoke-pure-handle-grow.sh` — 200k pushes
- Footgun fixed: Linux `-EEXIST` is **-17**, not -98

## Do next

1. Fix pure parse of merged `compiler/` package under handle-table runtime; then promote grow seed.  
2. More CI (fail cases / multi-file packages).

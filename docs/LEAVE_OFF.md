# Leave-off — pure ELF self-host (2026-08-04)

## Done

| Gate | Result |
|------|--------|
| Handle-table grow + 1 048 575 slots | green |
| Pure parse merged `compiler/` | **694 decls** |
| Pure second≡third stage | **md5 `69f0fbea…`** |
| `tests/run-strict-pure.sh` | **31/31** on pure stage2 |
| Seed | `bootstrap/diva-linux-amd64` ← grow stage2 (~1.2 MiB) |


## Grow design

- Handle table @ `0x500000000000`, **8 MiB / 1 048 575 slots** (64K exhausted mid-parse)
- Objects start **1 MiB**, double via `mremap(MAYMOVE)`
- FIXED_NOREPLACE fail ⇒ table ready (`-EEXIST` = **-17**)
- `write_elf_chunk` resolves handles
- Smoke: `scripts/smoke-pure-handle-grow.sh`

## Footgun

Full `build compiler/` under grow can peak **~28 GiB RSS** (many live 1 MiB maps). Consider smaller initial mmap next.

## Do next

1. Shrink initial object mmap (e.g. 64–256 KiB) to cut RSS.  
2. More CI (fail cases / packages).

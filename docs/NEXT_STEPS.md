# Next steps — pure ELF bootstrap

**Leave-off:** `docs/LEAVE_OFF.md` (2026-08-04).

## Green

Self-host on abort-on-full seed, hosted `asm`, handle-table grow (examples + strict-pure **31/31**), smoke grow.

## Do next

1. Pure parse of merged `compiler/` under handle table (blocks grow seed promote).  
2. More CI beyond `tests/strict-pure.list`.

## Footguns

| Symptom | Cause / fix |
|---------|-------------|
| Second `*_new` returned 0 | `-EEXIST` is `-17`; treat any FIXED_NOREPLACE fail as table ready |
| `write_elf_chunk` SEGV | Must resolve handle index → object ptr |
| Full-asm SEGV (old hosted) | `runtime_int_to_str.c` ring |
| `/tmp` lost builds | CLI out / `build/` only |
| pass1/pass2 Δ | Sync emit + size before cc-link |

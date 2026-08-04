# Next steps — pure ELF bootstrap

**Leave-off:** `docs/LEAVE_OFF.md` (2026-08-04).

## Green

Pure self-host with **handle-table grow** (stage2≡stage3), strict-pure **31/31**, seed promoted.

## Do next

1. Shrink initial vec/builder mmap to cut ~28 GiB compile RSS.  
2. More CI beyond `tests/strict-pure.list`.

## Footguns

| Symptom | Cause / fix |
|---------|-------------|
| `parse failed` on merged compiler | Handle table full at 64K — now 1 048 575 slots |
| Second `*_new` returned 0 | `-EEXIST` is `-17` |
| `write_elf_chunk` SEGV | Resolve handle → object |
| Huge RSS on full build | 1 MiB initial per object — shrink INIT next |
| pass1/pass2 Δ | Sync emit + size before cc-link |

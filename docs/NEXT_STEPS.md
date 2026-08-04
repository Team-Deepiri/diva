# Next steps — grow INIT RSS

**Leave-off:** `docs/LEAVE_OFF.md` (INIT 64 KiB).

## Do next

1. Finish verify on this branch: stage2≡stage3, Max RSS ≪ 28 GiB, promote seed.  
2. Broader CI (fail cases / packages).

## Footguns

| Symptom | Cause / fix |
|---------|-------------|
| 28 GiB RSS | 1 MiB init × many live objects — use 64 KiB init |
| Handle table full @ 64K | 1 048 575 slots (PR #12) |
| `-EEXIST` check | raw errno **-17** |

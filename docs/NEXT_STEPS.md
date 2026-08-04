# Next steps — grow INIT RSS

**Leave-off:** `docs/LEAVE_OFF.md` (INIT 4 KiB).

## Do next

1. Finish 4 KiB verify: RSS, stage2≡stage3, promote seed on this branch.  
2. Longer term: bump-pointer arena for tiny AST nodes (avoid mmap-per-node).  
3. Broader CI.

## Footguns

| Symptom | Cause / fix |
|---------|-------------|
| ~27 GiB RSS @ 64 KiB init | #live vecs × INIT — use **4 KiB** page |
| Handle table @ 64K | 1 048 575 slots (PR #12) |

# Next steps — pure ELF bootstrap

**Leave-off:** `docs/LEAVE_OFF.md` (2026-08-04).

## Green

Self-host (stage2≡stage3), noskip seed builds, `DIVA_PURE_FULL`, **strict-pure 21/21**, hosted full-package `asm` (int_to_str override).

## Do next

1. ~~Fix hosted stage2 `asm` SEGV~~ — `runtime_int_to_str.c` ring + weaken stock symbol in cc-link.  
2. **Handle-table realloc** for pure vec/builder (real grow).  
3. More CI beyond `tests/strict-pure.list`.

## Footguns

| Symptom | Cause / fix |
|---------|-------------|
| Full-asm SEGV in old stage2 | leaking `int_to_str`; rebuild with current cc-link (override linked in) |
| Silent capacity full | Now `exit_group(2)` in pure push/append |
| `/tmp` lost builds | CLI out / `build/` only |
| pass1/pass2 Δ | Sync emit + size before cc-link |

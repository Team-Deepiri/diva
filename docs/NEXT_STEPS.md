# Next steps — pure ELF bootstrap

**Leave-off:** `docs/LEAVE_OFF.md` (2026-08-04).

## Green

Self-host (stage2≡stage3), noskip seed builds, `DIVA_PURE_FULL`, **strict-pure 21/21**.

## Do next

1. Fix hosted stage2 **`asm` SEGV** (`int_to_str` → snprintf on large `cg_module_to_str`).  
2. **Handle-table realloc** (moving mmap unsafe with raw handles).  
3. More CI beyond `tests/strict-pure.list`.

## Footguns

| Symptom | Cause / fix |
|---------|-------------|
| Full-asm SEGV in stage2 | `int_to_str`/snprintf; use bak SEED (cc-link default) |
| Silent capacity full | Now `exit_group(2)` in pure push/append |
| `/tmp` lost builds | CLI out / `build/` only |
| pass1/pass2 Δ | Sync emit + size before cc-link |

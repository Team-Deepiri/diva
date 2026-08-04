# Next steps — pure ELF bootstrap

**Leave-off:** `docs/LEAVE_OFF.md` (2026-08-04).

## Green

Self-host (stage2≡stage3), noskip seed builds, `DIVA_PURE_FULL`, **strict-pure 21/21**.

## Do next

1. **Rebuild stage2→pure→promote** — land abort-on-full push/append (sizes 54 / 127) in seed.  
2. Fix hosted stage2 **`asm` SEGV** (`int_to_str` → snprintf on large `cg_module_to_str`).  
3. **Handle-table realloc** (moving mmap unsafe with raw handles).  
4. More CI beyond `tests/strict-pure.list`.

## Footguns

| Symptom | Cause / fix |
|---------|-------------|
| Full-asm SEGV in stage2 | `int_to_str`/snprintf; use bak SEED (cc-link default) |
| Silent capacity full | Now `exit_group(2)` in pure push/append |
| `/tmp` lost builds | CLI out / `build/` only |
| pass1/pass2 Δ | Sync emit + size before cc-link |

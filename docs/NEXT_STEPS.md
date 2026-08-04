# Next steps — after string arena

**Leave-off:** `docs/LEAVE_OFF.md` (RSS ~567 MiB; seed promoted).

## Do next

1. Bump arena for tiny AST `int_vec` objects (cut remaining ~0.5 GiB page tax).
2. Broader CI beyond `tests/strict-pure.list`.
3. Optional: skip per-call `FIXED_NOREPLACE` probes once arena/HT are live (micro-opt).

## Footguns

| Symptom | Cause / fix |
|---------|-------------|
| ~28 GiB RSS | page-rounded string `mmap` — STRA arena |
| Emit size drift | sync return + `pure_builtin_call_size` |
| `0xc3` in pure blob | NO ret on inlined builtins |
| Don’t commit | `bootstrap/*.bak-*` |

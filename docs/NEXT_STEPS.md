# Next steps — after AST bump arena

**Leave-off:** `docs/LEAVE_OFF.md` (RSS ~168 MiB; seed promoted to arena fixed point).

## Do next

1. Broader CI beyond `tests/strict-pure.list`.
2. Optional: skip per-call `FIXED_NOREPLACE` probes once arena/HT are live (micro-opt).
3. Optional: arena exhaustion is process-lifetime (no reuse of freed slots); a free-list for
   arena slots would help pathological churn, and the fallback 4 KiB mmap path is untested
   at scale (only hit past 2 GiB of live AST).

## Native codegen gaps (seed-only today)

The pure in-process ELF path (`compiler/src/codegen_x86.diva`) only covers the single-file
subset. These constructs are **parse-only or seed-only** in the native pipeline (see
`docs/diva-roadmap.md` for the full per-node checklist):

1. **OOP surface:** field-only struct/class + obj lit + field access/assign work in native;
   traits + impls validate method names and lower impl methods as free functions (Issue #27);
   class-body methods / trait objects still later.
2. **Control flow:** `nd_flux` / `nd_range` int ranges lower to while (Issue #20);
   array flux still later.
3. **Method calls:** receiver-first free-function lowering (Issue #19).
4. **Imports / multi-file:** merge + diagnostics (Issue #17); dep aliases (Issue #24 phase 1 —
   `docs/module-graph-phase1.md`); full module graph/cache still open.
5. **Array literals beyond int[] init / generics monomorphization:** Issues #22 (remaining) / #26.
   Dynamic `int[]` index + bounds docs landed with this stack; globals (#21) on prior PR.
6. **IR Stage 2:** see `docs/ir-stage2-status.md` (Issue #25).
7. **Backend / kernel track:** `compiler/{mir,backend}/` scaffolding and kernel targets are not
   shipped (see `docs/roadmap.md` phases 8–9).

Ordering suggestion: imports/multi-file first (unblocks real programs), then classes/objects +
method calls, then flux/range, then globals/generics.

## Footguns

| Symptom | Cause / fix |
|---------|-------------|
| ~28 GiB RSS | page-rounded string `mmap` — STRA arena |
| ~0.5 GiB AST RSS floor | 4 KiB per-`int_vec` mmap — ASTA bump arena (cap 13 slots, promote-on-grow) |
| Emit size drift | sync return + `pure_builtin_call_size` |
| `0xc3` in pure blob | NO ret on inlined builtins |
| Don’t commit | `bootstrap/*.bak-*` |

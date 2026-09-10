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

1. **OOP surface:** `nd_class` / `nd_trait` / `nd_impl` / `nd_obj_lit` / `nd_field_init` / `nd_field`
   — no IR lowering, no codegen.
2. **Control flow:** `nd_flux` / `nd_range` — no IR lowering, no codegen.
3. **Method calls:** `nd_method_call` — IR shape fragile; prefers `nd_call`.
4. **Imports / multi-file:** `nd_import` skipped in native IR — pure pipeline is single-file.
   `nd_package_decl` also skipped.
5. **Globals:** `nd_ident` globals → stub (locals + params only).
6. **Arrays:** `nd_array_lit` only as `int[]` initializer; `nd_index` const-index only.
7. **Generic calls:** `nd_generic_call` — no codegen.
8. **Backend / kernel track:** `compiler/{mir,backend}/` scaffolding and kernel targets are not
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

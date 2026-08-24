# Next steps — path to a usable production language

**Leave-off:** `docs/LEAVE_OFF.md` (RSS ~168 MiB; seed promoted to arena fixed point).

## Honest status

Feature stack PRs (#46–#52) close much of the **codegen surface** (methods, generics
erasure, structs, traits static, globals, dynamic `int[]`, flux ranges). That is
necessary but **not sufficient**: wrong programs still compile (sema is structural),
diagnostics lack `file:line:col`, and the pure self-hosted driver is not yet a
trustworthy promote path.

## Production path (do in this order)

| Priority | Issue | Why |
|----------|-------|-----|
| **P0** | [#53](https://github.com/Team-Deepiri/diva/issues/53) type checker | Unknown idents → `const 0`; no real programs without reject-bad |
| **P0** | [#54](https://github.com/Team-Deepiri/diva/issues/54) span diagnostics | Multi-file errors useless without locations — **MVP landed** (`path:line:col:`) |
| **P0** | [#55](https://github.com/Team-Deepiri/diva/issues/55) pure driver / seed promote | Trust root without skip-flag hacks |
| **P0** | [#61](https://github.com/Team-Deepiri/diva/issues/61) negative suite | Lock failure cases so stacked PRs don't regress |
| P1 | [#56](https://github.com/Team-Deepiri/diva/issues/56) array flux (**landed**), [#58](https://github.com/Team-Deepiri/diva/issues/58) bounds traps (**landed**), [#57](https://github.com/Team-Deepiri/diva/issues/57) class methods (**landed**), [#64](https://github.com/Team-Deepiri/diva/issues/64) non-int arrays | Collection / OOP surface |
| P1 | [#62](https://github.com/Team-Deepiri/diva/issues/62) heap + growable buffer | Unblocks real [#28](https://github.com/Team-Deepiri/diva/issues/28) stdlib |
| P2 | [#60](https://github.com/Team-Deepiri/diva/issues/60) `diva watch`, [#63](https://github.com/Team-Deepiri/diva/issues/63) DWARF | Dev UX |
| P2 | [#59](https://github.com/Team-Deepiri/diva/issues/59) kernel packages | Feeds [#30](https://github.com/Team-Deepiri/diva/issues/30) systems track |

Still open from earlier track: merge the feature stack to `dev`/`main`, finish
[#24](https://github.com/Team-Deepiri/diva/issues/24) module graph/cache,
[#26](https://github.com/Team-Deepiri/diva/issues/26) monomorphization / generic classes,
[#28](https://github.com/Team-Deepiri/diva/issues/28)–[#31](https://github.com/Team-Deepiri/diva/issues/31) stdlib/SDK/FFI/runtime-research.

## Do next (immediate)

1. **Land / merge** stacked native PRs (#47–#52) onto `dev` so mainline matches tip.
2. **Implement #53** (type checker) — MVP landed: unknown idents + call arity; continue with full types.
3. Pair **#54** diagnostics + **#61** negative suite with #53 so errors are actionable and locked.

## Native codegen gaps (remaining)

See `docs/diva-roadmap.md`. Highlights still partial/seed:

1. **OOP:** class-body methods / `self` (#57 landed — value receiver); trait objects later (#27 residual).
2. **Collections:** `bool[]`/`str[]`/struct arrays (#64); array flux (#56) + bounds traps (#58) landed.
3. **Imports / modules:** full graph/cache (#24); import merge already in flight (#17).
4. **Generics:** monomorphization / generic classes (#26).
5. **IR Stage 2 / backends:** #25 status doc; kernel path #59 + #30.
6. **Runtime/stdlib:** heap (#62) then grow packages (#28).

## Footguns

| Symptom | Cause / fix |
|---------|-------------|
| ~28 GiB RSS | page-rounded string `mmap` — STRA arena |
| ~0.5 GiB AST RSS floor | 4 KiB per-`int_vec` mmap — ASTA bump arena (cap 13 slots, promote-on-grow) |
| Emit size drift | sync return + `pure_builtin_call_size` |
| `0xc3` in pure blob | NO ret on inlined builtins |
| Don’t commit | `bootstrap/*.bak-*` |
| Silent wrong results | no type checker yet — #53 |

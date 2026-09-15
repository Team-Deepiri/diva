# Diva IR status (Issue #25 / replace-llvm Stage 2)

## Acceptance checklist

| Criterion | Status | Evidence |
|-----------|--------|----------|
| Frontend does not emit backend-shaped structures directly | **Met** | Parse → AST (`ast.diva`) → `build_ir` (`ir_builder.diva`) → `codegen_x86.diva` |
| IR is dumpable and usable in tests | **Met** | `diva emit-ir`; `ir_dump.diva`; `tests/run.sh` `assert_ir_contains` |
| LLVM-specific concepts stay behind a backend boundary | **Met** | Native path is pure x86 ELF emit; no LLVM IR types in `ir.diva` |
| Package-aware incremental compilation hooks | **Partial** | Multi-file via source merge (`loader.diva`); no compiled-package cache yet (see Issue #24) |

## IR shape

Module → functions → blocks → instructions (`compiler/src/ir.diva`). Opcodes cover consts, arithmetic, compares, load/store, call, ret, br/br_cond, alloca/param, and (on feature branches) globals/array ops.

## Remaining (not blocking Stage 2 close)

- Richer type/layout metadata on every vreg (today many ops are int-shaped)
- Incremental package artifacts (#24)
- Optional LLVM backend as a *consumer* of this IR (`docs/replace-llvm.md` Stage 3+)

## Conclusion

Stage 2 (“introduce a typed, backend-neutral Diva IR”) is **substantially complete** for the native pipeline. Track package caching under #24; treat further IR typing as follow-on hardening rather than a missing stage gate.

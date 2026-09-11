# Generics specialization strategy (native pipeline)

Issue: [#26](https://github.com/Team-Deepiri/diva/issues/26). Call-site IR: [#23](https://github.com/Team-Deepiri/diva/issues/23).

## Current strategy: call-site monomorphization (infrastructure)

`name_pool.diva` + alias map + codegen hooks are landed. **IR lowering still uses type
erasure** (plain call to the template name) until alias lookup is verified in the
self-hosted seed; then lowering will emit mangled synthetic callees again.

## Previous strategy: type erasure

Erasure remains the fallback when monomorphization cannot resolve a template.

## Next strategy: monomorphization

When erasure is no longer enough:

1. Keep generic templates out of the first IR pass (or mark them).
2. For each unique `(name, type_args)` at a call site, clone the template AST,
   substitute type-parameter tokens for concrete type tokens, and lower a
   specialized function.
3. Mangle specialized names (`id_int`, …). Codegen today keys callees by **lexer
   token text**, so mangled names need tokens that slice real source text (append
   an aux name pool to the compilation unit string, or extend IR call to carry a
   string-table name).
4. Reject or diagnose conflicting specializations and arity mismatches.

## Out of scope here

- Trait bounds on type parameters ([#27](https://github.com/Team-Deepiri/diva/issues/27))
- Inference of type arguments
- AST substitution for type-dependent bodies (full monomorphization)

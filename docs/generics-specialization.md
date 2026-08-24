# Generics specialization strategy (native pipeline)

Issue: [#26](https://github.com/Team-Deepiri/diva/issues/26). Call-site IR: [#23](https://github.com/Team-Deepiri/diva/issues/23).

## Current strategy: call-site monomorphization (MVP)

1. **Declarations** — `func id[T](x: T): T` and `class Box[T] { … }` keep type
   parameters on the AST (`ast_func_generic`, `ast_class_generic`).

2. **Call sites** — `id[int](30)` lowers to a **mangled callee** `id_int` via
   `name_pool.diva` (synthetic name tokens on the IR module). The template IR
   body is cloned under the mangled symbol when first referenced.

3. **Soundness bound** — clones share the template IR body today (pass-through
   generics). Type-dependent codegen still requires AST substitution per
   specialization (next step).

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

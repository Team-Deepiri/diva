# Generics specialization strategy (native pipeline)

Issue: [#26](https://github.com/Team-Deepiri/diva/issues/26). Call-site IR: [#23](https://github.com/Team-Deepiri/diva/issues/23).

## Current strategy: type erasure

1. **Declarations** — `func id[T](x: T): T` parses type parameters into the AST
   (`ast_func_generic` / `ast_func_type_params`). IR lowering still emits **one**
   monomorphic function under the base name (`id`). Type parameters do not change
   codegen layout while every use of `T` is treated like an opaque name that does
   not affect register/memory lowering (pass-through bodies such as `return x`).

2. **Call sites** — `id[int](30)` parses as `nd_generic_call` (type-argument token
   indices kept on the AST). IR build **erases** the type-argument list and lowers
   as a plain `nd_call` to the same base name.

3. **Soundness bound** — erasure is only sound while type arguments never change
   instruction selection or ABI. Do not rely on it for type-dependent sizes,
   overloads, or distinct specializations of the same name.

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

- Generic classes / methods
- Trait bounds on type parameters ([#27](https://github.com/Team-Deepiri/diva/issues/27))
- Inference of type arguments

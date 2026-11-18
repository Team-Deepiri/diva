# Expression type inference — Issue #96 foundation

Diva performs **local, bidirectional-free inference**: each unannotated binding
and each value-producing expression is assigned exactly one concrete type from
the types already available in the program. There are no type variables and no
constraint solver. Function signatures (including extern declarations) are
always explicit and are the source of truth at call sites.

This document describes what the native sema/IR pipeline infers today and what
is deliberately deferred.

## Binding inference

An unannotated `let` / `var` takes the type of its initializer:

```diva
let n = 40                 // int
let b = true               // bool
let s = "ok"               // str
let t = text"ok"           // text
let p = Point { x: 20, y: 22 }  // struct (value semantics)
```

The inferred type is recorded in the semantic scope, so later typed
assignments and bindings are checked against it:

```diva
let b = make_bool()        // bool, from the callee signature
let chk: bool = b          // ok
let bad: int = b           // sema: type mismatch: expected int, got bool
```

## Calls and simple expressions

Types propagate through the expression forms that can produce a value:

- calls to local functions, extern functions, and extern blocks use the
  declared return type;
- generic calls (`f[T](...)`) are erased to plain calls and use the callee's
  declared return type;
- module-qualified and method calls use the registered callee return type
  (with `ptr.is_null()` yielding `bool`);
- literals, identifiers, unary operators, casts, and binary operators keep
  their existing rules (arithmetic → `int`, comparisons → `bool`, text
  concatenation → `text`, and so on);
- struct literals infer the declared struct type; an unannotated copy
  (`let q = p`) keeps the source struct's value semantics.

```diva
let s = int_to_str(41)     // extern func int_to_str(...): str
let n = identity[i64](42)  // generic signature returns the same concrete type
```

## if / match result types

An `if` in expression position infers the type shared by both branches. The
branches must agree; disagreement is a compile error.

```diva
let x = if ready { 40 } else { 2 }          // int
let y = if a { 1 } else if b { 2 } else { 3 } // nested if-expression
let t = if ok { text"yes" } else { text"no" } // text
```

Diagnostic:

```
sema: if branches have inconsistent types: then is int, else is text
```

`match` expressions already require every arm to agree and infer the shared
arm type; the result can be bound without an annotation:

```diva
let v = match color {
    Color::Red => 10,
    Color::Green => 40,
    Color::Blue => 50,
}                                          // int
```

`match` exhaustiveness and arm agreement are documented in
[`language-spec.md`](language-spec.md); this foundation keeps those rules and
exposes the inferred result to unannotated bindings.

## Not covered (deferred)

This is not Hindley–Milner inference. The following remain out of scope:

- **Unification variables / constraint solving.** No type metavariables, no
  occurs check, no generalization.
- **Polymorphic functions.** Functions cannot be generic over an inferred type;
  type parameters on generic calls must already be written at the call site.
- **Inference across function boundaries.** Parameters and return types are
  always explicit; a function body cannot influence another function's
  signature.
- **Integer/float literal defaults from constraints.** Literals are `int`
  immediately; there is no "unresolved literal defaults to i64/f64" phase.
- **Closures / lambdas.** Not part of the language surface yet.
- **Element type from `vec.get(0)` / indexing.** Indexing is `int` until
  generic containers carry element types.
- **Struct field type inference.** Structs are value layouts; field types come
  from the declaration. Struct values are not represented as a sema type tag,
  so only construction and copy inference are supported.
- **Type-driven dispatch through `if`/`match`.** Branches must already produce
  the same concrete type; there is no implicit widening or coercion.

## Tests

`tests/inference.sh` builds a driver from the bootstrap seed and runs the cases
in `tests/cases/inference/`:

| Case | Checks |
|------|--------|
| `untyped_from_call` | local + extern call return types reach untyped bindings |
| `if_expr_type` | if / else-if expressions infer `int`, `str`, and `text` |
| `match_expr_type` | match expressions infer `int`, `str`, `text`, and `bool` |
| `branch_mismatch` | disagreeing if branches are rejected with both types |
| `untyped_struct_copy` | unannotated struct copies preserve value semantics |

Run with a pinned driver with
`DIVA_PURE_DRIVER=/path/to/diva sh tests/inference.sh`.

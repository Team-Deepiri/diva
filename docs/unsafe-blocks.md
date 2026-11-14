# Unsafe blocks and raw-pointer enforcement (#94)

Diva exposes raw pointers (`&x`, `*p`, `*T`) as a low-level escape hatch. This
document covers the `unsafe { ... }` boundary that gates raw dereferences.

## Syntax

```diva
func main(): int {
    let x: int = 41;
    let p: *mut int = &x;
    let q: *int = null;

    if q.is_null() {
        return 0;
    }

    unsafe {
        *p = 42;
        return *p;
    }
}
```

- `unsafe { ... }` is a statement. It opens a normal lexical scope.
- Inside the block, `*p` (load) and `*p = v` (store) are allowed.
- Outside any `unsafe` block, both forms are compile errors:

  ```
  sema: raw pointer dereference requires an unsafe block
  ```

The checker keeps a nesting-depth counter in the sema context, so nested
`unsafe` blocks work and the restriction is restored as soon as the block
exits. Taking an address (`&x`) is not itself unsafe and does not require a
block.

## Types and literals

- `*T` and `*mut T` are accepted and are aliases at the representation level
  (both are one machine word). `mut` is parsed as an optional spelling after
  `*`; it does not change code generation today.
- `null` is a reserved literal that evaluates to `0`, suitable for any raw
  pointer type.
- `ptr.is_null()` lowers to `ptr == 0` and has type `bool`.

## Implementation map

- `compiler/src/tokens.diva`: `tk_unsafe` (76), `tk_null` (77).
- `compiler/src/lexer.diva`: keyword classification for `unsafe` and `null`.
- `compiler/src/ast.diva`: `nd_unsafe_block` (51) and `ast_unsafe_block`.
- `compiler/src/parser.diva`: `unsafe` statement, `*mut T`, `null` primary.
- `compiler/src/sema.diva`: unsafe-depth slot (index 19), deref checks for both
  loads and stores, `is_null` typing.
- `compiler/src/ir_builder.diva`: `unsafe` blocks lower as their body;
  `is_null` lowers to an equality test against zero.
- `tests/unsafe.sh` + `tests/cases/unsafe/*`: self-contained coverage.

## Deferred

- `ptr.add(n)` / `ptr.sub(n)` typed pointer arithmetic is **not** implemented
  in this slice. The current type model erases element widths (`u8`, `i32`, ...)
  to the machine word and raw pointers carry no element-size metadata, so
  element-scaled arithmetic cannot be lowered correctly yet. It should land
  after pointer element types are tracked.
- Provenance/aliasing analysis, pointer casts between pointee types, and
  non-zero-width type checking for `*mut T` are future work.
- `docs/language-spec.md` and `tests/run.sh` are intentionally untouched to
  avoid conflicts with parallel slices; this file and `tests/unsafe.sh` are the
  feature documentation and test entry point.

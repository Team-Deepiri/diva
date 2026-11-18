# Raw pointer arithmetic (#94)

Diva supports typed pointer arithmetic on raw pointer values (`*T` / `*mut T`).
It is a low-level escape hatch and is gated by `unsafe { ... }`, like raw
dereferences.

## Syntax

```diva
func main(): int {
    let x: int = 41;
    let p: *mut int = &x;
    unsafe {
        *(p.add(1)) = 5;
        return *(p.add(1)) + *(p.add(1).sub(1));
    }
}
```

- `p.add(n)` returns `p + (n * 8)`.
- `p.sub(n)` returns `p - (n * 8)`.
- `n` may be a literal or any integer expression.
- The offset is measured in elements, not bytes. All current Diva values use
  one machine word (8 bytes), so the scale factor is `8`. Pointer element
  widths are erased in the current type model; see Deferred.
- Results have raw pointer type and can be chained (`p.add(1).sub(1)`) or
  stored in a `*T` / `*mut T` local.
- Results can be dereferenced for loads and stores, including directly:
  `*(p.add(1)) = 5`.

## Safety and type rules

- `add` / `sub` are only legal inside `unsafe { ... }`. Outside, compilation
  fails with `sema: raw pointer arithmetic requires an unsafe block`.
- The receiver must be a statically known raw pointer: `&x`, a `*T` / `*mut T`
  local/param/return value, or another `add` / `sub` result. On a non-pointer
  receiver, compilation fails with
  `sema: pointer arithmetic requires a raw pointer receiver`.
- Exactly one integer argument is required. Other arities and non-integer
  offsets produce explicit sema errors.
- `null` remains the zero raw-pointer value. It is parsed as integer literal
  `0`; assignment to a pointer-typed binding is explicitly allowed.
- Taking an address (`&x`) and calling `is_null()` remain safe outside
  `unsafe`.

## Lowering

Both methods reuse existing IR; no new opcode or codegen path was added.

- Lower the receiver to a pointer-valued vreg.
- Lower the offset expression to a vreg.
- Emit `ir_mul` with a constant `8` to scale the offset.
- Emit `ir_add` for `add` or `ir_sub` for `sub` with the receiver and scaled
  offset.

`tests/ptrarith.sh` covers literal and dynamic offsets, offset stores with read
back, inverse `sub`, and the sema rejection cases.

## Deferred

- Element-size-aware scaling for narrower pointee types (`*u8`, `*i32`, ...).
  All values are currently one word, so every element is scaled by `8`.
- Provenance, aliasing, bounds, and null checks for offset pointers.
- Static pointer type inference through struct fields and opaque integer
  values (for example, heap addresses returned as `int`); those receivers are
  rejected with the non-pointer diagnostic above.
- `tests/run.sh` and `docs/language-spec.md` are intentionally untouched;
  this document and `tests/ptrarith.sh` are the feature entry points.

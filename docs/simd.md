# SIMD foundation (`vec4`, Issue #99)

Diva now has a first-class `vec4` value type: four signed machine-word lanes. The first implementation is a **scalar fallback**: lanes live in four consecutive stack slots, and operations lower to existing IR scalar instructions. This establishes the language surface and semantics without changing the backend ABI or emitting hardware SIMD.

## Type and values

```diva
let a: vec4 = vec4_splat(2);
let b: vec4 = vec4_load(1, 2, 3, 4);
let c: vec4 = a * b;
let total: int = vec4_sum(c); // 2 + 4 + 6 + 8 = 20
```

`vec4` is accepted anywhere a type annotation is parsed (local declarations, parameters, returns, fields, globals). The type checker recognizes it as a distinct type (`ir_ty_vec4`), not as an alias for `int` or `[4]int`.

A `vec4` expression/value in IR is represented by the **base vreg/slot** of four consecutive slots: lane `i` is `base + i`. A vec4 local owns four vregs and four `ir_alloca` slots. Copying a vec4 copies all four lanes, so assignments do not alias.

## Builtins

| Builtin | Signature | Meaning |
| --- | --- | --- |
| `vec4_splat(x: int): vec4` | one int | All four lanes equal `x` |
| `vec4_load(a: int, b: int, c: int, d: int): vec4` | four ints | Lanes 0..3 are `a`, `b`, `c`, `d` |
| `vec4_get(v: vec4, i: int): int` | vec4 + int | Lane `i`; constant `i` is checked at compile time |
| `vec4_sum(v: vec4): int` | vec4 | Sum of all four lanes |

`vec4_load(a, b, c, d)` is the constructor. There is no `vec4(a, b, c, d)` call syntax; `vec4` is a type, not a function. This keeps constructor resolution unambiguous with type conversions and future generic syntax.

`vec4_get` is bounds-checked:
- A literal lane outside `0..3` is a semantic error: `sema: vec4 lane index out of range (0..3)`.
- A dynamic lane uses the existing `ir_array_load(..., 4)` path, so an out-of-range index traps at runtime (exit code 1) instead of reading adjacent stack memory.

## Operators

Only lane-wise arithmetic is defined for vec4:

| Operator | Requirement | Lowering |
| --- | --- | --- |
| `+` | `vec4 + vec4` | four `ir_add` instructions |
| `-` | `vec4 - vec4` | four `ir_sub` instructions |
| `*` | `vec4 * vec4` | four `ir_mul` instructions |

Mixed arithmetic (`vec4 + int`, `int * vec4`) is rejected with `sema: vec4 arithmetic requires two vec4 operands`. Comparisons and equality on vec4 are currently rejected by the same rule; use `vec4_get` or `vec4_sum` to compare scalar results.

### Example

```diva
func main(): int {
    let a: vec4 = vec4_splat(2);
    let b: vec4 = vec4_splat(3);
    let c: vec4 = a * b;
    let s: int = vec4_sum(c);
    if s == 24 { return 42; } // 4 lanes * (2 * 3)
    return 7;
}
```

## Lowering model

No new IR opcodes or backend code are required. Each lane operation is expanded as:

```text
t0 = load base_a + 0
u0 = load base_b + 0
r0 = mul  t0, u0
store base_result + 0, r0
... repeat for lanes 1..3
```

`vec4_splat` lowers to one scalar evaluation followed by four stores. `vec4_load` lowers four scalar expressions followed by four stores. `vec4_sum` lowers four loads and three `ir_add`s from zero. `vec4_get` lowers to one `ir_array_load` with length 4, reusing the existing bounds-check/trap path.

This is intentionally a foundation: it is correct, portable, and observable through ordinary IR dumps (`mul`, `add`, `array.load`) rather than a CPU-specific intrinsic.

## Unsupported / deferred

The following are deliberately out of scope for this change and are rejected or documented rather than silently miscompiled:

- Hardware SIMD instructions and target-specific vector registers.
- Widths other than four (`vec2`, `vec8`, masks).
- Vector comparisons, equality, bitwise ops, division, and modulo.
- Vec4 function parameters and return values (call ABI still uses one slot per argument).
- Vec4 globals, struct fields, and arrays of vec4 (aggregate storage layout is not defined yet).
- Vector loads/stores from arbitrary memory; only the four builtins and lane-wise operators are supported.

## Tests

`tests/simd.sh` is a standalone regression runner. It builds a driver from `compiler/` unless `DIVA_PURE_DRIVER` is set, then checks:

- `vec4_splat(2) * vec4_splat(3)` → `vec4_sum` = 24
- `vec4_load`, `vec4_get`, `vec4_sum`, dynamic lane indexing
- lane-wise `+`, `-`, and copy assignment
- runtime out-of-range trap for a dynamic lane
- compile-time rejection of constant out-of-range lanes, mixed arithmetic, vector comparison, wrong argument types, vec4 functions, globals, fields, and arrays
- IR contains scalar `mul`/`add` and `array.load` rather than a new vector opcode

Run from the repo root:

```sh
sh tests/simd.sh
```

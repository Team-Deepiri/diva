# Forward-mode automatic differentiation (#121)

Diva has a scalar forward-mode AD foundation built on a two-word `Dual` value
and a source-to-source transform. Reverse mode and tensor AD are **not
implemented** (see [Deferred work](#deferred-work)).

## Dual values

`Dual` is a struct-like value occupying two consecutive stack slots:

```
Dual = [value, tangent]
```

It is a compiler-level value type, not a declared `struct`: no import or
declaration is needed. A dual local is declared like any other typed local:

```
var d: Dual = dual(3, 1)   // value = 3, tangent = 1 (seed derivative dx/dx)
```

Builtins (no extern declaration required):

| Builtin | Result |
| --- | --- |
| `dual(v: int, d: int): Dual` | `[v, d]` |
| `dual_val(d: Dual): int` | `d.value` |
| `dual_tan(d: Dual): int` | `d.tangent` |
| `dual_add(a: Dual, b: Dual): Dual` | `[a.v + b.v, a.d + b.d]` |
| `dual_sub(a: Dual, b: Dual): Dual` | `[a.v - b.v, a.d - b.d]` |
| `dual_mul(a: Dual, b: Dual): Dual` | `[a.v*b.v, a.d*b.v + a.v*b.d]` (product rule) |
| `dual_scale(a: Dual, k: int): Dual` | `[a.v*k, a.d*k]` |

Sema rejects direct arithmetic on `Dual` (`d + e`): use the builtins. All
builtins lower to existing IR `load`/`store`/`add`/`sub`/`mul` instructions, so
no new opcode, backend path, or C/C++ runtime is involved.

## Differentiating a function

Mark a scalar function with `#[differentiate]`:

```
#[differentiate]
func square(x: int): int {
    return x * x
}
```

Then run the compiler in `grad` mode:

```
diva grad <file.diva> <func>
```

`grad` parses the file, verifies that `<func>` is marked, and prints the
**original file followed by two generated functions** to stdout. Redirect that
output to a new `.diva` file and compile it normally:

```
diva grad square.diva square > square_ad.diva
diva build square_ad.diva square_ad.exe
```

The generated functions are:

- `<func>_dual(_ad_arg: int): int` — seeds `var x: Dual = dual(_ad_arg, 1)`,
  reruns the body in dual arithmetic, and returns `dual_tan(...)`.
- `<func>_deriv(x: int): int` — a thin wrapper around `<func>_dual`.

`diva grad` fails with `grad: function is not marked #[differentiate]: ...` if
the named function has no attribute, and with a `grad: unsupported ...`
diagnostic if the body falls outside the supported subset. No compiler flags
or environment variables are needed beyond the normal `DI_STDLIB_DIR` used for
builds. The attribute itself is accepted by the parser on any top-level item;
only `grad` gives it semantics.

### Supported body subset

- Exactly one `int` parameter and an `int` return type.
- Statements: `var` declarations with initializers, assignments to simple
  variables, and `return <expr>`.
- Expressions: integer literals, known locals/parameters, unary `-`, and
  binary `+`, `-`, `*` (including multiplication by an integer literal, which
  lowers to `dual_scale`).

Calls, branches, loops, division, comparisons, arrays, and tensors are not
transformed; `grad` reports an error rather than emitting a wrong derivative.

### Correctness examples

| Function | Point | Derivative | Exit code in `tests/ad.sh` |
| --- | --- | --- | --- |
| `x*x` | 3 | 6 | 6 |
| `3*x + 2` | any | 3 | 3 |
| `x*x*x` | 2 | 12 | 12 |

`sh tests/ad.sh` builds a driver from the bootstrap seed (or uses
`DIVA_PURE_DRIVER`), checks the builtins, the three derivatives above,
generated IR (`mul`), and the negative cases.

## Deferred work

- **Reverse-mode AD / backpropagation** is explicitly deferred. It needs a
  tape/Wengert list, adjoint slots, and control-flow-aware accumulation; none
  of that exists in this slice. The forward transform above does not claim to
  provide it.
- **Tensor/vector/matrix AD** is deferred. `dual` is scalar-only: `vec4` and
  arrays are not differentiable operands, and higher-dimensional tangent types
  are not modelled.
- Differentiation through user-defined function calls, branches, loops, and
  division is deferred; the current transform intentionally rejects them.

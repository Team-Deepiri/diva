# Trait objects and dynamic dispatch — Issue #135

`dyn Trait` values store a concrete struct together with a tag identifying
which `impl Trait for Type` block produced the value. Calling a trait method
on a `dyn` local lowers to a closed-set tag check, so dispatch works without a
general vtable ABI.

This is the Phase 1 foundation. It is deliberately a small, self-hostable
subset of trait objects.

## Syntax

```diva
trait Shape {
    func area(): int
}

struct Box {
    value: int
}

struct Circle {
    radius: int
}

impl Shape for Box {
    func area(recv: int): int {
        return recv + 1
    }
}

impl Shape for Circle {
    func area(recv: int): int {
        return recv + 2
    }
}

func main(): int {
    let b: dyn Shape = Box { value: 40 }
    let c: dyn Shape = Circle { radius: 1 }
    return b.area() + c.area() - 2
}
```

- `dyn Trait` is accepted anywhere `parse_type` is called (locals, parameters,
  fields, array elements). `dyn` is a contextual identifier, so the lexer has no
  new keyword.
- A dyn local may be initialized from a struct literal or from an existing
  concrete struct local.
- A `var` dyn local may be reassigned to a different concrete impl of the same
  trait.
- A method call on a dyn local is matched by method name and lowered to tag
  dispatch.

Trait methods use the existing receiver-first convention: the first parameter
is written as `recv: int` and receives the concrete value described below.

## Representation

A trait with `k` known impls is a closed set. Impl tags are assigned in
declaration order within the file for that trait (`0`, `1`, ...).

A dyn local occupies `1 + payload_width` consecutive stack slots:

| Slot | Contents |
|------|----------|
| `0` | impl tag |
| `1..` | concrete payload |

`payload_width` is the maximum field count over the concrete structs that
implement the trait (at least one slot, so a payloadless struct still has a
slot). Consequently, storing an impl with fewer fields leaves the unused
payload slots at their previous value.

Dyn locals reuse the struct-local metadata table with a negative trait
encoding (`-(trait_tok + 2)`). Ordinary struct lookups ignore that encoding;
`ib_lookup_dyn_trait` decodes it.

The dispatch plan is built once per file in `ib_plan_impls`:

```text
[impl_node, method_index, trait_tok, type_tok, method_tok, func_tok]
```

Entries live in the lowering context at index 22. If two impls use the same
method spelling, the concrete type token is used as the disambiguating IR
function name. Otherwise the source method token is kept. No synthetic name
tokens are required by the pure seed.

## Dispatch lowering

For `d.area()` where `d: dyn Shape`:

1. Load the tag from slot `0`.
2. Compare it with each known impl tag for `Shape`.
3. On a match, call that impl's IR function with the payload word as its
   receiver-first argument.
4. Store the result in a temporary and continue after the chain.

The impl functions are ordinary lowered functions, so the same code serves
static impl calls resolved through a concrete struct type and dynamic calls
through a dyn local.

## Limitations

The following are intentionally outside this foundation:

- **Single receiver word.** Dispatch passes the first payload slot as `recv`,
  not the whole struct. Impl methods that need additional fields are not
  supported by dynamic dispatch yet.
- **Simple receivers only.** Dyn method interception recognizes a direct
  identifier receiver such as `d.method()`. Calls on arbitrary expressions are
  not intercepted.
- **Closed-set dispatch, no vtable ABI.** The set of impls is fixed at
  compile time from the file AST. There is no runtime method table, no
  cross-package impl discovery, and no uniform calling convention.
- **No trait-object parameters or returns.** Dyn values currently live in
  locals (and can be initialized from concrete locals). Passing or returning a
  dyn value is not implemented.
- **No object safety checking.** A trait method with an unsupported signature
  is not rejected at the trait declaration; lowering may simply fail or
  produce the single-word receiver behavior above.
- **No `dyn` casts or downcasts.** Converting a dyn value back to a concrete
  type is not implemented.
- **One impl per (trait, concrete type) with a given method name.** Duplicate
  method spellings are disambiguated by the concrete type token, so the same
  struct also implementing two different traits with the same method name is
  not supported yet.

## Tests

`tests/traits.sh` builds a driver from the bootstrap seed (or uses
`DIVA_PURE_DRIVER`) and runs the cases in `tests/cases/traits/`:

| Case | Checks | Exit |
|------|--------|------|
| `dyn_two_impls` | two impls, two dyn locals, tag dispatch | 42 |
| `dyn_from_local` | dyn initialized from concrete struct locals | 32 |
| `dyn_reassign` | `var` dyn local reassigned to another impl | 42 |

Run from the repo root:

```sh
sh tests/traits.sh
```

With a pinned driver:

```sh
DIVA_PURE_DRIVER=/path/to/diva sh tests/traits.sh
```

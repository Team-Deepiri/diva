# Diva Language Spec

This document describes the current implemented surface of `Diva`.

## Overview

`Diva` is a compiled language with:

- `.diva` source files
- `diva` as the CLI command (install also provides `di` → `diva`)
- explicit function signatures
- `var` bindings with optional type annotations
- class-based data and methods
- arrays, ranges, imports, and straightforward control flow

## Design Direction

The current language direction is:

- readable brace-based syntax
- explicit types where they add clarity
- lightweight syntax for common code
- no required parentheses around `if` and `while` conditions
- simple lowering into LLVM IR and a native executable path

## File Extension

All `Diva` source files use the `.diva` extension.

Examples:

- `main.diva`
- `math.diva`
- `game_loop.diva`

## Program Structure

A minimal program looks like this:

```diva
extern func print_int(x: int): void

func main(): int {
    var x = 10
    print_int(x)
    return 0
}
```

## Keywords

- `func`
- `extern`
- `class`
- `enum`
- `var`
- `if`
- `else`
- `while`
- `flux`
- `in`
- `return`
- `true`
- `false`
- `match`
- `package`
- `import`

## Types

Built-in types:

- `int`
- `bool`
- `str`
- `void`

Other supported type forms:

- arrays like `int[]`
- user-defined class names like `Point`
- user-defined enum names like `Color` (see [Enums](#enums))

## Declarations

### Functions

```diva
func add(a: int, b: int): int {
    return a + b
}
```

### External Functions

```diva
extern func print_str(x: str): void
```

Hosted runtime hooks currently exposed through `extern func` include:

- `print_int(x: int): void`
- `print_str(x: str): void`
- `print_hex(x: int): void`
- `write(fd: int, x: str): int`
- `exit(status: int): void`
- `abort(): void`

### Classes

Classes contain `var` fields and `func` methods:

```diva
class Counter {
    var value :: int

    func bump(amount: int): int {
        self.value = self.value + amount
        return self.value
    }
}
```

Current implementation note:

- class fields lower to struct-like fields
- methods lower to functions with an explicit receiver
- method calls use `obj.method(...)`

### Enums

An `enum` is a tagged union: a named type with an ordered set of variants.
Unit variants carry no data; payload variants carry one value of a declared
type. Variants are constructed by their bare name (`None`), or called with a
single argument (`Some(x)`), in the surrounding scope — no `Type::Variant`
qualifier is required.

```diva
enum Color { Red, Green, Blue }

enum Option[T] {
    None,
    Some(T)
}

var c: Color = Red
var n: Option[int] = Some(0)
```

Variants can also be constructed with their enum qualifier: `Enum::Variant`
for a unit variant, `Enum::Variant(payload)` for a payload variant. The
qualifier must name a declared enum, and the variant must belong to it.

```diva
var c: Color = Color::Blue
var n: Option[int] = Option::Some(0)
```

Supported on enum values (Issue #93, Phase 1):

- declaration and construction of unit and single-payload variants, bare or
  qualified (`Red`, `Color::Red`, `Some(0)`, `Option::Some(0)`)
- assignment, reassignment, and enum-typed parameters/returns
- equality against a variant, e.g. `o == None`, `c == Green`
- the `.tag` field, which reads the variant's declaration index as an `int`
  (`Red = 0`, `Green = 1`, …)
- the `.data` field, which reads the payload of a local enum binding (`0` for
  unit-only enums)
- generic parameter syntax `[T]` / `[T, E]`; parameters are parsed but not
  enforced in Phase 1

Runtime model: an enum binding in a local scope occupies two slots when its
enum declares a payload variant — the tag slot, then the payload slot — and a
single slot otherwise. Storing a variant writes the tag, plus the payload
when the variant has one; storing a unit variant resets the payload slot to
`0`.

Phase 1 limitations: outside a local binding an enum value is just its `int`
tag, so payloads are **not carried across a function boundary** — a parameter
or a return value carries the tag only, and the standard library's
`option_unwrap` still returns `0`. Equality compares tags. `match` expressions
can match variants (see [Match Expressions](#match-expressions)); `?`,
`map`/`and_then`, and niche optimization are not implemented yet.

The standard library ships ready-made `Option[T]` and `Result[T, E]` enums with
accessor helpers; see `stdlib/std/option.diva` and `stdlib/std/result.diva`.

## Variables

Use `var` for local bindings.

Type annotations are optional and use `::`.

Semicolons are optional statement and declaration terminators. They are still accepted for compatibility, but the recommended style is to leave them out.

```diva
var total = 0
var nums :: int[] = [1, 2, 3]
var point :: Point = Point { x: 3, y: 4 }
```

## Statements

Supported statements:

- variable declarations
- assignments
- field assignments
- index assignments
- expression statements
- `if` / `else`
- `while`
- `flux`
- `return`

## Expressions

Supported expressions:

- integer literals
- boolean literals
- string literals
- identifiers
- function calls
- method calls
- grouped expressions with `()`
- arithmetic: `+`, `-`, `*`, `/`
- comparisons: `==`, `!=`, `<`, `>`, `<=`, `>=`
- logic: `&`, `|`, `!`
- field access: `user.score`
- array indexing: `numbers[i]`
- object literals: `Point { x: 1, y: 2 }`
- array literals: `[1, 2, 3]`
- ranges: `0..5`
- `match` expressions

## Match Expressions

`match` is an expression: it picks an arm by pattern and yields that arm's
value. The scrutinee is any expression; each arm is a pattern, an optional
guard, and an arm expression.

```diva
var label = match status {
    0 => "idle",
    1 => "running",
    _ => "unknown",
}
```

Arms are tried top to bottom. The first arm whose pattern matches **and**
whose guard holds wins. A guard is written `if <expr>` after the pattern and
may read names the pattern binds:

```diva
var size = match n {
    x if x > 100 => "big",
    _ => "small",
}
```

### Patterns

| Pattern | Matches |
| --- | --- |
| `42`, `-1` | an `int` literal |
| `true`, `false` | a `bool` literal |
| `"text"` | a `str` literal |
| `_` | anything (the wildcard) |
| `x` | anything, binding the whole value to `x` |
| `Red` | a unit variant of the scrutinee's enum |
| `Color::Red` | the same, qualified with the enum name |
| `Opt::Some(x)` | a payload variant, binding its payload to `x` |

A bare name is a unit-variant pattern when the name is a declared variant of
the scrutinee's enum, and a whole-value binding otherwise. A name that names a
variant of a *different* enum is rejected as an unknown pattern.

### Exhaustiveness and reachability

The compiler rejects a `match` that can miss a case:

- over an enum, every variant must be covered — the error lists the missing
  variant names
- over a `bool`, both `true` and `false` must be covered
- over an `int` or `str`, a wildcard arm is required (there are too many
  values to enumerate)

An arm that can never run — one that follows an arm covering everything, or
one whose pattern is already covered by an earlier unguarded arm — is
rejected as an unreachable pattern.

All arms must agree on a type: a `match` has the type of its arms, and
mismatched arm types are rejected.

### Phase 1 limitations

- one level of destructuring: a payload variant binds its payload, but nested
  patterns inside a payload are not supported yet
- a payload can only be bound when the scrutinee is a local enum binding;
  Phase 1 does not carry enum payloads through expressions, so
  `match Opt::None { Opt::Some(x) => x }` is rejected
- a `match` on an enum needs a variant pattern, not a whole-value binding
- no `|` alternatives in a single pattern, and no range patterns

## Control Flow

Conditions do not require extra parentheses.

### If / Else

```diva
if score > 10 & ready {
    return 1
} else {
    return 0
}
```

### While

`while` supports an update clause:

```diva
while i < 5 => i = i + 1 {
    total = total + i
}
```

## Iteration

`flux` iterates over ranges and arrays.

```diva
flux value in 0..5 {
    print_int(value)
}
```

```diva
flux value in nums {
    print_int(value)
}
```

## Arrays

Array literals and indexing are supported today.

```diva
var values :: int[] = [3, 4, 5]
var second = values[1]
```

Array element assignment is also supported:

```diva
values[1] = 9
```

## Imports

Files may optionally declare a package at the top:

```diva
package imports_demo
```

Top-level imports can use relative `.diva` file paths:

```diva
import "math.diva"
```

Package manifests can also declare dependencies with `dep.<name> = "../path"` and import them by package name:

```diva
import "pkg/math_lib"
```

`pkg/<name>` resolves to that dependency package's manifest entry file.

Imports are resolved as a file graph and merged into a single program for semantic analysis and code generation.

## Example

```diva
import "math.diva"

extern func print_int(x: int): void

func main(): int {
    var nums :: int[] = [1, 2, 3]

    flux value in nums {
        print_int(value)
    }

    print_int(twice(21))
    return 0
}
```

## Implemented Today

- `func` and `extern func`
- explicit generic functions with call-site type arguments like `identity[int](7)`
- class declarations with methods
- `enum` declarations with unit and single-payload variants, bare-name and
  qualified (`Color::Red`) construction, `==` against variants, and `.tag` /
  `.data` reads (Issue #93 Phase 1); see `stdlib/std/option.diva` /
  `stdlib/std/result.diva`, `tests/enums.sh`, and `tests/optres.sh`
- **`match` expressions (Issue #91 Phase 1):** int/bool/str literal
  patterns, wildcard, whole-value binding, enum variant patterns (bare and
  qualified) with payload binding, guard clauses, exhaustiveness and
  reachability checking, and a typed match value; see `tests/match.sh` and
  `tests/cases/match/`
- `trait` declarations and `impl Trait for Type` validation
- **Native sema (Issue #53):** scoped symbol table (globals, funcs, locals); unknown identifiers rejected; call/generic-call arity; assign/return/binop type checks for `int`/`bool`/`str`; object-literal and method-call name lookup. Diagnostics use `path:line:col:` (Issue #54). See `tests/cases/sema/` and `tests/run-sema.sh`.
- `var` bindings with optional `::` type annotations
- `if` / `else`
- `while condition => update`
- `flux item in iterable`
- primitive types: `int`, `bool`, `str`, `void`
- arrays as `int[]` (fixed-size stack arrays)
- slices as `[T]` (heap-backed, `s.len`, `s[i]`, `s[a:b]`, bounds-checked)
- arithmetic, comparisons, and boolean logic
- field access and field mutation
- array indexing and mutation
- object literals
- optional top-level `package` declarations
- package manifests via `package.diva` with `kind = "app" | "lib" | "kernel"`
- relative file imports
- shipped standard library imports like `std/math.diva` and `std/range.diva`
- utility modules like `std/io.diva`, `std/int.diva`, and `std/assert.diva`

## Not Implemented Yet

- full assign/return/binop type checking (beyond names/arity)
- generic classes
- generic methods
- trait bounds on generic parameters
- trait-based dynamic dispatch
- `@field` sugar for receiver access
- custom packed-value runtime as the default representation
- NaN boxing
- sub-byte addressing experiments
- enum payloads carried across function boundaries (Phase 1 carries the payload
  only in local enum bindings; elsewhere an enum value is its tag)
- `?`, `map`/`and_then`, and niche optimization
- nested patterns inside an enum payload, `|` alternatives, and range patterns

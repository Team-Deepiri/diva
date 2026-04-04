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
- `var`
- `if`
- `else`
- `while`
- `flux`
- `in`
- `return`
- `true`
- `false`
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
- `trait` declarations and `impl Trait for Type` validation
- `var` bindings with optional `::` type annotations
- `if` / `else`
- `while condition => update`
- `flux item in iterable`
- primitive types: `int`, `bool`, `str`, `void`
- arrays as `int[]`
- arithmetic, comparisons, and boolean logic
- field access and field mutation
- array indexing and mutation
- object literals
- optional top-level `package` declarations
- package manifests via `diva.mod` with `kind = "app" | "lib" | "kernel"`
- relative file imports
- shipped standard library imports like `std/math.diva` and `std/range.diva`
- utility modules like `std/io.diva`, `std/int.diva`, and `std/assert.diva`

## Not Implemented Yet

- generic classes
- generic methods
- trait bounds on generic parameters
- trait-based dynamic dispatch
- `@field` sugar for receiver access
- custom packed-value runtime as the default representation
- NaN boxing
- sub-byte addressing experiments

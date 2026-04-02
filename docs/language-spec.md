# Di Language Spec

This document describes the current implemented surface of `Di`.

## Overview

`Di` is a compiled language with:

- `.di` source files
- `di` as the CLI command
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

All `Di` source files use the `.di` extension.

Examples:

- `main.di`
- `math.di`
- `game_loop.di`

## Program Structure

A minimal program looks like this:

```di
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

```di
func add(a: int, b: int): int {
    return a + b
}
```

### External Functions

```di
extern func print_str(x: str): void
```

### Classes

Classes contain `var` fields and `func` methods:

```di
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

```di
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

```di
if score > 10 & ready {
    return 1
} else {
    return 0
}
```

### While

`while` supports an update clause:

```di
while i < 5 => i = i + 1 {
    total = total + i
}
```

## Iteration

`flux` iterates over ranges and arrays.

```di
flux value in 0..5 {
    print_int(value)
}
```

```di
flux value in nums {
    print_int(value)
}
```

## Arrays

Array literals and indexing are supported today.

```di
var values :: int[] = [3, 4, 5]
var second = values[1]
```

Array element assignment is also supported:

```di
values[1] = 9
```

## Imports

Top-level imports use relative `.di` file paths:

```di
import "math.di"
```

Imports are resolved before parsing into a single compilation unit.

## Example

```di
import "math.di"

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
- class declarations with methods
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
- relative file imports

## Not Implemented Yet

- generics
- traits
- packages
- `@field` sugar for receiver access
- custom packed-value runtime as the default representation
- NaN boxing
- sub-byte addressing experiments

# Di Syntax Guide

`Di` is a compiled programming language with `.di` source files.

This guide is the quick-reference version of the language docs. For the fuller reference, see `docs/language-spec.md`.

## Hello World Shape

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
- `package`
- `import`

## Types

- `int`
- `bool`
- `str`
- `void`
- arrays like `int[]`
- class names like `Point`

## Variables

```di
var total = 0
var nums :: int[] = [1, 2, 3]
var point :: Point = Point { x: 3, y: 4 }
```

## Functions

```di
func add(a: int, b: int): int {
    return a + b
}
```

External declarations:

```di
extern func print_str(x: str): void
```

Semicolons are optional. The compiler still accepts them, but the preferred style is to omit them.

## Control Flow

Conditions do not require extra parentheses.

```di
if score > 10 & ready {
    return 1
} else {
    return 0
}
```

`while` supports an update clause:

```di
while i < 5 => i = i + 1 {
    total = total + i
}
```

## Iteration

`flux` iterates ranges and arrays:

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

## Classes

```di
class Counter {
    var value :: int

    func bump(amount: int): int {
        self.value = self.value + amount
        return self.value
    }
}
```

## Expressions

Supported forms include:

- integer, boolean, and string literals
- identifiers
- function and method calls
- grouped expressions with `()`
- arithmetic: `+`, `-`, `*`, `/`
- comparisons: `==`, `!=`, `<`, `>`, `<=`, `>=`
- boolean logic: `&`, `|`, `!`
- field access: `user.score`
- array indexing: `numbers[i]`
- object literals: `Point { x: 1, y: 2 }`
- array literals: `[1, 2, 3]`
- ranges: `0..5`

## Imports

Optional package declaration:

```di
package imports_demo
```

```di
import "math.di"
```

Imports are resolved as a file graph before semantic analysis.

## Current Limits

Not implemented yet:

- generics
- traits

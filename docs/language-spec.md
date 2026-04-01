# Diri Language Spec

This document defines the current designed surface of `diri`.

## Design Goals

- readable systems-language syntax
- explicit types
- simple compilation pipeline
- LLVM backend from the start

## Syntax Style

`diri` aims for:

- readable brace-based blocks
- explicit types where declarations matter
- low punctuation noise inside control flow
- familiar function syntax without becoming C-like clutter

## File Extension

All `diri` source files use the `.di` extension.

Examples:

- `main.di`
- `math.di`
- `game_loop.di`

## Core Syntax

```diri
extern func print_int(x: int): void;

func main(): int {
    let x: int = 10;
    print_int(x);
    return 0;
}
```

## Keywords

- `func`
- `extern`
- `struct`
- `let`
- `if`
- `else`
- `while`
- `return`
- `true`
- `false`

## Primitive Types

- `int`
- `bool`
- `str`
- `void`

Arrays are written as `int[]`. User-defined struct names are used directly as types.

## Expression Design

Expressions stay readable and mostly left-to-right:

- function calls use `name(arg1, arg2)`
- control-flow conditions do not require extra parentheses
- field access uses `.`
- array indexing uses `[]`
- struct literals use named fields

Supported today:

- integer literals
- boolean literals
- string literals
- identifiers
- function calls
- grouped expressions with `()`
- arithmetic: `+`, `-`, `*`, `/`
- comparisons: `==`, `!=`, `<`, `>`, `<=`, `>=`
- field access: `user.score`
- array indexing: `numbers[i]`
- struct literals: `Point { x: 1, y: 2 }`
- array literals: `[1, 2, 3]`

## Statements

Supported today:

- `let` declarations
- assignments
- field assignments
- expression statements
- `if` / `else`
- `while`
- `return`
- nested block scopes with shadowing

## Examples

### Variables And Assignment

```diri
func main(): int {
    let value: int = 10;
    value = value + 4;
    return value;
}
```

### Branching

```diri
func max(a: int, b: int): int {
    if a >= b {
        return a;
    } else {
        return b;
    }
}
```

### Looping

```diri
extern func print_int(x: int): void;

func main(): int {
    let i: int = 0;
    let total: int = 0;

    while i < 5 {
        total = total + i;
        i = i + 1;
    }

    print_int(total);
    return 0;
}
```

### Structs

```diri
struct Point {
    x: int,
    y: int,
}

func main(): int {
    let point: Point = Point { x: 3, y: 4 };
    return point.x + point.y;
}
```

### Arrays

```diri
func main(): int {
    let values: int[] = [3, 4, 5];
    return values[1];
}
```

## Current Implemented Features

- function declarations with `func`
- external function declarations with `extern func`
- struct declarations
- local bindings with `let`
- assignment and field assignment
- primitive types: `int`, `bool`, `str`, `void`
- integer, boolean, and string literals
- function calls
- arithmetic and comparisons
- field access
- struct literals
- `int[]` array literals and indexing
- `if`
- `while`
- `return`
- block scoping with shadowing

## Creative But Readable Direction

The language direction is:

- concise keywords instead of symbolic tricks
- no forced parentheses around `if` and `while` conditions
- explicit field names in struct literals
- a small `.di` source format that feels lightweight to type
- tooling that treats `.di` as the default project entry format

This keeps `diri` creative in feel without making code visually noisy or cryptic.

## Near-Term Design Direction

The next syntax areas to expand are:

- richer array support beyond `int[]`
- modules and imports
- methods or namespaced APIs
- a larger stdlib surface

## Not Implemented Yet

- generics
- traits
- packages
- custom packed-value runtime as the default representation
- kernel or ISR features

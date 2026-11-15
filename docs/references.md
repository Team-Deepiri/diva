# References (`&T` / `&mut T`)

Status: Phase 1 (Issue #90). References are a distinct type, share the raw
pointer representation, and support read-through. Borrow checking is **not**
implemented yet.

## Syntax

Reference types are prefix types:

```diva
let r: &int = &x;          // shared reference
let m: &mut int = &mut x;  // mutable reference
```

Reference expressions mirror the type syntax and reuse the existing
`ir_addr_of` raw-pointer machinery:

```diva
&x        // shared reference to x
&mut x    // mutable reference to x
```

For the current slice, `&T` and `&mut T` are syntactically distinct but share
one machine-word representation. Mutability is not enforced.

## Reading through a reference

A reference used in expression position auto-dereferences:

```diva
func main(): int {
    let x: int = 42;
    let r: &int = &x;
    return r;          // reads x -> 42
}
```

Explicit dereference also works and is useful for assignment through a
reference:

```diva
func inc(r: &mut int): int {
    *r = *r + 1;
    return *r;
}
```

References can be passed and returned as ordinary parameters (single word):

```diva
func read_ref(r: &int): int {
    return r;
}
```

## Structs through references

Field reads through a reference to a struct local are supported when the
pointee type is statically known at the reference binding:

```diva
struct Point {
    x: int
    y: int
}

func main(): int {
    var p = Point { x: 10, y: 32 };
    let r: &Point = &p;
    return r.x + r.y;   // 42
}
```

## Deferred (not in this slice)

- Borrow checking: aliasing, lifetime, and mutation rules are not enforced.
- `&mut T` is not checked; a `&mut T` and `&T` alias freely.
- Field **writes** through a reference (`r.x = v`) are not supported.
- Method calls through a reference (receiver auto-deref for `self`) are not
  supported; methods still take the struct by value.
- References to temporaries outside a local binding and reference returns with
  lifetime analysis.
- Nullability, pointer arithmetic, and unsafe boundaries for references.

These are follow-up work; the Phase 1 goal is type syntax, reference creation,
and read-through.

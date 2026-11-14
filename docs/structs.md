# Value-type structs — Issue #87

Structs are stack-resident value types. A struct declaration registers a name
and an ordered list of fields; a struct value occupies one machine word per
field in declaration order.

## Declaration

```diva
struct Point {
    var x: int
    var y: int
}
```

`struct` shares the class declaration parser (`parse_class_decl`), so an
unqualified field (`x: int`) is also accepted. Fields are currently plain
machine words (`int`, `bool`, `str`, pointers). Field types are not reordered
and there is no padding or header word.

## Construction and access

```diva
let p: Point = Point { x: 20, y: 22 }
let sum = p.x + p.y
p.x = 40
```

- A struct literal `Point { x: 1, y: 2 }` writes each named field into the
  value's slots. Missing fields keep their previous value (or the stack slot's
  value on first construction).
- The type annotation may be omitted when the initializer is a struct literal:
  `var p = Point { x: 1, y: 2 }`.
- `p.field` reads a field and `p.field = value` writes a `var` field.
- Struct locals are lowered to consecutive stack slots; field index resolution
  uses `ib_struct_field_index` / `ib_type_struct_width` over the file AST.

## Copy semantics

Structs are values, not references:

```diva
let p: Point = Point { x: 5, y: 7 }
let q: Point = p      // copies x and y into q's own slots
q.x = 30              // p.x is still 5
```

The same copy happens on struct assignment (`q = p`). Both paths lower to a
load/store of every field (`lower_struct_store_value`).

## Deferred

The following are intentionally out of scope for this foundation:

- **Nested struct fields.** A field whose type is another struct is not
  flattened; `outer.inner.x` is not lowered yet.
- **Immutable (`let`) fields.** The class/struct parser only records `var`
  fields, so assignment to a `let` field cannot be rejected yet.
- **Struct parameters and return values.** Passing a struct to a function or
  returning one by value is not implemented; structs currently live in locals
  and struct-element arrays.

## Tests

`tests/structs.sh` builds a driver from the bootstrap seed and runs the cases
in `tests/cases/structs/`:

| Case | Checks |
|------|--------|
| `construct_read` | literal construction + field reads |
| `field_write` | mutable field write |
| `copy_isolation` | mutating the copy leaves the source unchanged |
| `copy_source_isolation` | mutating the source leaves the copy unchanged |
| `reassign_copy` | `q = p` copies fields |
| `infer_literal` | type inferred from a struct literal |

Run with a pinned driver with
`DIVA_PURE_DRIVER=/path/to/diva sh tests/structs.sh`.

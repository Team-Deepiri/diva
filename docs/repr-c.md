# `#[repr(...)]` attribute parsing (#95)

Diva structs are flat value types laid out as consecutive machine words. This
document covers the attribute syntax used to declare an intended ABI layout
alongside a top-level item.

## Syntax

An attribute is `#[name]` or `#[name(args)]`. Zero or more attributes may
precede a top-level item (before an optional `pub`):

```diva
#[repr(C)]
struct Point {
    var x: int
    var y: int
}

#[repr(i32)]
enum Color { Red, Green, Blue }

#[doc("flat layout")]
#[repr(C)]
struct Pair { var a: int, var b: int }
```

Attributes may also follow `pub` (`pub #[repr(C)] struct S { ... }`). Unknown
attribute names and their argument lists are parsed and ignored, so forward
compatible spellings such as `#[doc("...")]` do not break compilation.

## Accepted `repr` layouts

- `C` — flat C-compatible layout marker. Diva structs are already flat word
  layout values, so this is currently a **no-op**.
- `i8`, `i16`, `i32`, `i64`, `u8`, `u16`, `u32`, `u64`, `isize`, `usize` —
  intended enum tag integer types. Accepted and validated syntactically;
  documented here as the target representation.

`repr` requires exactly one layout argument. Malformed attributes produce a
located `parse error` and fail the build:

```
#[repr]              -> repr expects a layout name (C or i8/...)
#[repr()]            -> repr expects a layout name (C or i8/...)
#[repr(Q)]           -> unknown repr layout (expected C or i8/...)
#[repr(C, i32)]      -> repr accepts a single layout argument
#repr(C)             -> parse error: expected LBRACK
#[123]               -> expected attribute name after '#['
#[repr(C             -> parse error: expected RPAREN
```

## Current semantics

Attributes are **parsed and validated but not yet stored** on AST nodes. They
have no effect on layout or code generation: `#[repr(C)]` is a documentation
marker for the existing flat struct layout, and `#[repr(i32)]` is accepted on
an enum with no change to the current tag lowering. Items with no attributes
parse exactly as before.

## Implementation map

- `compiler/src/tokens.diva`: `tk_hash` (78), `tk_name` entry `HASH`.
- `compiler/src/lexer.diva`: `#` (ASCII 35) in `lex_punct_kind`; `[` / `]`
  already lexed as `tk_lbrack` / `tk_rbrack`.
- `compiler/src/parser.diva`: `p_parse_attributes`, `p_repr_args`,
  `p_repr_layout_ok`, `p_skip_attr_args`, `p_attr_error`; attribute pass in
  `parse_top_level` before item dispatch.
- `tests/reprc.sh` + `tests/cases/reprc/*`: self-contained coverage (positive
  struct/enum/multiple-attribute cases, back-compat case, malformed cases).

## Deferred

- Attaching attributes to AST nodes and exposing them to sema / IR / codegen.
- Enforcing layout compatibility (for example rejecting `#[repr(i32)]` on a
  struct or `#[repr(C)]` on an enum) and emitting the chosen integer tag type.
- Additional attributes (`#[export_name]`, `#[align(N)]`, `#[packed]`) and
  attribute parsing inside item bodies (fields, variants, functions).
- `docs/language-spec.md`, `tests/run.sh`, and `.github/workflows/ci.yml` are
  intentionally untouched to avoid conflicts with parallel slices; this file
  and `tests/reprc.sh` are the feature documentation and test entry point.

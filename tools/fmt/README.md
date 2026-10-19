# `diva fmt` — canonical Diva source formatter

`tools/fmt/diva_fmt.diva` is a self-contained native tool that rewrites a
`.diva` source file into a single canonical layout. It is a **lexical**
formatter: it re-serialises the token stream with a fixed whitespace/indentation
policy and **never changes the program's meaning**. Proven invariant: for every
`.diva` file in the repository the compiler's own lexer (`diva lex`) emits an
identical token stream before and after formatting.

## Usage

```sh
# format a file to stdout
diva_fmt path/to/file.diva

# read from stdin (use "-" or pass no argument)
diva_fmt - < file.diva
cat file.diva | diva_fmt
```

The formatter writes the result to **stdout**; it does not edit files in place
(redirect to a file, or let your editor pipe it).

### Building it

```sh
DI_STDLIB_DIR=$PWD/stdlib DIVA_NO_EXTERNAL=1 \
  DI_RUNTIME_O=$PWD/bootstrap/runtime-linux-amd64.o \
  build/diva-compiler-pure-elf build tools/fmt/diva_fmt.diva /tmp/diva_fmt
```

## Canonical rules

- **Indentation** — 4 spaces per block level; tabs are converted to spaces.
  Every line is re-indented from scratch.
- **Blocks** — a block header (`if`, `while`, `else`, `func`, `class`,
  `struct`, `trait`, `impl`, `flux`) keeps its `{` on the **same line** as the
  header; the **body is broken onto its own lines**; the closing `}` goes on its
  own line. A block written inline, e.g. `if a >= b { return a }`, is expanded.
- **`else`** — `}` `else` `{` is kept on one line as `} else {`.
- **One statement per line** — the formatter never merges two lines; combined
  with brace-driven breaking this yields one statement per line.
- **Spacing** — a single space after every `,`; a single space after `:` in
  type/field/struct annotations and slices; binary operators are surrounded by
  single spaces; no space before `,` `;` `)` `]`.
- **Blank lines** — runs of blank lines collapse to **one**. Exactly one blank
  line is enforced **before** a top-level declaration keyword
  (`func`/`class`/`struct`/`trait`/`impl`), without detaching a leading doc
  comment. No leading/trailing blank lines are emitted.
- **Line endings** — CRLF is normalised to LF.
- **Trailing newline** — the file always ends in exactly one `\n`.
- **Trailing whitespace** — removed.
- **Comments** — preserved verbatim and in their original position, and
  re-indented like the surrounding code (own-line and trailing comments both).

## Test

```sh
sh tools/fmt/diva_fmt_test.sh
```

The test builds the formatter with the pure-ELF native driver, then over a
corpus (`examples/*.diva`, `stdlib/std/{sort,kv}.diva`, `tests/cases/kv/*.diva`)
and a curated fixture (`tools/fmt/fixtures/messy.diva`) asserts:

1. **idempotency** — `fmt(fmt(x)) == fmt(x)`, and
2. **compile preservation** — the formatted text still lexes, parses and
   type-checks (`diva check` on a throwaway package).

Files that cannot be checked standalone are counted as *skipped* (none in the
default corpus). Output ends with a machine-readable line:

```
[fmt] total=55 failed=0 skipped=0
```

Broader local sweeps used during development (not part of the committed test):

- format **all 288** `.diva` files in the tree twice → idempotent, and
- `diva lex` token streams identical before/after for **all 288** files.

## Limitations

- **Comments in expressions / blank-line placement inside a statement** keep the
  author's line breaks; the formatter re-indents but does not reflow continued
  lines onto one line.
- **Slices** render with a space after the colon: `a[1:3]` becomes `a[1: 3]`.
  This is cosmetic and token-identical.
- **Struct literals** (`Name { a: 1, b: 2 }`) are kept inline; brace blocks are
  detected lexically, so a literal is not expanded onto separate lines.
- **Multiple statements on one physical line** at the same level are not split
  onto separate lines (the formatter does not add line breaks where the source
  had none, except around block braces).
- The formatter assumes its input **lexes**. It is a token re-serialiser, not a
  parser; malformed sources are passed through as best it can and are not
  repaired.

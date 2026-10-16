# diva LSP servers

This directory hosts two minimal [Language Server Protocol](https://microsoft.github.io/language-server-protocol/)
servers written in pure Diva, both running on the pure-ELF native driver and
speaking JSON-RPC 2.0 over stdio:

- **`diva_lang_lsp`** (#104) — language-aware: diagnostics, document symbols,
  hover and completion over the Diva grammar itself.
- **`diva_text_lsp`** (#190) — text-aware: Unicode-correct position metrics,
  grapheme-snapped ranges, folding and selection.

# diva_lang_lsp

A **language-aware** LSP server (`diva_lang_lsp.diva`, issue #104). Where the
text server answers "what is at this position", the language server answers
"what does this Diva file contain" — it lexes each document on the fly
(strings, `//` line comments, identifiers, brackets, top-level declarations)
and serves diagnostics, an outline, documentation hovers and completions.

## What it implements

| LSP method | Behaviour |
| --- | --- |
| `initialize` / `initialized` | advertises `textDocumentSync: 1` (full sync), `hoverProvider`, `documentSymbolProvider`, `completionProvider` |
| `shutdown` / `exit` | clean termination |
| `textDocument/didOpen` / `didChange` | registers/replaces a document by URI and publishes fresh diagnostics |
| `textDocument/didClose` | drops the document |
| `textDocument/publishDiagnostics` | unbalanced brackets (stray / mismatched / unclosed), unterminated strings, and `func`/`class`/`struct`/`trait` declarations without a name |
| `textDocument/documentSymbol` | top-level `func` / `class` / `struct` / `trait` / `import` declarations with full declaration ranges (kinds 12 / 5 / 23 / 11 / 2) |
| `textDocument/hover` | markdown docs for keywords and stdlib modules from built-in `name\|blurb` tables, plus import paths inside `import "std/..."` strings |
| `textDocument/completion` | keywords (kind 14), stdlib modules (9), document import paths (9) and declared names — `func` (3), `class` (7), `struct` (22), `trait` (8), `var`/`let` (6), `const` (21) |

Documents are stored as **`str`** end to end (the pure driver's `text_from_str`
copies into one fixed 4096-byte page with no bounds check, which would corrupt
documents above ~4 KB), in the same fixed **four-slot** URI table as the text
server — a fifth document overwrites slot 0.

## Build

From the repository root:

```sh
DI_STDLIB_DIR=stdlib DIVA_NO_EXTERNAL=1 \
  DI_RUNTIME_O=bootstrap/runtime-linux-amd64.o \
  build/diva-compiler-pure-elf build tools/lsp/diva_lang_lsp.diva /tmp/diva_lang_lsp
```

## Run

Same contract as the text server: no raw `read(2)` builtin, so the whole
session is read with one `read_file` — prefer a path argument
(`diva_lang_lsp /path/to/session.txt`), otherwise `/dev/stdin` via a regular
file redirect. Framing is scanned over the raw `str` buffer, so the session may
be large; no message-body size limit applies (unlike the text server).

## Test

```sh
sh tools/lsp/diva_lang_lsp_test.sh
```

The script builds the server and drives a scripted session that opens five
intentionally-broken fixtures (`tools/lsp/fixtures/`) and every
`examples/*.diva` file, then asserts the exact diagnostics messages, the
document-symbol outline (top-level only — no nested methods), hover contents
and completion items. The full-repo diagnostic sweep doubles as a
false-positive check: valid code must produce `"diagnostics":[]`.

## Design notes / limitations

- **Single-pass lexer, no AST.** Diagnostics come from one state machine
  (code / line comment / string). Diva has no block comments, so unterminated
  comments cannot occur; strings may span lines and are only flagged at EOF.
  After a mismatched close (or an allocation failure) the bracket stack stops
  reporting, to avoid cascading noise; at most 50 diagnostics per document.
- **Declaration detection is a line-start heuristic.** `func`/`class`/
  `struct`/`trait` are only treated as declarations at the start of a line
  (an `extern` prefix counts), with the name probed across newlines and
  comments. Validated against the whole repo corpus (examples, stdlib,
  compiler sources) with zero false positives.
- **Columns are codepoints, not UTF-16 units.** Exact for ASCII/BMP text;
  astral characters (surrogate pairs in UTF-16) would need conversion.
- **JSON is extracted with a hand-rolled field scanner**, not a parser —
  sufficient for the flat, known request shapes an LSP client sends.
- **Codegen note:** the current native codegen miscompiles functions with
  seven or more parameters (pass1/pass2 size mismatch), so server helpers are
  kept to at most six.

# diva_text_lsp

A minimal, **text-aware** [Language Server Protocol](https://microsoft.github.io/language-server-protocol/)
server written in pure Diva (`diva_text_lsp.diva`). It runs on the pure-ELF
native driver and speaks JSON-RPC 2.0 over stdio. Its focus is not completion or
semantic analysis but **Unicode-correct position reporting**: every position it
answers with is snapped to grapheme-cluster boundaries and accompanied by byte,
codepoint, display-width and grapheme metrics.

## What it implements

| LSP method | Behaviour |
| --- | --- |
| `initialize` / `initialized` | advertises `textDocumentSync: 1` (full sync), `hoverProvider`, `documentSymbolProvider`, `foldingRangeProvider`, `selectionRangeProvider` |
| `shutdown` / `exit` | clean termination |
| `textDocument/didOpen` | registers a document by URI |
| `textDocument/didChange` | full-document replacement (sync kind 1) |
| `textDocument/hover` | "hover metrics": `byteOffset`, `codepointIndex`, `displayWidth`, `graphemeIndex` and the grapheme cluster at the requested position, plus the grapheme-snapped range |
| `textDocument/foldingRange` | blank-line-separated blocks |
| `textDocument/documentSymbol` | `func` / `var` declarations (`kind` 12 / 13) |
| `textDocument/selectionRange` | single-grained selection snapped to grapheme boundaries |
| `diva/graphemeSelection` | custom: word/grapheme-aware selection range |

Documents are stored in a fixed **four-slot** table keyed by URI (the language
has no arrays today); a fifth document overwrites slot 0.

## Build

From the repository root:

```sh
DI_STDLIB_DIR=stdlib DIVA_NO_EXTERNAL=1 \
  DI_RUNTIME_O=bootstrap/runtime-linux-amd64.o \
  build/diva-compiler-pure-elf build tools/lsp/diva_text_lsp.diva /tmp/diva_text_lsp
```

## Run

The pure-ELF driver has no raw `read(2)` builtin, so the server reads its whole
input with a single `read_file`:

- prefer an input **path** argument: `diva_text_lsp /path/to/session.txt`
- otherwise it reads `/dev/stdin`. Feed it from a **regular file** (redirect),
  which is read in full, rather than a pipe, which may short-read.

Framing is scanned over the raw `str` buffer, so the session as a whole may be
large; only each individual message body is materialised as a `text`.

```sh
diva_text_lsp /tmp/session.txt
# or
diva_text_lsp < /tmp/session.txt
```

Frames are standard LSP framing: `Content-Length: N\r\n\r\n` followed by `N`
bytes of JSON.

## Test

```sh
sh tools/lsp/diva_text_lsp_test.sh
```

The script builds the server, drives a scripted session (initialize, didOpen,
hover, folding, selection, documentSymbol, didChange, shutdown, exit) and asserts
the exact grapheme-accurate fields.

## Design notes / limitations

- **JSON is not parsed by a real parser.** A hand-rolled field extractor locates
  `"key"` and decodes the string value (`\n \t \r \" \\ \/` and `\uXXXX`,
  including surrogate pairs). This covers the flat, known request shapes an LSP
  client sends and keeps the server pure-Diva.
- **Character offsets are counted in codepoints**, not UTF-16 code units. They
  coincide for the Basic Multilingual Plane; astral characters (e.g. emoji) would
  need a surrogate-pair-aware conversion, which is out of scope here.
- **A single request must fit one `text_from_str` block (~4 KB).** The pure
  `text_from_str` copies into a fresh 4096-byte page, so an individual message
  body larger than ~4072 bytes (e.g. a `didChange` carrying a multi-KB document)
  is rejected by the framing loop. Keeping whole documents larger than that would
  require parsing on the raw `str` and building field values with
  `text_from_byte_vec`.
- `text_from_byte_vec` skips NUL bytes, so an embedded NUL in a document body is
  not preserved.
- Related native-`text` design: `docs/text-native-direction.md`.

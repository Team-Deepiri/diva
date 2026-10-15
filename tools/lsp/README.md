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

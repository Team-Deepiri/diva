# Diva Text-Native Direction

**Diva is a language where plain text is a native value.**

This is a second strategic direction, alongside
[`strategic-direction.md`](strategic-direction.md). That document positions Diva
as an AI-native *systems* language — tensors, MLIR, GPU kernels, ONNX. This one
covers the half that comes first and that everything else depends on: **text
itself**.

Natural language is not a string type with library functions bolted on. It is the
data. Every model consumes it, every output is it, and the tools around a model
are text processing. A language that wants to be good at AI has to be genuinely
good at text — at the value-representation level, not the library level.

---

## The honest starting point

Diva today cannot claim this. The gaps are not subtle:

| Gap | Evidence |
|-----|----------|
| `str` is a NUL-terminated C pointer | `extern func str_len(s: str): int` — `stdlib/std/host.diva:9` |
| Length is O(n), interior NUL truncates | same |
| ASCII-only character handling | `str_to_upper_byte` — `stdlib/std/str.diva:161`; `is_letter` — `stdlib/std/char.diva:21` |
| No regex | `stdlib/std/pattern.diva` has exactly one pattern fn: `glob_match` |
| No string interpolation | formatting is `str_builder_new` / `append` / `to_str` — `compiler/src/codegen_x86.diva:44` |
| No multi-line literals | prose is a pile of `\n` escapes |
| No Unicode at all | no normalization, no graphemes, no codepoint iteration |
| **No stdin input whatsoever** | no `read_line` / `getline` / `stdin` anywhere in `stdlib/` |

That last row is the one to sit with. A Diva program can print text and cannot
read it. For a language whose thesis is natural language, that is the most
embarrassing possible gap, and it is a day of work.

None of this is a criticism of the compiler. The self-hosting bootstrap, the pure
ELF backend, the DWARF output, the package system — those are hard and they are
done. But they were built with a `str` borrowed from C, and that shortcut is now
the binding constraint on what the language can claim to be.

---

## The thesis

Text becomes a length-carrying, Unicode-correct, immutably-shared value type that
the compiler understands — and the language gets first-class syntax for it.

```diva
var msg = "user $name has $count items"          // interpolation
var doc = """Dear $name,

Your order shipped on ${order.date}."""          // multi-line, dedented

flux w in doc.words() { }                        // Unicode word boundaries
var re = r"\d{4}-\d{2}-\d{2}"                    // regex literal, compiled at build time
if re.matches(line) { }

var ids = tokenizer.encode(doc)                  // byte-level BPE, exact round trip
var hits = index.search(question, 5)             // hits cite byte spans in the source
```

Every line above is either zero-ceremony or one call. That is the whole argument.

### Why the compiler has to care

Text is not a library concern. Three things force this into the compiler:

1. **Length.** A substring, a slice, and a tokenizer span all need O(1) length
   and a view into the parent. `str` cannot express any of them.
2. **Interpolation.** `"$name"` is a lexing and lowering decision. Handled in the
   stdlib it is a builder dance; handled at compile time it is a constant blob.
3. **Diagnostics.** Compiler errors point at columns. In a text-native language,
   the error span for `"café"` must be codepoint-based or every editor puts the
   caret in the wrong place.

---

## How this relates to the systems roadmap

The two directions are sequential and they meet in the middle.

```
   THIS DIRECTION                       systems roadmap (Phase 1–4)
   ────────────────                     ──────────────────────────
   text value type            ─┐
   Unicode correctness         │
   regex / tokenize            ├──▶   tensor<T, shape>   (#112)
   embedding index             │       tensor library    (#130)
   prompt types                │       ONNX import       (#122)
   text AI runtime        ────┘       inference runtime  (#134)
```

Phases 1–4 here are self-contained compiler and stdlib work — they need nothing
from the tensor side. Phase 5 consumes it: embeddings are `tensor<f32>`, model
execution is ONNX. **Phase 5 is blocked on the tensor issues, not the other way
round.** That ordering is deliberate — it means this direction can start
immediately and produce value long before the MLIR investment lands.

The general-purpose language maturity work in the systems roadmap (type system,
ownership, enums, modules, FFI, concurrency) is a **prerequisite**, not a
parallel track. Several issues here depend on it:

- Enums and sum types (#85) make `Role` in prompt types a real enum.
- Ownership and move semantics (#88) are what make passing a document free.
- `Result`/`Option` (#93) and pattern matching (#91) are the error model for
  regex and text I/O.
- FFI (#95) is required for terminal raw mode and model execution.
- Concurrency (#98) applies to BPE training and index build.

---

## Phase 1 — Text is a value (#145–#153)

The representation change. `text` is `(ptr, len, cap)` — a fat pointer over a
heap buffer, NUL-free, O(1) length.

- [ ] #145 `text` value type, embedded NUL safe
- [ ] #146 length-carrying literals, lexer measures, interning by `(bytes, len)`
- [ ] #147 comparison and ordering operators
- [ ] #148 slicing `text[a:b]` — zero-alloc views
- [ ] #149 compile-time string interpolation `"${expr}"` / `$name`
- [ ] #150 multi-line `"""..."""` and raw `r"..."` literals
- [ ] #151 full escape sequences (`\n \r \t \0 \xNN \u{...}`)
- [ ] #152 `+` concatenation, zero-copy move semantics
- [ ] #153 `str` ↔ `text` bridge, with a visible count of what remains

#149 is the highest-visibility, lowest-effort win in the whole direction. #145 is
the highest-leverage. Everything else is cheaper after both land.

## Phase 2 — Unicode native (#154–#163)

The phase that makes the language correct for the world. Not "correct for
English" — correct.

- [ ] #154 UTF-8 validation at every boundary, `unsafe` escape hatch
- [ ] #155 codepoint iteration — `flux cp in text`
- [ ] #156 grapheme clusters — combining marks, ZWJ emoji, regional indicators
- [ ] #157 byte ↔ codepoint ↔ grapheme index mapping
- [ ] #158 full case mapping and case folding (`"straße"` → `"STRASSE"`)
- [ ] #159 Unicode property tables, generated from the UCD
- [ ] #160 normalization NFC / NFD / NFKC / NFKD
- [ ] #161 collation — stable keys, explicit strength
- [ ] #162 display width, so terminal tables line up
- [ ] #163 codepoint encode/decode and exact escape round-trips

#159 is the enabling data issue — #156, #158, #160, #161 all read from its
tables. Generate once, share, and record the Unicode version.

## Phase 3 — The plain-text surface (#164–#171)

Where ergonomics stop being a compiler concern.

- [ ] #164 `read_line()` — the ability to ask a user a question
- [ ] #165 `read_text` / `write_text` — whole-file I/O
- [ ] #166 line, paragraph, and sentence iteration
- [ ] #167 Unicode word boundaries — `words()`
- [ ] #168 interpolation-native formatting; migrate the compiler's own hot paths
- [ ] #169 line-oriented editing and diff
- [ ] #170 interactive terminal input — readline, history, REPL
- [ ] #171 streaming builders — kill quadratic concatenation

#168 is the acceptance test for Phase 1: if the compiler's own string handling in
`codegen_x86.diva` and `diag.diva` can be written with interpolation, the feature
is real.

## Phase 4 — Patterns (#172–#177)

- [ ] #172 regex engine in pure Diva — backtracking matcher
- [ ] #173 regex literals `r"..."`, first-class `Regex`, compiled at build time
- [ ] #174 classes, anchors, groups, alternation, `\p{L}` property classes
- [ ] #175 lazy quantifiers, backreferences, lookahead/lookbehind
- [ ] #176 `match` / `find_iter` / `replace_all` / `split`, codepoint spans
- [ ] #177 diagnostics and resource limits

Precedent exists: `glob_match` is already a backtracking matcher in pure Diva.
The real constraint is that Diva has no closures, so backtracking continuations
must be an explicit node-index stack.

## Phase 5 — The natural-language layer (#178–#184)

The payoff. Consumes the tensor work from the systems roadmap.

- [ ] #178 `token` / `vocab` — tokens that carry a span back into the source
- [ ] #179 byte-level BPE — train, encode, decode
- [ ] #180 embedding store and nearest-neighbor search, with span-carrying hits
- [ ] #181 prompt and chat-message types with safe template rendering
- [ ] #182 text AI model runtime — LLM inference in Diva, no Python
- [ ] #183 chunking and RAG over local documents, with citations
- [ ] #184 similarity, diff, and quality metrics

Byte-level BPE specifically: it cannot produce OOV, so nothing is ever lost, and
round-trip is exact by construction. That property is what everything downstream
depends on.

## Phase 6 — Conformance and proof (#185–#190)

Claims without measurements are marketing.

- [ ] #185 Unicode conformance suite — official test data, version-pinned
- [ ] #186 golden corpus and property tests (idempotence, round-trip, no data loss)
- [ ] #187 fuzz targets — malformed UTF-8, pathological regex
- [ ] #188 benchmark suite vs Rust and C
- [ ] #189 `diva text` — inspect and transform text from the CLI
- [ ] #190 text-aware LSP — hover metrics, grapheme-aware selection, folding

#188 has one rule: publish a result where Diva loses, or it is not a benchmark
suite.

---

## What this direction is not

- **Not a replacement for the systems roadmap.** That one is about tensors,
  kernels, and heterogeneous compute. This one is about the data those things
  consume. Both are needed; they are not alternatives.
- **Not "add more stdlib functions."** Every issue here traces back to a
  representation change in the compiler. A `std/str.diva` with a thousand
  functions on top of a NUL-terminated `str` would deliver none of this.
- **Not a plan to skip Unicode.** Half the world's writing systems are not ASCII.
  A text-native language that mangles them is not text-native.
- **Not NLP-as-a-science project.** Sentiment, parsing, and linguistic theory are
  out of scope. The scope is the machinery every NLP system sits on: correct
  text representation, patterns, tokenization, retrieval, and generation.

---

## Sequencing

```
Phase 1  ████████████  start now, no dependencies outside the compiler
Phase 2  ████████████  depends on Phase 1
Phase 3  ██████████    depends on Phase 1; runs parallel to Phase 2
Phase 4  ████████      depends on Phase 1, 2 (index spaces), 3 (lines)
Phase 5  ██████        depends on Phase 1–4 + tensor work (#112, #130, #122, #134)
Phase 6  ████          test infra lands alongside each phase, not after
```

Phase 6 is not a final phase. The conformance suite and the fuzz targets should
be built *with* the feature they cover — a Unicode claim asserted before #185
exists is not a claim, it is a hope.

## Tracking

46 issues, #145–#190, in the `Text-Native Natural Language Direction` milestone.

See also:

- [`strategic-direction.md`](strategic-direction.md) — AI-native systems language
  roadmap (tensors, MLIR, GPU, ONNX)
- [`language-spec.md`](language-spec.md) — current implemented surface
- [`syntax-guide.md`](syntax-guide.md) — quick syntax reference
- [`diva-roadmap.md`](diva-roadmap.md) — AST/IR/codegen coverage matrix
- [`NEXT_STEPS.md`](NEXT_STEPS.md) — current implementation queue
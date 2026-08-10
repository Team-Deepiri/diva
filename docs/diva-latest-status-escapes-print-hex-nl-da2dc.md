---
name: Escapes and print_hex NL
overview: Implement minimal C-style string escapes in `tok_str_value` so `"\n"` etc. decode correctly at compile time, then append a trailing newline to the pure-ELF `print_hex` builtin to match common line-oriented I/O. Simplify examples/tests that currently work around the old behavior.
todos:
  - id: tok-escapes
    content: Extend tok_str_value in tokens.diva for \n \t \r (optional \0); add tiny 1-char helpers; update comment
    status: pending
  - id: print-hex-nl
    content: Append newline syscall to emit_pure_print_hex + update id 19 size in codegen_x86.diva
    status: pending
  - id: examples-tests
    content: Revert multiline LF hacks in branching/utils_demo; fix fmt/conv fallout; update run.sh goldens; add minimal escape/println assertion
    status: pending
  - id: merge-rebuild-verify
    content: merge_compiler_package.py; rebuild diva-stage2; DIVA_TEST_FAST=1 tests/run.sh (+ optional verify-pure-compiler-build.sh)
    status: pending
isProject: false
---

# C-style escapes + pure `print_hex` newline

## Context

- String decoding lives in `[compiler/src/tokens.diva](diri-lang/compiler/src/tokens.diva)` (`tok_str_value`). Today only `\"` and `\\` are special; `\n` stays as two characters (documented in `[compiler/src/main.diva](diri-lang/compiler/src/main.diva)` near `newline_str()` / `lf.txt`).
- Pure `print_hex` is emitted as a fixed blob in `[compiler/src/pure_elf_builtins.diva](diri-lang/compiler/src/pure_elf_builtins.diva)` (`emit_pure_print_hex`, size **96** bytes). `[compiler/src/codegen_x86.diva](diri-lang/compiler/src/codegen_x86.diva)` maps `pure_builtin_call_size_hi_misc` **id 19** to **96**. There is **no** trailing newline after the hex digits (unlike `print_int`, which now ends with a `write` of `\n`).

## 1) C-style escapes in `tok_str_value`

**File:** `[compiler/src/tokens.diva](diri-lang/compiler/src/tokens.diva)`

- Extend the `if c == 92` branch: after handling `n2 == 34` (`\"`) and `n2 == 92` (`\\`), add explicit cases for at least:
  - `**n` (110)** → ASCII **10** (LF)
  - `**t` (116)** → ASCII **9** (TAB)
  - `**r` (114)** → ASCII **13** (CR)
- Optional but low-cost: `**\0`** (backslash + `0`) → NUL **if** you want parity with common C subsets (only if second char is `0`).
- **Implementation detail (no new host ABI):** append a **one-character** `str` to the builder. Prefer tiny private helpers in the same file that return a length-1 string, e.g. multiline literal for LF (same pattern as `[examples/branching.diva](diri-lang/examples/branching.diva)` today), and a literal **tab character** inside quotes for TAB (lexer already allows any byte except `"` inside strings). CR can be a multiline string that contains a single carriage return (editor-safe) or the same `lf.txt` pattern used elsewhere—pick one approach and stay consistent.
- Update the stale comment at **L181** (“other backslash sequences stay as two literal chars”) to describe the new set.

**Follow-on cleanups** (same PR, so behavior is exercised):

- `[stdlib/std/fmt.diva](diri-lang/stdlib/std/fmt.diva)`: `println` / `eprintln` can keep `str_builder_append(b, "\n")`—after this change it becomes a **real** newline instead of backslash+`n`.
- `[stdlib/std/conv.diva](diri-lang/stdlib/std/conv.diva)`: `char_to_str` branches that append `"\n"` / `"\t"` will behave correctly for programs compiled with the new compiler.
- Examples that used **multiline** strings purely for LF: revert to escaped form where readability improves—`[examples/branching.diva](diri-lang/examples/branching.diva)`, `[examples/utils_demo.diva](diri-lang/examples/utils_demo.diva)` (`print_bool` strings, and the extra `print_str` inserted only to separate `print_hex` from the next `print_int`).

**Regression coverage:** add or extend a small compiler/lexer test or a `tests/run.sh` assertion on a tiny program that prints `"\n"` length / `println("hi")` output (`hi` + one LF). If no dedicated unit harness exists, a one-line `assert_output_equals` on a temp example under `examples/` or `tests/cases/` is enough.

## 2) Trailing newline for pure `print_hex`

**Files:**

- `[compiler/src/pure_elf_builtins.diva](diri-lang/compiler/src/pure_elf_builtins.diva)`: append the same **stdout newline syscall** tail used for `print_int` (reuse the **objcopy-from-.s** workflow via `[scripts/gen-pure-host-builtin-bytes.sh](diri-lang/scripts/gen-pure-host-builtin-bytes.sh)` if you extract the hex blob into a scratch `.s` file, or hand-append the known byte sequence and bump `emit_pure_print_hex` return size).
- `[compiler/src/codegen_x86.diva](diri-lang/compiler/src/codegen_x86.diva)`: update `pure_builtin_call_size_hi_misc` for **id == 19** to the **new** byte length (must match emitted push count exactly).

**Downstream:**

- `[tests/run.sh](diri-lang/tests/run.sh)`: adjust `assert_output_equals` for `[examples/systems_hosted.diva](diri-lang/examples/systems_hosted.diva)` and `[examples/utils_demo.diva](diri-lang/examples/utils_demo.diva)` if the observable stdout changes (extra newline after hex; possibly final line ending).
- Remove the **temporary** `print_str("↵")` spacer in `utils_demo` after `print_hex` if hex now ends with `\n`.

## 3) Bootstrap / self-host hygiene

- Run `[scripts/merge_compiler_package.py](diri-lang/scripts/merge_compiler_package.py)` so `[compiler/src/_bootstrap_merged.diva](diri-lang/compiler/src/_bootstrap_merged.diva)` matches edited sources.
- Rebuild the cc-linked driver (`[scripts/legacy/build-compiler-cc-link.sh](diri-lang/scripts/legacy/build-compiler-cc-link.sh)` → `build/diva-stage2`) before `DIVA_TEST_FAST=1 sh tests/run.sh` and optionally `sh scripts/verify-pure-compiler-build.sh`.

## Risk / scope note

- Changing `tok_str_value` affects **all** string literals in every program the compiler compiles (stdlib, compiler, tests). Expect a few goldens or snapshots that assumed literal `\n` two-character strings to flip—fix forward by updating expectations or source that relied on the old quirk.


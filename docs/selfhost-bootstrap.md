# Self-host bootstrap notes

This document tracks what the hosted Di runtime exposes so a Di-implemented compiler can exist without growing the language surface first.

## Bootstrap driver (`compiler/`)

The repository includes a small Di app (`compiler/src/main.diva`) that builds to a hosted executable behaving like `di` by forwarding CLI arguments to the **seed** compiler binary. Set `DI_BOOTSTRAP` to an absolute path (e.g. `bootstrap/di-linux-amd64` in the repo). The driver uses `host_getenv` and `host_system`; the runtime implements them via `getenv` / `system` in LLVM IR (`runtime/runtime.ll`), compiled with `clang` at install when available, or copied from `bootstrap/runtime-linux-amd64.o` when `NO_CLANG=1`.

This is a **practical bridge** so `PATH` can point at a Di-built `di` while the toolchain remains the checked-in bootstrap binary. A full self-host replaces this with lexer, parser, sema, IR, and codegen entirely in Di.

## Process and file I/O

Import `std/host.diva`. The hosted runtime (LLVM IR in `runtime/runtime.ll`) provides:

- `host_argc` / `host_argv` — populated by the process entry before `di_user_main` runs.
- `file_size` — returns the size in bytes of a regular file, or `-1` on failure.
- `read_file` — reads an entire file into a nul-terminated `str` (heap-allocated by the runtime). On failure returns `""`.

## String scanning

`str` values are nul-terminated byte strings in the host. For lexer-style access without a `byte` type in Di:

- `str_len(s)` — length in bytes, excluding the nul terminator.
- `str_byte(s, i)` — unsigned byte value at `i`, or `-1` if out of range.

## Entry point naming

The user still writes `func main(): int`. The compiler lowers this to the symbol `di_user_main`; the hosted executable entry calls `di_runtime_set_argv` and then `di_user_main()`.

Do not declare a top-level function named `di_user_main` in Di sources; it is reserved for codegen.

## ABI contract and no-clang mode

Stable hosted/link conventions (`di_user_main`, runtime symbol names) and the `NO_CLANG=1` install contract are documented in [`docs/no-clang-contract.md`](no-clang-contract.md).

## Dynamic data structures

Import `std/vec.diva`. Handles are opaque `int` ids into a small runtime slot table in the hosted runtime.

**Int vector**

- `int_vec_new(): int` — returns `0` on allocation failure.
- `int_vec_push(handle, value): int` — new length, or `-1` on error.
- `int_vec_len`, `int_vec_get` — `-1` on bad handle or out-of-range index for `get`.
- `int_vec_free` — releases storage; handle must not be used again.

**String builder**

- `str_builder_new(): int` — `0` on failure.
- `str_builder_append` — appends UTF-8 bytes from a `str` (nul-terminated host string); no separate `char` type required.
- `str_builder_len` — byte length excluding the nul terminator of the accumulated buffer.
- `str_builder_to_str` — returns a fresh heap `str` copy; builder remains valid.
- `str_builder_free` — frees the builder buffer.

Together with `read_file` and `str_byte`, a lexer can push token kinds / offsets into parallel `int_vec`s or build lexeme text in a `str_builder`.

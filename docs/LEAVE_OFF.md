# Leave-off: pure-only driver and large compiler `check`

**Paused until:** 2026-08-07 (about three months from 2026-05-07).

## What was wrong

The pure ELF runtime used a fixed **64 KiB** `mmap` for `int_vec_new` and `str_builder_new` (see `compiler/src/pure_elf_builtins.diva`). `pure_int_vec_push` and `pure_str_builder_append` do not grow buffers; they fail silently when full.

That capped token streams at roughly **~8k int slots** (~2.7k lexer tokens) and string builders at **~64 KiB** of payload. Merging the full `compiler/` package (~285 KiB of source) overflowed both paths, so `diva-native-exe check compiler/` failed with parse errors near EOF while hosted `diva-stage2-from-cc` succeeded.

## What changed

In `compiler/src/pure_elf_builtins.diva`, the initial `mmap` size and header caps were raised from **64 KiB to 4 MiB** (`0x400000`) for:

- `emit_pure_int_vec_new_*` (qword cap `(0x400000 - 24) / 8`)
- `emit_pure_str_builder_new_*` (byte cap `0x400000 - 24`)

Inline blob sizes for pure builtin ids **9** and **14** remain **96** bytes (unchanged instruction length).

## What you must do after pulling

`emit_pure_*` is compiled into **`build/diva-stage2-from-cc`** via the cc-link path. Rebuilding only `/tmp/diva-native-exe` with an old stage2 does **not** pick up new emitter bytes.

1. Refresh the hosted compiler (slow):

   ```sh
   ASM_TIMEOUT_SECS=7200 ./scripts/legacy/build-compiler-cc-link.sh build/diva-stage2-from-cc
   ```

2. Rebuild the pure driver:

   ```sh
   DIVA_SKIP_NATIVE_EXTERN_CHECK=1 ./build/diva-stage2-from-cc build compiler/ /tmp/diva-native-exe
   ```

3. Sanity checks:

   ```sh
   /tmp/diva-native-exe lex /path/to/merged_compiler.diva | wc -c   # should be ~hundreds of KB, not ~25k
   ROOT_DIR="$PWD" DI_STDLIB_DIR="$PWD/stdlib" /tmp/diva-native-exe check compiler/
   ```

Related notes: `docs/pure-only-driver.md`, `compiler/res/pure_int_vec_push.s`, `compiler/res/pure_str_builder_append.s`.

## Follow-ups (later)

- Implement real **reallocation** in `pure_int_vec_push` / str-builder append so growth is not capped at 4 MiB.
- Re-run `DIVA_PURE_FULL=1 ./scripts/verify-pure-only-driver.sh` after the driver refresh.

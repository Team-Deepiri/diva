# Bootstrap seed compiler

`diva-linux-amd64` is the **Linux x86-64** reference compiler binary. It is the **trust root** for the bootstrap: the in-tree Diva compiler package (`compiler/`) is built with this seed, then used in tests to rebuild itself (see `docs/selfhost-bootstrap.md`).

## What is *not* in this repository

- **No C or C++ compiler sources** — all language and compiler logic you edit is **`.diva`**. Verification: `scripts/verify-no-c-sources.sh`.
- The seed is a **prebuilt executable**, not source in another programming language.

## What you still need from the host (not “Diva source”)

- **Shell** — `scripts/install.sh`, `tests/run.sh`, etc.
- **LLVM IR** — `runtime/runtime.ll` defines the hosted runtime (I/O, `int_vec`, linking). At install, either:
  - `clang -c runtime/runtime.ll` → `runtime.o`, or
  - copy **`bootstrap/runtime-linux-amd64.o`** (no compiler needed; use `NO_CLANG=1`).
- **System linker** — user programs are linked with the system **`cc`** as a linker driver (no C sources from this repo).

## Refreshing the seed binary

This tree cannot run `scripts/build-bootstrap-seed.sh` to compile a seed — it exits with instructions on purpose.

Options:

1. **Historical path:** check out an older commit that still contained the legacy C compiler, build the seed with an external C toolchain, commit `bootstrap/diva-linux-amd64`, return to Diva-only sources.
2. **Future path:** when the Diva-only compiler can fully replace the seed for `build`/`run`, promote the self-built executable (same OS/ABI) to become the new `bootstrap/diva-linux-amd64`.

## Runtime / stdlib resolution

Set `DI_STDLIB_DIR` and `DI_RUNTIME_O` after install, or rely on defaults under `~/.local/share/diva/` (see `scripts/install.sh`).

## Source extension

Canonical sources use **`.diva`**. The CLI may still accept **`.di`** where the seed implements it.

## Manifest filename

Packages use **`package.diva`**.

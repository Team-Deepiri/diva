# Bootstrap seed compiler

`diva-linux-amd64` is the **Linux x86-64** reference compiler binary. It is the **trust root** for the bootstrap: the in-tree Diva compiler package (`compiler/`) is built with this seed; `tests/run.sh` then requires pure rebuild convergence and `scripts/verify-pure-compiler-build.sh` (see repo `README.md`).

## `write_elf_chunk` and promoting the seed

The driver materializes pure ELF output using `write_elf_chunk` (hosted `di_runtime_write_elf_chunk` in `compiler/res/legacy/runtime_extra.s`, pure builtin id 32 in `pure_elf_builtins.diva`).

**Issue #55 closed:** the pinned seed matches tip codegen. Install / verify / self-host scripts **do not** default `DIVA_SKIP_NATIVE_EXTERN_CHECK=1`. Set that env only for a one-shot rebuild if a temporary pin lags new externs.

Pure ELF full pipeline (`ir`/`asm`) is gated by `DIVA_PURE_FULL=1 ./scripts/verify-pure-only-driver.sh` — see `docs/pure-only-driver.md`.

## What is *not* in this repository

- **No C or C++ compiler sources** — all language and compiler logic you edit is **`.diva`**. Verification: `scripts/verify-no-c-sources.sh`.
- The seed is a **prebuilt executable**, not source in another programming language.

## What you still need from the host (not “Diva source”)

- **Shell** — `scripts/install.sh`, `tests/run.sh`, etc.
- **LLVM IR** — `runtime/runtime.ll` defines the hosted runtime (I/O, `int_vec`, linking). At install, either:
  - `clang -c runtime/runtime.ll` → `runtime.o`, or
  - copy **`bootstrap/runtime-linux-amd64.o`** (no compiler needed; use `NO_CLANG=1`).
- **System linker (optional)** — the native driver links with **`cc` + `runtime.o`** only when **`DIVA_ALLOW_HOSTED_LINK=1`** and a readable runtime object is configured; otherwise user programs use the pure in-process ELF path (no C sources from this repo).

## Refreshing the seed binary

This tree cannot run `scripts/build-bootstrap-seed.sh` to compile a seed — it exits with instructions on purpose.

Options:

1. **Historical path:** check out an older commit that still contained the legacy C compiler, build the seed with an external C toolchain, commit `bootstrap/diva-linux-amd64`, return to Diva-only sources.
2. **Self-hosted promotion:** build the in-tree compiler with the current seed, then copy the produced executable over the seed (same Linux x86-64 ABI):

   ```sh
   cd /path/to/diri-lang
   DI_STDLIB_DIR="$PWD/stdlib" DI_RUNTIME_O="$PWD/bootstrap/runtime-linux-amd64.o" \
     ./scripts/promote-bootstrap-seed.sh
   ```

   The script backs up the old binary to `bootstrap/diva-linux-amd64.bak-<timestamp>`, replaces `bootstrap/diva-linux-amd64`, and runs a **second** `diva build compiler` to verify the new seed. That second step runs the Diva-authored driver (typically **pure ELF** unless you export **`DIVA_ALLOW_HOSTED_LINK=1`** and **`DI_RUNTIME_O`**). Run the script on a normal machine (not a restricted sandbox). To only copy without verify: `PROMOTE_SKIP_VERIFY=1 ./scripts/promote-bootstrap-seed.sh`.

   After a successful promotion, commit the updated `bootstrap/diva-linux-amd64` so clones pick up the new trust root. For the **pure-only** driver check list (no libexec overlay, `DIVA_PURE_DRIVER`, second-stage promote without skip), see `docs/pure-only-driver.md`.

## Why the seed is not “auto-replaced” in git

The repository only updates `bootstrap/diva-linux-amd64` when someone **commits** a new ELF produced by a successful promote (or the historical C bootstrap path). CI and pull requests do not silently overwrite this binary: if `diva-linux-amd64 build compiler` or `./scripts/promote-bootstrap-seed.sh` prints the same `[di:error] …` line thousands of times, the **current seed cannot parse or lower the merged compiler**—fix the in-tree `.diva` sources until a single `build compiler` run finishes, then run promote and commit the new seed so everyone picks it up.

## Runtime / stdlib resolution

Set `DI_STDLIB_DIR` and `DI_RUNTIME_O` after install, or rely on defaults under `~/.local/share/diva/` (see `scripts/install.sh`).

For **`diva build` / `diva run`**: the driver uses **pure in-process ELF** by default (no `cc` / `runtime.o`). **`DIVA_NO_EXTERNAL=1`** still forces that path. Hosted linking (**`cc`** + **`compiler/res/native_crt.s`** + **`DI_RUNTIME_O`** / `ROOT_DIR/bootstrap/runtime-linux-amd64.o`) runs only when **`DIVA_ALLOW_HOSTED_LINK=1`** (and a readable runtime object is available). The native **`diva` driver** does not delegate normal commands to the seed.

## Source extension

Canonical sources use **`.diva`**. The CLI may still accept **`.di`** where the seed implements it.

## Manifest filename

Packages use **`package.diva`**.

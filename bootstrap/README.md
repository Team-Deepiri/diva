# Bootstrap artifacts

This directory holds the **Linux x86-64** reference `di` compiler binary and a precompiled **runtime object** produced from `runtime/runtime.ll`.

- `di-linux-amd64` — copied to `~/.local/bin/di` by `scripts/install.sh`.
- `runtime-linux-amd64.o` — prebuilt object for installs without `clang`, or when `NO_CLANG=1` (see [`docs/no-clang-contract.md`](../docs/no-clang-contract.md)). When `runtime/runtime.ll` changes, run [`scripts/rebuild-bootstrap.sh`](../scripts/rebuild-bootstrap.sh) and commit the updated `.o`.

The canonical hosted runtime description is LLVM IR at `runtime/runtime.ll`. There are **no** C sources under `runtime/`.

The compiler emits a native glue translation for user programs into `build/` (ignored by git); that output is not checked into this tree.

To refresh `bootstrap/di-linux-amd64`, use a trusted self-host or release build of `di` and copy the binary here (there is no C reference compiler in this repository).

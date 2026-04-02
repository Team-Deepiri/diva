# Bootstrap artifacts

This directory holds the **Linux x86-64** reference `di` compiler binary and a precompiled **runtime object** produced from `runtime/runtime.ll`.

- `di-linux-amd64` — copied to `~/.local/bin/di` by `scripts/install.sh`.
- `runtime-linux-amd64.o` — prebuilt object for installs without `clang`, or when `NO_CLANG=1` (see [`docs/no-clang-contract.md`](../docs/no-clang-contract.md)). Must be regenerated from `runtime/runtime.ll` when that IR changes (maintainers: `clang -c -O1 runtime/runtime.ll -o …` outside the tree, then replace this file).

The canonical hosted runtime description is LLVM IR at `runtime/runtime.ll`. There are **no** C sources under `runtime/`.

The compiler emits a native glue translation for user programs into `build/` (ignored by git); that output is not checked into this tree.

To refresh `bootstrap/di-linux-amd64`, maintainers compile the reference compiler from a private checkout or release tarball (see `scripts/rebuild-bootstrap.sh` message) and copy the binary here.

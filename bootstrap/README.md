# Bootstrap artifacts

This directory holds the **Linux x86-64** reference `di` compiler binary and a precompiled **runtime object** produced from `runtime/runtime.ll`.

- `di-linux-amd64` — copied to `~/.local/bin/di` by `scripts/install.sh`.
- `runtime-linux-amd64.o` — same as `clang -c runtime/runtime.ll`; used when `clang` is unavailable during install.

The canonical hosted runtime is LLVM IR at `runtime/runtime.ll`. Edit that file or regenerate the object with `clang -c` on the `.ll` file.

The compiler emits a native glue translation for user programs into `build/` (ignored by git); that output is not checked into this tree.

To refresh `bootstrap/di-linux-amd64`, maintainers compile the reference compiler from a private checkout or release tarball (see `scripts/rebuild-bootstrap.sh` message) and copy the binary here.

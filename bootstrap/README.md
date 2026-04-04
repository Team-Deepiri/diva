# Bootstrap seed compiler

`di-linux-amd64` is the **Linux x86-64** reference `di` binary. It is the **trust root** for self-hosting: the in-tree Di compiler package (`compiler/`) is built with this seed, then used to rebuild itself (see `docs/selfhost-bootstrap.md`).

This repository does **not** ship the legacy C implementation. `scripts/install.sh` copies the seed from `bootstrap/di-linux-amd64` and installs the LLVM runtime object (`runtime/runtime.ll` via `clang`, or `bootstrap/runtime-linux-amd64.o` when `NO_CLANG=1`).

## Refresh the seed

The seed was last produced from the removed C compiler. To rebuild it you must temporarily restore the old sources from git, run the build script, then remove them again (or keep them only on a maintenance branch):

```sh
git checkout <commit-that-still-had-c> -- src include runtime
sh scripts/build-bootstrap-seed.sh
rm -rf src include
git checkout HEAD -- runtime/
```

The last line puts `runtime/` back to your branch tip (LLVM IR only, no `runtime.c`).

Commit the updated `bootstrap/di-linux-amd64` when you want a frozen checkpoint for CI or collaborators.

## Runtime / stdlib resolution

Set `DI_STDLIB_DIR` and `DI_RUNTIME_O` after install, or rely on the defaults under `~/.local/share/di/` (see `scripts/install.sh` output).

## Source extension

Canonical sources use **`.diva`**. The CLI may still accept **`.di`** for compatibility where implemented by the seed.

# No-clang bootstrap contract

This document freezes the behavioral contract for `NO_CLANG=1` installs and for the path toward a Di-native backend without invoking `clang`.

## Environment

| Variable | Meaning |
|----------|---------|
| `NO_CLANG=1` | [`scripts/install.sh`](../scripts/install.sh) must **not** execute `clang`. Runtime is copied from [`bootstrap/runtime-linux-amd64.o`](../bootstrap/runtime-linux-amd64.o), which must be kept in sync with [`runtime/runtime.ll`](../runtime/runtime.ll) (refresh with [`scripts/rebuild-bootstrap.sh`](../scripts/rebuild-bootstrap.sh) when IR changes). |
| `DI_BOOTSTRAP` | Absolute path to the seed `di` binary used by [`compiler/src/main.diri`](../compiler/src/main.diri). |
| `DI_STDLIB_DIR` | Standard library root (default `~/.local/share/di/stdlib`). |
| `DI_RUNTIME_O` | Hosted runtime object linked with user programs. |

## Hosted ABI (link + entry)

- User `func main(): int` lowers to symbol **`di_user_main`**.
- Hosted entry in native glue calls **`di_runtime_set_argv(argc, argv)`** then **`di_user_main()`** (see [`docs/selfhost-bootstrap.md`](selfhost-bootstrap.md)).
- Runtime symbols for stdlib hooks are the `di_runtime_*` names emitted by the seed compiler’s glue generator; new backends must preserve this mapping until the stdlib is versioned.

## Verification

- `NO_CLANG=1` + `./scripts/install.sh` must succeed on Linux x86_64 when `bootstrap/runtime-linux-amd64.o` exists.
- [`tests/run-no-clang.sh`](../tests/run-no-clang.sh) exercises install + a minimal `di run` under this contract.
- CI should run [`scripts/verify-no-clang.sh`](../scripts/verify-no-clang.sh) (or equivalent) so `clang` is never invoked on that lane.
- [`scripts/verify-no-c-sources.sh`](../scripts/verify-no-c-sources.sh) fails if any `.c` or `.h` file is tracked; [`tests/run.sh`](../tests/run.sh) invokes it after the no-clang check.

## Future: Di-native object emission

When the ELF/object backend lands under [`compiler/backend/`](../compiler/backend/), `DI_RUNTIME_O` may be produced entirely by Di tooling; until then, the checked-in bootstrap object is the supported no-clang runtime.

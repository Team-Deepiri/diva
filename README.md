# Di

_A lightweight programming language for semantic analysis, textual IR emission, and native executable generation._

This repository is **Di source only** (`.di` standard library, examples, tests, docs). The reference compiler ships as a **bootstrap Linux amd64** `di` binary under `bootstrap/`; the hosted runtime is **LLVM IR** (`runtime/runtime.ll` → `runtime.o`).

## Repository layout

- `bootstrap/` — prebuilt `di` (Linux x86-64) and `runtime-linux-amd64.o` fallback for installs without `clang`
- `compiler/` — Di package that installs as `di` and forwards to the seed binary (`DI_BOOTSTRAP`); see `compiler/README.md`
- `runtime/` — `runtime.ll` (LLVM IR hosted runtime; no C sources in-repo)
- `stdlib/` — standard library `.di` modules
- `docs/` — language and architecture notes
- `examples/` — sample programs
- `tests/` — compiler integration tests (`tests/run.sh`)

## Install (Linux / WSL)

Needs `cc` only as the **system linker driver** for hosted executables (no C sources in this repository). Optional `clang` to compile `runtime/runtime.ll` at install time; otherwise install copies `bootstrap/runtime-linux-amd64.o`. Set `NO_CLANG=1` to forbid invoking `clang` during install (see `docs/no-clang-contract.md`).

```sh
./scripts/install.sh
```

Then ensure your environment includes (the install script prints these):

- `PATH` containing `~/.local/bin`
- `DI_STDLIB_DIR` → `~/.local/share/di/stdlib` (optional if `HOME` is set — the compiler defaults to `~/.local/share/di/stdlib`)
- `DI_RUNTIME_O` → `~/.local/share/di/runtime/runtime.o` (optional if `HOME` is set — defaults to `~/.local/share/di/runtime/runtime.o`)

## Windows

Use **WSL** and `./scripts/install.sh`. Native Windows install scripts are not wired to this layout.

## Guides

- `docs/install-and-usage.md`
- `docs/syntax-guide.md`
- `docs/language-spec.md`
- `docs/no-clang-contract.md` (bootstrap without `clang`)
- `docs/mir-lir-layer.md`, `docs/backend-elf64-roadmap.md`, `docs/cross-platform-backend.md`

## Example

```di
extern func print_int(x: int): void

func main(): int {
    var x = 10
    print_int(x)
    return 0
}
```

## CLI

```sh
di main.di
di run .
di build .
di check .
di emit-ir .
di watch .
di new my-app
di new my-lib --lib
```

## CMake

`cmake` is a no-op pointer: there is no C compiler build in-tree. Use `./scripts/install.sh` and `bootstrap/di-linux-amd64`. Integration tests run twice (`tests/run.sh`): once with the seed compiler, then with the Di compiler package built from `compiler/` replacing `di`.

## Self-host bootstrap

- `scripts/bootstrap-verify.sh` runs the same suite as `tests/run.sh` (seed + self-host stages).
- The long-term goal is a full compiler in Di; the current `compiler/` driver is a minimal Di-hosted CLI that delegates to the seed binary. See `docs/selfhost-bootstrap.md`.

## Generated output

The bootstrap `di` may write ephemeral native glue and intermediates under `build/` (ignored by git; `*.c` is ignored repo-wide). To clear them: `./scripts/clean.sh` or `rm -rf build`.

## Editor extension

See `tools/vscode-extension/` and `./scripts/install-extension.sh`.

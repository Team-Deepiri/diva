# Di

_A lightweight programming language for semantic analysis, textual IR emission, and native executable generation._

This repository is **Di source only** (`.di` standard library, examples, tests, docs). The reference compiler ships as a **bootstrap Linux amd64** `di` binary under `bootstrap/`; the hosted runtime is **LLVM IR** (`runtime/runtime.ll` → `runtime.o`).

## Repository layout

- `bootstrap/` — prebuilt `di` (Linux x86-64) and `runtime-linux-amd64.o` fallback for installs without `clang`
- `runtime/` — `runtime.ll` (LLVM IR) and `runtime.o` (precompiled for local dev defaults)
- `stdlib/` — standard library `.di` modules
- `docs/` — language and architecture notes
- `examples/` — sample programs
- `tests/` — compiler integration tests (`tests/run.sh`)

## Install (Linux / WSL)

Needs `cc` for linking user programs. Optional `clang` to compile `runtime/runtime.ll` at install time; otherwise the script copies `bootstrap/runtime-linux-amd64.o`.

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

`cmake` is configured to **stop** with a pointer to `./scripts/install.sh` — there is no in-tree compiler build from sources here.

## Generated output

The bootstrap `di` may write ephemeral native glue and intermediates under `build/` (ignored by git; `*.c` is ignored repo-wide). To clear them: `./scripts/clean.sh` or `rm -rf build`.

## Editor extension

See `tools/vscode-extension/` and `./scripts/install-extension.sh`.

# diri-lang

`diri` is a new systems programming language project by Deepiri.

The current repo already includes:

- a C compiler frontend
- semantic analysis
- textual LLVM IR emission
- native executable generation through a generated-C fallback
- a small runtime, examples, install scripts, and an editor extension

## Repository Layout

- `src/`: compiler driver and implementation modules
- `include/`: public/internal headers shared by compiler modules
- `runtime/`: runtime support implemented in C
- `stdlib/`: early standard library surface and notes
- `docs/`: language and architecture documents
- `examples/`: small `diri` programs
- `tests/`: focused compiler tests

## Current Language Surface

`diri` currently supports:

- `func` and `extern func`
- `struct` declarations
- `let` declarations and assignment
- `if` / `else`
- `while`
- integer, boolean, and string literals
- arithmetic and comparisons
- function calls
- field access and field assignment
- struct literals
- array literals and indexing

## Example

```diri
extern func print_int(x: int): void;

func main(): int {
    let x: int = 10;
    print_int(x);
    return 0;
}
```

## CLI

```sh
diri main.di
diri build main.di
diri run main.di
diri emit-ir main.di
diri watch main.di
diri new my-app
```

`.di` is the source extension for all `diri` files.

## Build

The repository includes a simple C build path and can also be built with CMake.

```sh
cmake -S . -B build
cmake --build build
```

If you just want a working local compiler quickly:

```sh
./scripts/install.sh
```

## SDK Workflow

After installation, the expected workflow is:

```sh
diri new hello-di
cd hello-di
diri main.di
diri build main.di
diri emit-ir main.di
diri watch main.di
```

`diri new` creates a starter project with a `main.di`, `.gitignore`, and README.

## Install

Linux/WSL:

```sh
./scripts/install-sdk.sh
```

PowerShell:

```powershell
./scripts/install-sdk.ps1
```

These SDK scripts install:

- the `diri` compiler into a local user bin directory
- the `.di` Diri source file type association on the local machine
- the local `.di` editor extension into Cursor by default

If you only want the compiler, use `./scripts/install.sh` or `./scripts/install.ps1`.

If you only want to register the Diri file type:

- Linux / WSL: `./scripts/install-filetype.sh`
- PowerShell: `./scripts/install-filetype.ps1`

## Editor Extension

A local VS Code / Cursor extension for `.di` files lives in:

- `tools/vscode-extension/`

It registers the `diri` language and currently includes:

- `.di` file association
- comment, bracket, and auto-close configuration
- syntax highlighting for functions, keywords, types, operators, fields, and arrays
- starter snippets for common `diri` patterns

Install it locally:

Linux/WSL:

```sh
./scripts/install-extension.sh
```

PowerShell:

```powershell
./scripts/install-extension.ps1
```

By default these install into Cursor's extensions directory. You can pass a target path to install into VS Code instead.

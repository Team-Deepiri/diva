# di

`Di` a programming language by Deepiri.

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
- `examples/`: small `Di` programs
- `tests/`: focused compiler tests

## Guides

- install and usage: `docs/install-and-usage.md`
- syntax guide: `docs/syntax-guide.md`
- language spec: `docs/language-spec.md`

## Current Language Surface

`Di` currently supports:

- `func` and `extern func`
- `class` declarations with methods
- `var` declarations with optional `::` type annotations
- `if` / `else`
- `while condition => update`
- `flux item in iterable`
- optional top-level `package` declarations
- relative file imports
- integer, boolean, and string literals
- arithmetic, comparisons, and boolean operators
- function and method calls
- field access and field assignment
- object literals
- array literals and indexing
- relative file imports
- optional semicolons, with semicolon-free style preferred

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
di build main.di
di run main.di
di emit-ir main.di
di watch main.di
di new my-app
```

`.di` is the source extension for all `Di` files.

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
di new hello-di
cd hello-di
di main.di
di build main.di
di emit-ir main.di
di watch main.di
```

`di new` creates a starter project with a `main.di`, `.gitignore`, and README.

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

- the `di` compiler into a local user bin directory
- the `.di` Di source file type association on the local machine
- the local `.di` editor extension into Cursor by default

If you only want the compiler, use `./scripts/install.sh` or `./scripts/install.ps1`.

If you only want to register the Di file type:

- Linux / WSL: `./scripts/install-filetype.sh`
- PowerShell: `./scripts/install-filetype.ps1`

## Editor Extension

A local VS Code / Cursor extension for `.di` files lives in:

- `tools/vscode-extension/`

It registers the `Di` language and currently includes:

- `.di` file association
- comment, bracket, and auto-close configuration
- syntax highlighting for functions, keywords, types, operators, fields, and arrays
- starter snippets for common `Di` patterns

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

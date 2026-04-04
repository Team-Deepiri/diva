# Diva

**Diva** is Deepiri’s experimental programming language and LLVM-backed toolchain for fast, expressive **`.diva`** programs—aiming at compact representations, rich control flow, and efficient execution. Sources in this repository are **`.diva` only**; there are **no tracked C/C++ sources** (see `scripts/verify-no-c-sources.sh`).

## Bootstrap model (what “full” means here)

| Piece | Role |
|--------|------|
| **`bootstrap/diva-linux-amd64`** | **Full compiler** today: lex, parse, sema, C codegen + link, pseudo–LLVM IR text. Pinned Linux amd64 seed; rebuild only from an older git snapshot (see `bootstrap/README.md`). |
| **`runtime/runtime.ll`** + **`bootstrap/runtime-linux-amd64.o`** | Hosted runtime (argv, I/O, `std/host` / `std/vec` helpers). Linked as **`runtime.o`**; `cc` is used as the **system linker driver only**. |
| **`compiler/`** (installable **`diva.mod`** app) | **Diva-built driver** (`install.sh` compiles it with the seed): `diva lex` runs the **Diva lexer** (`src/lexer.diva`); other commands forward to the seed. Installed under `$XDG_DATA_HOME/diva/libexec/diva-driver` with a **`diva` wrapper** (and `di` → `diva` symlink) that sets `DIVA_BOOTSTRAP` / `DI_BOOTSTRAP`. |
| **`compiler/{mir,backend}/`** | MIR / ELF scaffolding for future backend work in Diva. |
| **`compiler/frontend/`** | `diva check` shares [`src/lexer.diva`](compiler/src/lexer.diva). |

**Full self-host** = parser, sema, and codegen also in **`.diva`**, so the seed is only needed to break the bootstrap cycle. The **lexer** is the first real compiler stage living in Diva source.

**Not in this repo:** experimental ideas from design chats (e.g. arbitrary bit-bucket layouts, alternate `this` syntax, extra loop forms beyond current `while` / `flux`)—those belong in the language spec / roadmap when you formalize them.

## Repository Layout

- `bootstrap/`: pinned **seed** binary (`diva-linux-amd64`) and optional prebuilt runtime object for `NO_CLANG=1`
- `compiler/`: **installable** Diva app — lexer in `src/lexer.diva`, CLI driver in `src/main.diva`, seed forward + `diva lex` (see `compiler/README.md`)
- `runtime/`: hosted runtime as **LLVM IR** (`runtime.ll`); install and the seed link against a compiled **`runtime.o`** (`bootstrap/runtime-linux-amd64.o` or `clang -c runtime.ll`)
- `stdlib/`: standard library (`.diva` sources)
- `docs/`: language and architecture documents
- `examples/`: small `Diva` programs
- `tests/`: focused compiler tests

## Guides

- install and usage: `docs/install-and-usage.md`
- syntax guide: `docs/syntax-guide.md`
- language spec: `docs/language-spec.md`

## Current Language Surface

`Diva` currently supports:

- `func` and `extern func`
- explicit generic functions via `func name[T](...)`
- `class` declarations with methods
- `trait` declarations and `impl Trait for Type` conformance checks
- `var` declarations with optional `::` type annotations
- `if` / `else`
- `while condition => update`
- `flux item in iterable`
- optional top-level `package` declarations
- package manifests via `diva.mod` for app, lib, and kernel targets
- relative file imports
- shipped stdlib modules via `import "std/..."`
- hosted system hooks via `extern func write`, `print_hex`, `exit`, and `abort`
- utility stdlib modules for io, int helpers, ranges, logic, and assertions
- integer, boolean, and string literals
- arithmetic, comparisons, and boolean operators
- function and method calls
- field access and field assignment
- object literals
- array literals and indexing
- relative file imports
- optional semicolons, with semicolon-free style preferred

## Example

```diva
extern func print_int(x: int): void

func main(): int {
    var x = 10
    print_int(x)
    return 0
}
```

## CLI

Primary command: **`diva`**. A symlink **`di` → `diva`** is installed for compatibility.

```sh
diva main.diva
diva run .
diva build .
diva check .
diva emit-ir .
diva watch .
diva new my-app
diva new my-lib --lib
diva lex src/main.diva
```

`.diva` is the source extension for all `Diva` files.

## Build / install

There is **no in-tree C compiler** to build. Install copies the seed and runtime:

```sh
./scripts/install.sh
```

CMake is intentionally disabled (`CMakeLists.txt` explains the migration). Linking user programs still uses the system **`cc`** driver as a **linker only**; there are no C sources in this repository.

To rebuild the Linux amd64 **seed** under `bootstrap/`, you must temporarily restore the legacy C sources from git history, then run `scripts/build-bootstrap-seed.sh`. See [`bootstrap/README.md`](bootstrap/README.md).

## SDK Workflow

After installation, the expected workflow is:

```sh
diva new hello-diva
cd hello-diva
diva run .
diva build .
diva check .
diva emit-ir .
diva watch .
```

`diva new` creates a package directory with `diva.mod`, `src/`, `.gitignore`, and README (manifest name unchanged for the toolchain).

Package manifests can also declare local dependencies like `dep.math_lib = "../math_lib"`, and source files can import them with `import "pkg/math_lib"`.

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

- the `diva` compiler (and `di` symlink) into a local user bin directory
- the `.diva` Diva source file type association on the local machine
- the local `.diva` editor extension into Cursor by default

If you only want the compiler, use `./scripts/install.sh` or `./scripts/install.ps1`.

If you only want to register the Diva file type:

- Linux / WSL: `./scripts/install-filetype.sh`
- PowerShell: `./scripts/install-filetype.ps1`

## Editor Extension

A local VS Code / Cursor extension for `.diva` files lives in:

- `tools/vscode-extension/`

It registers the `Diva` language and currently includes:

- `.diva` file association
- comment, bracket, and auto-close configuration
- syntax highlighting for functions, keywords, types, operators, fields, and arrays
- starter snippets for common `Diva` patterns

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

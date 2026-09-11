# Diva
<img width="1695" height="928" alt="image" src="https://github.com/user-attachments/assets/48b30bdb-1c2b-4a67-ba69-a70c647cd708" />

**Diva** is Deepiri’s experimental programming language and LLVM-backed toolchain for fast, expressive **`.diva`** programs—aiming at compact representations, rich control flow, and efficient execution. **All compiler and library sources in this repo are `.diva`**. Policy details: [`docs/source-language-policy.md`](docs/source-language-policy.md).

## Bootstrap model (self-sustaining Diva development)

| Piece | Role |
|--------|------|
| **`bootstrap/diva-linux-amd64`** | **Pinned seed binary** (full pipeline for `build` / `run` / `emit-ir` today). Not C *source* in this repo — it is the trust root until the Diva-only compiler can replace it end-to-end. See `bootstrap/README.md`. |
| **`runtime/runtime.ll`** + **`bootstrap/runtime-linux-amd64.o`** | Hosted runtime (argv, I/O, `std/host` / `std/vec`). Becomes **`runtime.o`** at install (`clang -c` on the `.ll`, or copy the prebuilt `.o` when `NO_CLANG=1`). |
| **`compiler/`** (`package.diva`) | **Diva-built driver**: native commands (`lex`, `parse`, `ir`, `asm`, `emit-ir`, `build`, `run`, `check`, `new` for app/lib/kernel) run in Diva without delegating to the seed. **`build`/`run`** emit **pure in-process ELF** (no external `cc`/link of user programs). Installed as `$XDG_DATA_HOME/diva/libexec/diva-driver` with a **`diva` wrapper** (still ships the seed for promotion / manual use). |
| **`compiler/{mir,backend}/`** | MIR / ELF scaffolding for the native backend in Diva. |
| **`compiler/frontend/`** | Shares lexer sources with `compiler/src/`. |

**Self-sustainability** here means: you ship and edit **only `.diva`** (plus LLVM IR for the small hosted runtime and shell for scripts). The seed remains the **trust root** until you promote a new binary (see `bootstrap/README.md`).

**Self-host acceptance (CI / `tests/run.sh`):** the suite requires (1) seed building `compiler/` with `DIVA_NO_EXTERNAL=1` and no `DI_RUNTIME_O`, (2) stage-3 rebuild with the in-tree driver under the same pure flags, and (3) `scripts/verify-pure-compiler-build.sh` (pinned seed by default). There is no “skip self-host and pass” path.

**Install strict mode:** when `CI` is set or `DIVA_INSTALL_STRICT=1`, `scripts/install.sh` fails if the Diva-authored driver cannot be built (no silent seed-only install). For bring-up in CI, set `DIVA_INSTALL_SEED_ONLY=1` to allow seed-only installs.

**Not in this repo:** experimental ideas from design chats (e.g. arbitrary bit-bucket layouts, alternate `this` syntax, extra loop forms beyond current `while` / `flux`)—those belong in the language spec / roadmap when you formalize them.

## Repository Layout

| Path | Purpose |
|------|---------|
| `bootstrap/` | Pinned seed (`diva-linux-amd64`) and prebuilt `runtime-linux-amd64.o` |
| `compiler/` | Installable Diva driver (`src/main.diva`, …) — see `compiler/README.md` |
| `stdlib/` | Standard library (`.diva`) |
| `docs/` | Specs, roadmaps, install guide, logo (`docs/diva-logo.png`) |
| `examples/` | Small programs exercised by native / strict-pure suites |
| `tests/` | Integration + locked negatives (`cases/fail`, `negative.list`); ad-hoc snippets in `tests/manual/` |
| `scripts/` | Build, promote, verify, install helpers |
| `tools/` | Editor / tooling (e.g. VS Code extension) |
| `testkern/` | Kernel package demo |
| `build/` | Local build outputs (gitignored) |

Root keeps only `README.md`, `LICENSE`, and `.gitignore` besides those directories.

## Guides

- install and usage: `docs/install-and-usage.md`
- syntax guide: `docs/syntax-guide.md`
- language spec: `docs/language-spec.md`
- user heap / growable buffer: `docs/heap-mem.md`
- what is (and is not) Diva source in-tree: `docs/source-language-policy.md`

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
- package manifests via `package.diva` for app, lib, and kernel targets
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

`diva new` (native driver) creates app/lib/kernel package directories with `package.diva`, `src/`, `.gitignore`, and README.

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

# Diva Install And Usage

This guide shows how to install the `Diva` compiler and start running `.diva` programs.

## What You Get

The repository includes:

- the `diva` compiler (symlink `di`)
- the runtime support files used by generated programs
- install scripts for Linux / WSL and PowerShell
- a local VS Code / Cursor extension for `.diva` files

## Prerequisites

You need a working C compiler:

- Linux / WSL: `cc`, `clang`, or `gcc`
- Windows PowerShell: Visual Studio Build Tools or `gcc`

Optional:

- `cmake` if you want to build with the CMake project instead of the install script

## Quick Install

### Linux / WSL

Install the compiler, file association, and editor extension:

```sh
./scripts/install-sdk.sh
```

Install only the compiler:

```sh
./scripts/install.sh
```

### PowerShell

Install the compiler, file association, and editor extension:

```powershell
./scripts/install-sdk.ps1
```

Install only the compiler:

```powershell
./scripts/install.ps1
```

## Installed Locations

On Linux / WSL, the default install locations are:

- compiler: `~/.local/bin/diva` (and `di` → `diva`)
- runtime: `~/.local/share/diva/runtime/`
- stdlib: `~/.local/share/diva/stdlib/`

On PowerShell, the default install locations are:

- compiler: `~/.diva/bin/diva.exe`
- runtime: `~/.diva/runtime/`
- stdlib: `~/.diva/stdlib/`

If the compiler is not found after install, add the install directory to your `PATH`.

## Editor Support

Install the local editor extension only:

### Linux / WSL

```sh
./scripts/install-extension.sh
```

### PowerShell

```powershell
./scripts/install-extension.ps1
```

The language name is `Diva` and source files use the `.diva` extension.

## First Program

Create a file named `main.diva`:

```diva
extern func print_int(x: int): void

func main(): int {
    var value = 10
    print_int(value)
    return 0
}
```

Semicolons are optional in `Diva`. The compiler still accepts them, but the recommended style is to leave them out.

Run it:

```sh
diva run main.diva
```

## Basic CLI

Common commands:

```sh
di main.diva
di build .
diva run .
di check .
di emit-ir .
diva watch .
diva new hello-di
diva new hello-lib --lib
```

Notes:

- `di main.diva` builds and runs a single `.diva` file
- `diva build . -g` emits minimal DWARF (`.debug_line` / `.debug_info` / `.debug_abbrev`) so `addr2line -e <exe> 0x1000` resolves to the source entry line — see `docs/dwarf-debug.md` (Issue #63). Without `-g`, the loadable ELF layout is unchanged.
- `di check .` validates a package without native linking
- `di emit-ir .` writes LLVM IR into `build/`
- `diva watch .` watches the package entry and its transitive imports (plus `package.diva`), rebuilds on content change (1s poll + 1s debounce), and keeps running after build errors. Set `DIVA_WATCH_MAX_ITERS=N` to exit after N poll cycles (CI smoke).
- `diva new hello-di` creates an app package
- `diva new hello-lib --lib` creates a library package
- `diva new --kernel` creates a kernel scaffold (`kmain` in `src/boot.diva`). Use `diva check` / `emit-ir` / `build` on the package dir — see `docs/kernel-packages.md`. Hosted **`cc` + `DI_RUNTIME_O`** only when **`DIVA_ALLOW_HOSTED_LINK=1`**.

## Kernel vs app

| | App | Kernel |
|--|-----|--------|
| Manifest `kind` | `app` | `kernel` |
| Entry func | `main` | `kmain` |
| `diva check` / `emit-ir` / `build` | yes | yes (Issue #59) |

## Create A New Project

```sh
diva new hello-di
cd hello-di
diva run .
```

The generated project includes:

- `package.diva`
- `src/main.diva` for apps or `src/lib.diva` for libraries
- `.gitignore`
- `README.md`

## Package Dependencies

Package manifests can declare local dependencies:

```txt
name = "app_with_dep"
kind = "app"
entry = "src/main.diva"
dep.math_lib = "../math_lib"
```

Then source files can import a dependency package by name:

```diva
import "pkg/math_lib"
```

`pkg/<name>` resolves to the dependency package entry from that package's own `package.diva`.

## Build From Source

### Using The Install Script

```sh
./scripts/install.sh
```

### Using CMake

```sh
cmake -S . -B build
cmake --build build
```

## Diagnostics

Parser and semantic errors print:

```text
<path>:<line>:<col>: <message>
```

Lines and columns are **1-based** and refer to the originating source file (not the
merged translation unit). Multi-file builds insert `//@diva-file:<abs-path>` markers
when merging imports so diagnostics resolve back to the real file.

## Testing

Run the smoke test suite from the repository root:

```sh
sh tests/run.sh
```

## Troubleshooting

### `di: command not found`

- ensure the install directory is on your `PATH`
- restart the shell after install if needed

### No C compiler found

- install `clang`, `gcc`, or another `cc`-compatible compiler
- on Windows, install Visual Studio Build Tools or `gcc`

### Editor does not recognize `.diva`

- reinstall the local extension with the install script
- reload Cursor or VS Code

# Di Install And Usage

This guide shows how to install the `Di` compiler and start running `.di` programs.

## What You Get

The repository includes:

- the `di` compiler
- the runtime support files used by generated programs
- install scripts for Linux / WSL and PowerShell
- a local VS Code / Cursor extension for `.di` files

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

- compiler: `~/.local/bin/di`
- runtime: `~/.local/share/di/runtime/`
- stdlib: `~/.local/share/di/stdlib/`

On PowerShell, the default install locations are:

- compiler: `~/.di/bin/di.exe`
- runtime: `~/.di/runtime/`
- stdlib: `~/.di/stdlib/`

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

The language name is `Di` and source files use the `.di` extension.

## First Program

Create a file named `main.di`:

```di
extern func print_int(x: int): void

func main(): int {
    var value = 10
    print_int(value)
    return 0
}
```

Semicolons are optional in `Di`. The compiler still accepts them, but the recommended style is to leave them out.

Run it:

```sh
di run main.di
```

## Basic CLI

Common commands:

```sh
di main.di
di build .
di run .
di check .
di emit-ir .
di watch .
di new hello-di
di new hello-lib --lib
```

Notes:

- `di main.di` builds and runs a single `.di` file
- `di build .` builds the current package directory
- `di check .` validates a package without native linking
- `di emit-ir .` writes LLVM IR into `build/`
- `di watch .` watches the package entry file from `di.mod`
- `di new hello-di` creates an app package
- `di new hello-lib --lib` creates a library package

## Create A New Project

```sh
di new hello-di
cd hello-di
di run .
```

The generated project includes:

- `di.mod`
- `src/main.di` for apps or `src/lib.di` for libraries
- `.gitignore`
- `README.md`

## Package Dependencies

Package manifests can declare local dependencies:

```txt
name = "app_with_dep"
kind = "app"
entry = "src/main.di"
dep.math_lib = "../math_lib"
```

Then source files can import a dependency package by name:

```di
import "pkg/math_lib"
```

`pkg/<name>` resolves to the dependency package entry from that package's own `di.mod`.

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

### Editor does not recognize `.di`

- reinstall the local extension with the install script
- reload Cursor or VS Code

# Targets

Diva identifies compilation targets with LLVM-style triples: `<arch>-<os>[-env]`.
The compiler exposes this through `--target` on `build`, `ir`, and `opt`, plus
`diva target list` and `diva target current`.

## Supported target

| Triple | Status |
| --- | --- |
| `x86_64-linux-gnu` | supported (native) |
| `x86_64-linux` | alias for `x86_64-linux-gnu` |
| `native` | alias for `x86_64-linux-gnu` |

The native descriptor is:

| Field | Value |
| --- | --- |
| arch | `x86_64` |
| os | `linux` |
| pointer width | 8 bytes |
| endianness | `little` |
| name | `x86_64-linux-gnu` |

Only the native x86_64 Linux target emits code. `diva target current` prints
`x86_64-linux-gnu`.

## Declared but not implemented

These triples are recognized and rejected with an explicit diagnostic; Diva
does not emit object files or executables for them:

- `aarch64-linux-gnu`
- `aarch64-none-elf`
- `x86_64-apple-darwin`
- `arm-linux-gnueabi`
- `riscv64-linux-gnu`
- `wasm32-unknown-unknown`

The error is:

```text
error: target '<triple>' is declared but not implemented (only x86_64-linux-gnu is supported)
```

A triple with unknown components, empty components, or more than three
components is malformed and reports a separate error.

## Examples

```sh
diva build --target native examples/hello.diva /tmp/hello
diva ir --target x86_64-linux-gnu examples/hello.diva
diva opt --target x86_64-linux examples/hello.diva

diva target list
diva target current
```

## Scope

Issue #108 adds the target abstraction and CLI selection only. Real AArch64
codegen, macOS/Mach-O emission, and bare-metal ELF/startup support are
deferred; passing those triples is an honest error, not a silent fallback.

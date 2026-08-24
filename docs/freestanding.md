# Freestanding mode (Issue #30)

Freestanding/system packages target environments without a full hosted libc.

## Scaffold

```bash
diva new mysys --system
```

Writes `kind = "system"`, entry `src/system.diva`, and documents syscall-first hooks.

## Build flags

| Variable | Effect |
|----------|--------|
| `DIVA_FREESTANDING=1` | Documented preference for pure-ELF + syscall wrappers; use with `DIVA_NO_EXTERNAL=1`. |
| `DIVA_NO_EXTERNAL=1` | Default in tests — no host `cc`/`ld`. |

## Syscall wrappers

Import `std/syscall_linux.diva` for `sys_exit`, `sys_write`, and helpers. See
`docs/ffi-abi.md` for the AMD64 calling convention.

## Example

`examples/freestanding_demo.diva` writes `freestanding_ok` via `sys_write` and exits with `sys_exit`.

Kernel packages (`--kernel`, `kmain`) remain on the `#59` path for bring-up images without `main`.

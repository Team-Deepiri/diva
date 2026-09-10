# C FFI and ABI rules (Issue #30)

Native Diva uses the **System V AMD64 ABI** for `extern` calls on Linux:

| Kind | Registers | Notes |
|------|-----------|-------|
| Integer/pointer args | `%rdi`, `%rsi`, `%rdx`, `%rcx`, `%r8`, `%r9` | First six arguments |
| Return int/pointer | `%rax` | |
| Stack | 16-byte aligned before `call` | Callee may use `%rbp` frame |

## Declaring FFI

```di
extern func write(fd: int, buf: str): int
extern func my_c_hook(x: int): int
```

- Names must match the linked symbol (Diva codegen emits `di_runtime_<name>` for
  builtins listed in `pure_elf_builtins.diva`, or raw names for user externs resolved at link).
- `str` is passed as a pointer (`char*`).
- Do not rely on struct layout across the boundary until a stable `repr(C)` attribute lands.

## Syscall wrappers

Platform-specific thin wrappers live under `stdlib/std/syscall_linux.diva` (`sys_exit`,
`sys_write`). Kernel/freestanding packages should import these instead of hosted `os`/`host_*`.

## Freestanding packages

- Scaffold with `diva new --system` (`kind = "system"`).
- Set `DIVA_FREESTANDING=1` when building to prefer pure-ELF syscall paths and omit
  hosted runtime expectations (see `docs/freestanding.md`).

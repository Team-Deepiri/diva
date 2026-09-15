# Kernel packages (Issue #59)

`kind = "kernel"` packages are first-class on the native driver.

## Manifest

```txt
name = "kernel_demo"
kind = "kernel"
entry = "src/boot.diva"
```

Entry source should define **`kmain(): int`** (not `main`). Apps still use `main`.

## Commands

| Command | Behavior |
|---------|----------|
| `diva check <kernel-dir>` | Merge + lex/parse/sema (no `main` required) |
| `diva emit-ir <kernel-dir>` | Dump Diva IR for the package |
| `diva build <kernel-dir>` | Pure ELF with entry stub calling **`kmain`** |
| `diva run <kernel-dir>` | Build + execute (Linux host smoke; exit status = `kmain` return) |
| `diva watch <kernel-dir>` | Same as apps |

## Hosted vs kernel

- **App / lib:** normal hosted tooling path; apps require `main`.
- **Kernel:** freestanding *surface* — no CRT `main` contract. Today’s `build` still emits a **pure ELF PIE** usable on Linux for bring-up (syscall exit after `kmain`). Bootloader / linker-script targets remain on the systems track (#30).

Scaffold: `diva new mykern --kernel`. Example: `examples/kernel_demo`.

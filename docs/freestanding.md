# Freestanding mode (Issue #30 — stub for system template)

Freestanding packages use `diva new --system` (`kind = "system"`). They target
environments without a full hosted libc contract:

- Entry: `src/system.diva` with `main` or a custom symbol documented in your linker script.
- Declare platform hooks as `extern` (see `docs/ffi-abi.md`).
- Set `DIVA_FREESTANDING=1` when building to skip hosted runtime assumptions (WIP).

Kernel packages (`--kernel`, `kmain`) remain the path for `#59` bring-up images.

See also: `docs/ffi-abi.md`, `docs/kernel-packages.md`.

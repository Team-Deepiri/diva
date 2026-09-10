# Diva Runtime Model

The first `Diva` runtime model is intentionally conventional.

## Baseline

- stack locals for primitive values
- explicit primitive types
- C runtime shims for I/O
- hosted runtime shims for `write`, `exit`, `abort`, and hex printing
- LLVM manages low-level optimization and register allocation

## Package Kinds

`Diva` currently has three package kinds through `package.diva`:

- `app`: requires `main` and links a hosted / pure-ELF executable
- `lib`: validates and emits IR without requiring `main`
- `kernel`: validates without `main`; entry is `kmain`; `diva build` emits a pure ELF entered at `kmain` (see `docs/kernel-packages.md`)

## Why Start Conventional

The compiler needs a stable semantic base before advanced memory experiments.

## Later Research Track

After the MVP works, these can be explored as opt-in features:

- tagged packed values
- NaN boxing
- bit-packed aggregates
- compiler-managed slot reuse
- SIMD-aware data layouts

# Di Runtime Model

The first `Di` runtime model is intentionally conventional.

## Baseline

- stack locals for primitive values
- explicit primitive types
- native runtime shims for I/O (`runtime/runtime.ll`)
- hosted runtime shims for `write`, `exit`, `abort`, and hex printing
- LLVM manages low-level optimization and register allocation

## Package Kinds

`Di` currently has three package kinds through `di.mod`:

- `app`: requires `main` and links a hosted executable
- `lib`: validates and emits IR without requiring `main`
- `kernel`: validates without `main` and builds a freestanding object file

## Why Start Conventional

The compiler needs a stable semantic base before advanced memory experiments.

## Later Research Track

After the MVP works, these can be explored as opt-in features:

- tagged packed values
- NaN boxing
- bit-packed aggregates
- compiler-managed slot reuse
- SIMD-aware data layouts

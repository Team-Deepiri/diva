# Diri Runtime Model

The first `diri` runtime model is intentionally conventional.

## Baseline

- stack locals for primitive values
- explicit primitive types
- C runtime shims for I/O
- LLVM manages low-level optimization and register allocation

## Why Start Conventional

The compiler needs a stable semantic base before advanced memory experiments.

## Later Research Track

After the MVP works, these can be explored as opt-in features:

- tagged packed values
- NaN boxing
- bit-packed aggregates
- compiler-managed slot reuse
- SIMD-aware data layouts

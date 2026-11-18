# IR optimizations (issue #105)

The native compiler runs a small, conservative optimization pipeline after IR
building and before x86-64 code generation. The pipeline is deliberately local:
it never reasons across calls or memory, and it never removes operations that
can have side effects.

## Passes

1. **Constant folding** — binary integer operations whose two operands are
   known integer constants are replaced by a single `const`. Covered operators
   are `+ - * / %`, `& | ^`, `<< >>`, the internal arithmetic shift, and all
   integer comparisons. Unary `-` on a literal is folded as well. Division and
   modulo are left alone when the divisor is zero. Logical right shift of a
   negative constant is also left alone, since the folded value would need
   unsigned semantics that the IR does not carry.
2. **Algebraic simplification** — when exactly one operand is a known literal,
   the identity forms become a copy and the absorbing forms become a constant:
   `x + 0`, `x - 0`, `x * 1`, `x | 0`, `x ^ 0`, `x << 0`, `x >> 0`, and
   `x * 0`. The commutative forms of the safe identities are handled too.
3. **Dead code elimination** — pure instructions whose destination vreg is
   never read are removed. The pure set is integer constants, arithmetic,
   comparisons, bitwise/shift ops, and copies. Calls, stores, loads, returns,
   branches, traps, allocations, and all memory operations are kept even when
   their result looks unused.

The three passes run to a fixed point, capped at eight iterations. Each
iteration reruns the constant analysis from the current IR, so a folded value
can enable a later simplification or make another temporary dead.

`^` is accepted in source as bitwise XOR and lowers to the `xor` IR opcode.

## Observing the pipeline

```sh
diva opt <file.diva>            # optimized IR dump
diva opt --no-opt <file.diva>   # IR as built, before the passes
```

`ir` and `emit-ir` continue to print the unoptimized IR. The flag may appear
before or after the file name.

## Tests

`tests/opt.sh` builds a driver from the bootstrap seed (unless
`DIVA_PURE_DRIVER` is set) and checks:

- folded constants and removal of the now-dead operand constants;
- identity simplifications in the IR;
- preservation of calls, stores, branches, and division by a variable zero;
- runtime output of arithmetic, bitwise, shift, comparison, and identity cases.

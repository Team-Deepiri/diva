# MLIR lowering architecture (Issue #119)

This repository now has a **textual IR-to-MLIR lowering pass**, written entirely in Diva:

```
diva emit-mlir [--auto] <file.diva>
```

It prints an MLIR-like textual module to stdout and a lowering summary to stderr.
`--auto` is accepted as a no-op so callers can adopt the command before more
modes exist. This is **an architecture pass, not full MLIR support**: unsupported
Diva IR operations are preserved as comments and counted.

## Where the code lives

| File | Role |
|------|------|
| `compiler/src/mlir_emit.diva` | IR walker, dialect mapping, text emitter, unsupported-op accounting |
| `compiler/src/main.diva` | `emit-mlir` CLI command, argument handling, parse/sema/IR setup |
| `tests/mlir.sh`, `tests/cases/mlir/` | End-to-end checks for emitted text, comments, summary and failure exit |
| `docs/mlir-architecture.md` | This document |

The emitter is built into the self-hosted driver through the normal package
import graph (`main.diva` imports `mlir_emit.diva`). No C/C++ sources are added.

## Pipeline

```
source -> lexer -> parser -> sema -> Diva IR -> MIR type view -> MLIR text
```

`cmd_emit_mlir` follows the same parse/sema/IR steps as `emit-ir`. It exits
non-zero only when parsing or semantic analysis fails; lowering itself is
non-fatal. `mlir_emit_module` walks:

```
module -> function -> basic block -> instruction
```

SSA value names are preserved verbatim as `%v<number>`. Function signatures keep
their name, parameter count (with the IR `param` slots as block arguments) and
return type. MLIR block labels are derived from Diva IR label ids (`^bb<id>`).

The existing typed-MIR layer (`ir_types.diva`) supplies a per-function type view.
It is used for operand/result type spelling; parameter slots are spelled `i64`
until a memory dialect is defined, since Diva IR does not carry parameter type
tags directly.

## Dialect mapping

| Diva IR op | Emitted MLIR |
|------------|--------------|
| `const` | `arith.constant` |
| `add`, `sub`, `mul`, `div`, `mod` | `arith.addi`, `arith.subi`, `arith.muli`, `arith.divsi`, `arith.remsi` |
| `and`, `or`, `xor`, `shl`, `shr`, `sar` | `arith.andi`, `arith.ori`, `arith.xori`, `arith.shli`, `arith.shrui`, `arith.shrsi` |
| `eq`, `ne`, `lt`, `le`, `gt`, `ge` | `arith.cmpi eq/ne/slt/sle/sgt/sge` |
| `neg`, `not` | `arith.subi` / `arith.xori` with an inline constant |
| `call` | `func.call @callee(...) : (...) -> T` |
| `br`, `br.cond` | `cf.br`, `cf.cond_br` |
| `ret`, `ret.void` | `func.return` |
| `param`, `nop` | elided (block argument / comment) |

Types that have no stable MLIR definition yet use placeholder custom-dialect
types: `!diva.str`, `!diva.text`, `!diva.ptr`, `!diva.slice`, `!diva.opaque`.

## Unsupported operations

An instruction without a mapping emits a comment instead of failing:

```
// diva.unsupported: alloca
// diva.unsupported: text.concat
```

Text/string helpers arrive in the IR as calls, but are reported with their
Diva-level names (`text.concat`, `text.slice`, `text.cmp`) until the text dialect
exists. Every such comment increments a counter; `mlir_emit_module` always prints:

```
mlir: emitted <N> instruction(s), unsupported <M>; partial lowering (issue #119)
```

A non-zero `<M>` is informational only and does not change the exit code.

## Verification

```
ROOT_DIR=$PWD DI_STDLIB_DIR=$PWD/stdlib DIVA_NO_EXTERNAL=1 \
  DI_RUNTIME_O=$PWD/bootstrap/runtime-linux-amd64.o \
  ./bootstrap/diva-linux-amd64 build "$PWD/compiler" /tmp/drv-mlir

DIVA_PURE_DRIVER=/tmp/drv-mlir sh tests/mlir.sh
DIVA_TEST_FAST=1 timeout 1500 bash tests/run.sh   # must print "all tests passed"
```

## Deferred

- `#120`: real dialect definitions for `!diva.*` placeholder types and memory
  ops (`alloca`, `load`, `store`, globals, arrays).
- `#122`: linalg/tensor/ONNX lowering for numerical kernels, plus text/tensor
  operation dialect ops replacing the unsupported comments.
- Verification against `mlir-opt`/`mlir-translate` and binary emit are out of
  scope for this textual-architecture issue.

# ONNX text graph import (issue #122)

`diva onnx-check`, `diva onnx-run`, and `diva onnx-mlir` import a small text
representation of an ONNX graph. This is the foundation of the ONNX bridge: it
covers a precisely defined subset, validates it, and reuses the existing tensor
builtins and MLIR emitter from issues #112 and #120. Binary `.onnx` protobufs,
opsets, attribute parsing, and full ONNX operator coverage are follow-up work.

## File format (`.onnx.txt`)

The format is line-oriented UTF-8/ASCII text. Each non-blank line is one
statement. Leading and trailing spaces/tabs are ignored, tokens are separated
by spaces or tabs, and a line whose first non-whitespace byte is `#` is a
comment. Inline comments are not supported.

```text
input <name> <shape>
output <name>
const <name> <shape> <value> ...
node <op> <input> [<input>] -> <output>
```

- `<name>` must match `[A-Za-z_][A-Za-z0-9_]*` and must be unique across all
  `input`, `const`, and node outputs. `<shape>` is either `N` for rank 1 or
  `NxM` for rank 2, where `N` and `M` are decimal integers in `1..999`.
- `input` declares a named graph input with a shape. It is a declaration only:
  runtime input binding is deferred (see below).
- `const` declares a named tensor followed by exactly `N` (rank 1) or `N*M`
  (rank 2) integer element values in row-major order. Negative values are
  allowed. Values are embedded in the generated Diva source.
- `output` declares a graph output by name. It may appear before or after the
  node that produces the name; the name must be defined somewhere in the graph.
  Multiple `output` lines are printed in declaration order.
- `node` declares an operation. Binary ops (`Add`, `Mul`, `MatMul`) require two
  inputs; unary `Relu` requires one. Node inputs must name values declared
  earlier in the file, so the graph must be in topological order. The output
  name is inferred from the op and the input shapes.

Example (two nodes, rank 1):

```text
output y
const a 4 1 2 3 4
const b 4 2 2 2 2
const c 4 10 10 10 10
node Mul a b -> m
node Add m c -> y
```

`diva onnx-run` prints one line per declared output:

```text
y: 12 14 16 18
```

## Supported ops and ONNX semantics

All values are integer tensors of rank 1 or 2. The text format uses the ONNX
operator spellings; semantics are the ONNX elementwise/matrix semantics
restricted to the shapes below:

| Op | ONNX semantics | Supported shapes | Diva lowering |
| --- | --- | --- | --- |
| `Add` | `C = A + B` (ONNX `Add`) | Equal rank-1 or rank-2 shapes | `tensor_add` for rank 1; `tensor_get`/`tensor_set` loop for rank 2 |
| `Mul` | `C = A * B` (ONNX `Mul`) | Equal rank-1 or rank-2 shapes | `tensor_get`/`tensor_set` loop |
| `MatMul` | `C[i,j] = sum_p A[i,p] * B[p,j]` (ONNX `MatMul`) | Rank 2 and `A.d1 == B.d0`; result `[A.d0, B.d1]` | `tensor_matmul` |
| `Relu` | `max(0, x)` (ONNX `Relu`) | Rank 1 or 2, result shape equals input shape | `tensor_get`/`tensor_set` loop |

Broadcasting is intentionally deferred: `Add` and `Mul` require exactly equal
shapes rather than the full ONNX broadcast rules. Element type is the Diva
`int` (i64); ONNX floating-point tensors, attributes, quantization, and other
data types are deferred.

## Validation

`diva onnx-check <file>` parses and validates the graph. It prints
`ok: <n> nodes` on success. On failure it prints one or more `error:` lines on
stderr and exits non-zero. Validation enforces:

- unique value names;
- every node input is defined earlier in the file;
- every declared output name is defined;
- at least one output declaration;
- supported ops and correct unary/binary arity;
- valid names, positive shapes, and correct const element counts;
- rank-1/rank-2 shape compatibility (`Add`/`Mul` equal shapes, `MatMul` rank 2
  with matching inner dimensions).

## Execution and MLIR

`diva onnx-run <file>` translates the graph into a Diva `main()` function that
uses the tensor builtins for `Add` (rank 1), `MatMul`, allocation, indexing, and
element access. It then compiles and executes that generated source with the
existing native pipeline. Only constant-only graphs are runnable; graphs with
`input` declarations are accepted by `onnx-check` and `onnx-mlir` but
`onnx-run` reports `error: runtime inputs are deferred; onnx-run supports
constant-only graphs`.

`diva onnx-mlir <file>` emits MLIR through `mlir_emit.diva`: rank-1 `Add`
becomes `linalg.add` and `MatMul` becomes `linalg.matmul`. A prologue comment
maps each imported node to its ONNX op and target Linalg op. `Mul` and `Relu`
currently lower to scalar arithmetic loops, so their comments mark the full
Linalg mapping as pending.

## Deferred work

- Binary `.onnx` protobuf parsing and opset/attribute handling.
- Runtime graph inputs and external/sidecar weights.
- Floating-point, higher ranks, broadcasting, and remaining ONNX operators
  (`Conv`, `BatchNormalization`, `MaxPool`, `Gemm`, `Concat`, `Softmax`,
  `Reshape`).
- Full Linalg lowering for `Mul`/`Relu` and end-to-end LLVM/CUDA codegen.
- ResNet-50 import and ONNX Runtime numerical comparison.

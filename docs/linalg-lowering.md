# Linalg lowering (`tensor_add`, `tensor_dot`, `tensor_matmul`)

Issue #120 adds three integer tensor operations on top of the rank-1/rank-2 tensor type from #112.

## Builtins

| Builtin | Inputs | Result |
| --- | --- | --- |
| `tensor_add(a, b)` | two `tensor<int, N>` | `tensor<int, N>` |
| `tensor_dot(a, b)` | two `tensor<int, N>` | `int` |
| `tensor_matmul(a, b)` | `tensor<int, N, M>` and `tensor<int, M, K>` | `tensor<int, N, K>` |

Rank mismatches are semantic errors. For example, passing rank-2 tensors to `tensor_add` reports
`sema: tensor_add rank mismatch: expected rank 1 tensor, got rank 2`.

Operand lengths are checked at runtime. Mismatched `tensor_add` operands trap with
`tensor_add: shapes must match`; mismatched `tensor_dot` operands trap with
`tensor_dot: shapes must match`; mismatched `tensor_matmul` inner dimensions trap with
`tensor_matmul: inner dimensions must match`.

Rank-2 storage is row-major: element `(i, j)` is at `i * M + j`, and matmul computes
`C[i, j] = sum over p of A[i, p] * B[p, j]`.

## Lowering paths

The compiler uses one IR representation with two build modes:

- Normal `build` mode lowers tensor operations into existing scalar IR (`alloc`, `load`, `store`,
  `br.cond`, `add`, `mul`) before native code generation. No new x86 backend opcodes are required.
- `emit-mlir` mode keeps high-level `tensor.add`, `tensor.dot`, and `tensor.matmul` IR ops plus
  `tensor.shape` annotations. The textual MLIR emitter uses those annotations to print typed
  Linalg operations.

Tensor shapes are encoded in IR as `rank * 1000000 + d0 * 1000 + d1`, where rank is 1 or 2 and
each dimension is at most 999. Shape annotations are metadata: they do not define new SSA values.

## MLIR example

```diva
var a: tensor<int, 4> = tensor_fill(2, 4)
var b: tensor<int, 4> = tensor_fill(3, 4)
var c: tensor<int, 4> = tensor_add(a, b)
var p: tensor<int, 2, 2> = tensor_matmul(m, n)
```

emits excerpts like:

```mlir
%v75_init = arith.constant dense<0> : tensor<4xi64>
%v75 = linalg.add ins(%v73, %v74 : tensor<4xi64>, tensor<4xi64>) outs(%v75_init : tensor<4xi64>) -> tensor<4xi64> // diva.tensor linalg.add
%v123 = linalg.matmul ins(%v121, %v122 : tensor<2x3xi64>, tensor<3x2xi64>) outs(%v123_init : tensor<2x2xi64>) -> tensor<2x2xi64> // diva.tensor linalg.matmul
```

The `// diva.tensor` suffix marks operations whose surrounding buffer allocation and scalar
control flow are still partially lowered.

## Verification

```sh
DIVA_PURE_DRIVER=build/diva-compiler-pure-elf sh tests/linalg.sh
bash tests/tensor.sh
bash tests/mlir.sh
```

`tests/linalg.sh` checks runtime results, emitted Linalg text, rank-mismatch sema diagnostics, and
the matmul shape-mismatch trap.

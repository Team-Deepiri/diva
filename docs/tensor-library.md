# CPU tensor library (`std/tensor.diva`)

Pure-Diva CPU tensor helpers on top of the #112 tensor type, the #120 linalg
builtins, and the #99 `vec4` value type. No C/C++ sources are involved.

## Scope and limits

- Integer elements only (`int`). There is no `f32`/`f64` tensor support.
- Ranks 1 and 2 only. Higher ranks are deferred.
- Tensor shape dimensions are compile-time literals in Diva. The library therefore
  exposes fixed-shape helpers instead of a single variadic constructor:
  rank-1 length 4 (`tensor<int, 4>`), rank-1 length 6 (`tensor<int, 6>`),
  and rank-2 `2x2`, `2x3`, and `3x2`.
- `tensor_add` and `tensor_matmul` are language builtins (#120) and take priority
  over user functions with the same name. The module reuses them directly and
  exposes callable wrappers with explicit shape suffixes (`tensor_add4`,
  `tensor_matmul_2x2`, ...).
- No variadic functions and no function with 7 or more parameters. Constructors are
  fixed-arity; the widest takes six `int` values.
- `vec4` has no function parameters, returns, globals, arrays, or hardware SIMD
  instructions in the current compiler. The SIMD path below is the documented
  `vec4` **scalar fallback**: four lanes lowered as four scalar IR operations.
- The library keeps `vec4` values expression-local and passes only `int`/`tensor`
  arguments to helpers, matching the current vec4 ABI limits.
- Invalid fixed-shape arguments (`tensor_zeros` dimensions other than `2, 2`,
  `tensor_eye(n)` with `n != 2`, `tensor_zeros6(n)` with `n != 6`) call `exit(1)`.

## API

### Constructors

| Function | Result |
| --- | --- |
| `tensor_zeros(rows: int, cols: int): tensor<int, 2, 2>` | All-zero `2x2`; requires `rows == 2` and `cols == 2`. |
| `tensor_zeros6(n: int): tensor<int, 6>` | All-zero length-6 vector; requires `n == 6`. |
| `tensor_from_array4(a, b, c, d): tensor<int, 4>` | Rank-1 values `[a, b, c, d]`. |
| `tensor_from_array6(a, b, c, d, e, f): tensor<int, 6>` | Rank-1 values `[a, b, c, d, e, f]`. |
| `tensor_from_array2x2(a, b, c, d): tensor<int, 2, 2>` | Row-major `[[a, b], [c, d]]`. |
| `tensor_eye(n: int): tensor<int, 2, 2>` | `2x2` identity; requires `n == 2`. |

### Shape and rank-2 helpers

| Function | Result |
| --- | --- |
| `tensor_transpose(a: tensor<int, 2, 2>): tensor<int, 2, 2>` | Transpose of a square `2x2` tensor. |
| `tensor_transpose_2x3(a: tensor<int, 2, 3>): tensor<int, 3, 2>` | Rectangular transpose. |
| `tensor_add_2x2(a, b): tensor<int, 2, 2>` | Rank-2 elementwise add. |
| `tensor_sub_2x2(a, b): tensor<int, 2, 2>` | Rank-2 elementwise subtract. |
| `tensor_mul_elementwise_2x2(a, b): tensor<int, 2, 2>` | Rank-2 elementwise multiply. |
| `tensor_matmul_2x2(a, b): tensor<int, 2, 2>` | Wrapper over the `tensor_matmul` builtin. |
| `tensor_matmul_2x3(a: tensor<int, 2, 3>, b: tensor<int, 3, 2>): tensor<int, 2, 2>` | Rectangular matmul via the builtin. |
| `tensor_reduce_sum_2x2(a): int` | Sum of all four elements. |

### Rank-1 helpers

| Function | Result |
| --- | --- |
| `tensor_add4(a, b): tensor<int, 4>` | Wrapper over the `tensor_add` builtin. |
| `tensor_add6(a, b): tensor<int, 6>` | `vec4` add for the first four lanes, scalar tail for lanes 4 and 5. |
| `tensor_sub(a, b): tensor<int, 4>` | Scalar elementwise subtract. |
| `tensor_sub6(a, b): tensor<int, 6>` | Scalar elementwise subtract. |
| `tensor_mul_elementwise(a, b): tensor<int, 4>` | `vec4` lane-wise multiply. |
| `tensor_mul_elementwise6(a, b): tensor<int, 6>` | `vec4` multiply for four lanes, scalar tail for two. |
| `tensor_reduce_sum(a): int` | `vec4_sum` over a length-4 tensor. |
| `tensor_reduce_sum6(a): int` | `vec4_sum` for four lanes plus scalar tail. |

## SIMD path and scalar fallback

`tensor_add6`, `tensor_mul_elementwise`, `tensor_mul_elementwise6`, and
`tensor_reduce_sum6` load four consecutive `tensor_get` values into a `vec4`
expression, apply `+`, `*`, or `vec4_sum`, and write results with `tensor_set`.
Because the fixed shapes are length 6, a second `while` loop handles the two
remaining lanes with scalar arithmetic. This is the documented fallback for
tails and for lengths not divisible by four.

The compiler currently lowers each vec4 lane to ordinary scalar IR (`add`,
`mul`, `array.load`), so there is no AVX2/NEON code generation yet. The vec4
path is nevertheless the single source of lane-wise operations: changing the
`vec4` lowering later changes all of these helpers at once.

Rank-2 operations are deliberately scalar: a `2x2` row does not fill a four-lane
`vec4` naturally, and #120 already lowers `tensor_matmul` to scalar IR.

## Example

```diva
import "std/io.diva"
import "std/tensor.diva"

func main(): int {
    var a: tensor<int, 6> = tensor_from_array6(1, 2, 3, 4, 5, 6)
    var b: tensor<int, 6> = tensor_from_array6(10, 20, 30, 40, 50, 60)
    var c: tensor<int, 6> = tensor_add6(a, b)
    print_int(tensor_get(c, 5))
    print_int(tensor_reduce_sum6(c))
    return 0
}
```

Output: `66` and `231`.

## Verification

```sh
bash tests/tensorlib.sh
DIVA_TEST_FAST=1 timeout 1500 bash tests/run.sh
```

`tests/tensorlib.sh` checks constructors, eye, transpose (square and
rectangular), rank-1 and rank-2 elementwise ops, matmul (square and
rectangular), reductions, invalid-shape exits, and a repeated-operation
checksum benchmark. It also checks that the elementwise IR contains `mul` and
`array.load` from the vec4 path.

## Deferred

- Floating-point and mixed-dtype tensors.
- Dynamic shapes, rank 3+, broadcasting, views, and zero-copy slices.
- Hardware SIMD intrinsics, widths other than four, masks, and vector compare.
- `vec4` function parameters/returns and arrays of `vec4`.
- Fused multiply-add and NumPy-parity performance targets from issue #130.

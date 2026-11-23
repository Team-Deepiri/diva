# Tensor type (`tensor<T, shape>`)

Diva supports a minimal first-class tensor type for integer elements.

## Syntax

```diva
tensor<int, N>
tensor<int, N, M>
tensor<int, N> @cpu
tensor<int, N> @gpu
```

- `N` and `M` must be positive integer literals.
- Only `int` elements are supported.
- Rank 1 (`tensor<int, N>`) and rank 2 (`tensor<int, N, M>`) are supported. Higher ranks are deferred.
- `@cpu` and `@gpu` are accepted as syntactic device tags. `@gpu` is recorded in the tensor descriptor but GPU execution is not implemented; allocation and indexing run on the host.
- Omitting the device tag is equivalent to `@cpu`.

## Builtins

| Builtin | Description |
| --- | --- |
| `tensor_new(N)` | Allocate a rank-1 tensor with `N` elements. |
| `tensor_new(N, M)` | Allocate a rank-2 tensor with `N * M` elements. |
| `tensor_fill(V, N)` | Allocate a rank-1 tensor filled with `V`. |
| `tensor_fill(V, N, M)` | Allocate a rank-2 tensor filled with `V`. |
| `tensor_get(t, i)` | Read a rank-1 element. |
| `tensor_get(t, i, j)` | Read a rank-2 element. |
| `tensor_set(t, i, v)` | Write a rank-1 element. |
| `tensor_set(t, i, j, v)` | Write a rank-2 element. |
| `tensor_len(t)` | Return the total element count. |
| `tensor_rank(t)` | Return `1` or `2`. |

Rank-2 indexing is row-major: element `(i, j)` is stored at `i * M + j`.

## Errors

- Non-positive shape dimensions trap with `tensor: shape dimensions must be positive`.
- Out-of-bounds `tensor_get` traps with `tensor_get: index out of bounds`.
- Out-of-bounds `tensor_set` traps with `tensor_set: index out of bounds`.
- A shape rank mismatch between a declared tensor type and a constructor is a semantic error.
- Invalid device names and non-literal or non-positive shape dimensions are parse errors.

## Example

```diva
import "std/io.diva"

func main(): int {
    var t: tensor<int, 2, 3> = tensor_fill(7, 2, 3)
    tensor_set(t, 1, 2, 9)
    print_int(tensor_len(t))
    print_int(tensor_rank(t))
    print_int(tensor_get(t, 1, 2))
    return 0
}
```

# Kernel functions and launch (Issue #117)

Diva now has a source-level kernel abstraction. A kernel is an ordinary function
marked with `#[kernel]`; a host function schedules it with `launch`.

This is a **CPU fallback** implementation. It does not emit CUDA, SPIR-V, or any
GPU machine code. `launch` lowers to a descriptor passed to a generated host
stub, which loops over the grid/block on the CPU and calls the kernel directly.

## Syntax

```diva
#[kernel]
func fill(out: [int], base: int): void {
    var i = block_idx() * 2 + thread_idx()
    out[i] = base + i
}

func main(): int {
    var a: [int] = [0, 0, 0, 0]
    launch fill(grid: 2, block: 2, a, 10)
    return 0
}
```

- `#[kernel]` must immediately precede a top-level `func`.
- `launch name(grid: <expr>, block: <expr>, arg0, ...)` requires the `grid:` and
  `block:` labels in that order.
- `grid` and `block` must be `int` expressions; a trailing comma in the launch
  argument list is allowed.
- A kernel can take at most four explicit arguments. Two hidden `int`
  parameters (`block_idx`, then `thread_idx`) are appended by the compiler.
- Inside a kernel, `thread_idx()` and `block_idx()` take no arguments and return
  the current `int` index. Calling them outside a kernel is a sema error.
- Direct calls to a kernel are legal and pass zero for both hidden indices.

## Lowering

`launch` builds a descriptor on the stack:

```text
[fn_id, grid, block, arg_count, arg0, arg1, ...]
```

The generated `diva_kernel_launch(desc)` stub loops `block` in `0..grid-1` and
`thread` in `0..block-1`, dispatches on `fn_id`, and invokes the kernel with its
explicit arguments plus the hidden indices. Kernels are never inlined, so each
kernel remains a real function in the IR and native binary.

## Limits and deferred work

- No CUDA / SPIR-V / GPU target codegen; execution is honest CPU fallback.
- No asynchronous queues, streams, barriers, shared memory, or device memory.
- Grid/block values are ordinary `int` expressions; no target-specific limits
  are enforced beyond the native ABI argument cap.
- `break`/`continue` are not part of this surface; use flag variables.

Run the focused smoke suite with:

```sh
sh tests/gpu.sh
```

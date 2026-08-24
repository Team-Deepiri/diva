# Array indexing bounds (native pipeline)

## Layout

Fixed-length `int[]` locals are consecutive stack slots (8 bytes each). Const-index
access (`a[2]`) lowers to a plain `load`/`store` of slot `base+offset`. Dynamic
index access (`a[i]`) lowers to `array.load` / `array.store`, which compute
`rbp + base_disp - idx*8`.

## Bounds semantics

| Access | Compile time | Runtime |
|--------|--------------|---------|
| Const index in range | Emit load/store | None |
| Const index out of range / negative | Lower to `0` (read) or no-op (write) | None |
| Dynamic index | Always emit `array.load`/`array.store` | **Unchecked** — out-of-range is undefined (may corrupt stack) |

There is no length metadata in the generated binary today. Callers must keep
indices in `[0, len)`.

## Still out of scope

- Array literals outside `int[]` local initializers
- Heap / growable arrays
- Runtime bounds traps

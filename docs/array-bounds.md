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
| Dynamic index in range | Emit `array.load`/`array.store` | Check then access |
| Dynamic index out of range / negative | Emit check | **`exit(1)`** (syscall abort stub) |

Dynamic ops carry compile-time length in IR `extra` (arrays with length 1..127).
Longer arrays still load/store without the imm8 check (rare for the fixed-stack subset).

There is no length metadata object in the binary beyond that immediate.

## `flux` over arrays

`flux v in arr { … }` (local fixed `int[]` with length > 1) lowers to an index
loop `i in 0..len` with `v = arr[i]` via `array.load` (checked).

## Still out of scope

- Array literals outside `int[]` local initializers
- Heap / growable arrays
- `DIVA_BOUNDS=unchecked` opt-out (always trap today)
- `flux` over length-1 arrays (length `1` collides with scalar marker today)
- `flux` over globals / non-`int[]`

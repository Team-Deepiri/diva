# Array indexing bounds (native pipeline)

## Layout

Fixed-length array locals are consecutive stack slots (**8 bytes** each):

| Element kind | Stride (slots) | Notes |
|--------------|----------------|-------|
| `int` / `bool` / `str` | 1 | Value or pointer in one slot |
| Field-only struct / class | field count | `Point { x, y }` → stride 2; access via `arr[i].field` |

Const-index scalar access (`a[2]`) lowers to a plain `load`/`store` of slot
`base+offset`. Dynamic index access (`a[i]`) lowers to `array.load` /
`array.store`, which compute `rbp + base_disp - idx*8`.

Struct-element arrays use the same ops with a scaled offset
`idx * stride + field_index` (bounds against `nelem * stride`).

## Bounds semantics

| Access | Compile time | Runtime |
|--------|--------------|---------|
| Const index in range | Emit load/store | None |
| Const index out of range / negative | Lower to `0` (read) or no-op (write) | None |
| Dynamic index in range | Emit `array.load`/`array.store` | Check then access |
| Dynamic index out of range / negative | Emit check | **`exit(1)`** (syscall abort stub) |

Dynamic ops carry compile-time length in IR `extra` (slot count 1..127 for the
imm8 check). Longer arrays still load/store without the imm8 check (rare for the
fixed-stack subset).

There is no length metadata object in the binary beyond that immediate.

## `flux` over arrays

`flux v in arr { … }` (local fixed scalar-element array with length > 1, stride 1)
lowers to an index loop `i in 0..len` with `v = arr[i]` via `array.load` (checked).
Struct-element arrays are not flux targets yet (use indexed field access).

## Still out of scope

- Array literals outside typed local initializers
- Heap / growable arrays
- `DIVA_BOUNDS=unchecked` opt-out (always trap today)
- `flux` over length-1 arrays (length `1` collides with scalar marker today)
- `flux` over globals / struct-element arrays

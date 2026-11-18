# Integer width casts (#86)

Diva accepts the width names `i8`, `i16`, `i32`, `i64`, `u8`, `u16`, `u32`,
`u64`, `f32`, and `f64` as type annotations and as targets of `expr as Type`.
Values are still represented as one machine word (64-bit on x86-64); width
names do not allocate narrower storage. Casting changes the *value* in that
word through truncation followed by extension.

## Integer widths

Let `k` be the target width in bits. For `k < 64`, lowering emits:

1. `shl x, (64 - k)` — discards all bits above bit `k - 1`.
2. `sar y, (64 - k)` for signed targets, or `shr y, (64 - k)` for unsigned
   targets.

`ir_shr` is a logical (zero-filling) right shift. `ir_sar` (IR opcode 47) is
the arithmetic (sign-preserving) right shift added for signed narrowing. Both
code generators emit `shrq`/`sarq` respectively; the pure byte backend uses
`48 D3 E8` for `shr` and `48 D3 F8` for `sar`.

| Target     | Shift amount | Extension |
| ---------- | ------------ | --------- |
| `i8`/`u8`  | 56           | signed / zero |
| `i16`/`u16`| 48           | signed / zero |
| `i32`/`u32`| 32           | signed / zero |
| `i64`/`u64`| —            | identity (already a machine word) |

Examples:

```diva
(300 as i8)    // 44
(300 as u8)    // 44
((-1) as u8)   // 255
(200 as i8)    // -56
```

Casts are expressions, so they compose with operators: `(300 as i8) + 100`
is `144`. Assignment remains strict: crossing numeric/bool types still needs
an explicit `as`.

## Float widths

`f32` and `f64` remain identity casts: there is no floating-point
representation or IEEE conversion in the current backend. They are accepted
so source using these names compiles, but `(300 as f32) == 300`.

## Deferred

- Real IEEE-754 data representation and conversions for `f32`/`f64`.
- Storage-size/layout effects of width types in structs, arrays, and globals.
- Overflow/trap modes; narrowing currently wraps by truncation.

# Atomic memory builtins (Issue #98)

Diva exposes a small set of x86-64 atomic memory primitives as language builtins.
They are recognised by name, require no `extern` declaration, and are lowered to
dedicated IR opcodes rather than runtime calls.

## Signatures

```diva
atomic_load(p: *int): int
atomic_store(p: *int, v: int): void
atomic_add(p: *int, v: int): int   // returns the OLD value
atomic_xchg(p: *int, v: int): int  // returns the OLD value
atomic_cas(p: *int, expected: int, desired: int): int // 1 on success, 0 on failure
fence(): void
```

All six operations are unsafe: they must appear inside an `unsafe { ... }`
block. Calling one outside that context is a sema error:

```
sema: atomic operation requires an unsafe block
```

The pointer argument must be a raw pointer (`*int`); value arguments must be
integers.

## Example

```diva
func main(): int {
    let x: int = 10;
    let old: int = 0;
    unsafe {
        old = atomic_add(&x, 5);
    }
    // old == 10, x == 15
    if old == 10 {
        if x == 15 { return 42; }
    }
    return 7;
}
```

## Semantics

- `atomic_load` / `atomic_store` are aligned 64-bit loads/stores. On x86-64 an
  aligned `mov` is atomic.
- `atomic_add` uses `lock xadd`, so the memory location receives `old + v` and
  the return value is `old`.
- `atomic_xchg` uses `xchg` with a memory operand (implicitly atomic on x86-64),
  storing `v` and returning `old`.
- `atomic_cas` uses `lock cmpxchg`: it compares the pointed-to value with
  `expected`, stores `desired` on success, and returns `1` for success or `0`
  for failure.
- `fence()` emits `mfence`.

Only caller-saved scratch registers (`%rax`, `%rdx`, `%rcx`) are used, so the
SysV ABI is preserved.

## Backends

Both code generation paths emit the real instructions:

| Opcode          | Text backend (`diva asm`) | Byte backend (`diva build`) |
| --------------- | ------------------------- | --------------------------- |
| `atomic.load`   | `movq (%rax), %rdx`       | `48 8b 10`                  |
| `atomic.store`  | `movq %rdx, (%rax)`       | `48 89 10`                  |
| `atomic.add`    | `lock xaddq %rdx, (%rax)` | `f0 48 0f c1 10`            |
| `atomic.xchg`   | `xchgq %rdx, (%rax)`      | `48 87 10`                  |
| `atomic.cas`    | `lock cmpxchgq %rcx, (%rdx)` | `f0 48 0f b1 0a`         |
| `fence`         | `mfence`                  | `0f ae f0`                  |

## Tests

Run the dedicated suite with:

```sh
sh tests/atomics.sh
```

It checks single-threaded semantics, the unsafe requirement, IR lowering, and
the emitted assembly text.

## Deferred

Thread creation, scheduling, and higher-level synchronization abstractions
(mutex/condvar) are not part of this foundation.

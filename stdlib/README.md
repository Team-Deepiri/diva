# Diva Standard Library

Shipped as real Diva modules under `stdlib/std/`. Logical package map for SDK
consumers: **`docs/stdlib-packages.md`** (Issue #28).

## Layers (quick)

| Package | Import examples |
|---------|-----------------|
| core | `std/core.diva`, `std/assert.diva`, `std/math.diva`, `std/logic.diva` |
| mem | `std/mem.diva` — `mem_*`, `int_buf_*` (`docs/heap-mem.md`) |
| io | `std/io.diva`, `std/fmt.diva` |
| str | `std/str.diva`, `std/vec.diva` |
| math | `std/math.diva`, `std/random.diva` |
| collections | `std/collections.diva` (IntBuf), `std/stack.diva`, `std/queue.diva` |
| iter | `std/iter.diva`, `std/range.diva` |
| os | `std/os.diva`, `std/fs.diva`, `std/path.diva` |

## Usage

```di
import "std/mem.diva"
import "std/collections.diva"
import "std/iter.diva"

func main(): int {
    var b = IntBuf_new()
    IntBuf_push(b, 10)
    IntBuf_push(b, 20)
    // int_buf_sum → 30
    IntBuf_free(b)
    return 0
}
```

Example: `examples/stdlib_packages.diva` → `35\n20\n10`.

The install scripts copy `stdlib/` alongside the compiler so `import "std/..."` works from user projects.

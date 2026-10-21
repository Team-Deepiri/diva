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
| collections | `std/collections.diva` (IntBuf), `std/stack.diva`, `std/queue.diva`, `std/map.diva`, `std/table.diva`, `std/kv.diva` (str→str key/value store) |
| iter | `std/iter.diva`, `std/range.diva` |
| os | `std/os.diva`, `std/fs.diva`, `std/path.diva` |
| option/result | `std/option.diva` (`Option[T]`), `std/result.diva` (`Result[T, E]`) |

Phase 1 (Issue #93): enum values lower to their `int` tag, so the accessors
below read the tag rather than carried payloads. See `docs/language-spec.md`
("Enums") for the supported surface and limitations.

- `std/option.diva` — `Option[T] { None, Some(T) }`;
  `option_tag`, `option_is_some`, `option_is_none`, `option_unwrap`,
  `option_unwrap_or`, `option_unwrap_str`
- `std/result.diva` — `Result[T, E] { Ok(T), Err(E) }`;
  `result_tag`, `result_is_ok`, `result_is_err`, `result_unwrap`,
  `result_unwrap_err`, `result_unwrap_or`, `result_unwrap_str`,
  `result_unwrap_err_str`

Both modules `import "std/mem.diva"`. Covered by `tests/optres.sh`.

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

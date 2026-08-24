# Diva Standard Library

The standard library starts small on purpose, but it is now shipped as real `Diva` modules.

Available modules:

- `std/math.diva`: `abs`, `max`, `min`, `clamp`
- `std/logic.diva`: `all`, `any`, `bool_to_int`
- `std/range.diva`: `sum_range`, `count_range`, `contains_range`
- `std/io.diva`: `stdout`, `stderr`, `print_bool`, `panic`
- `std/int.diva`: `sign`, `is_even`, `is_odd`, `gcd`
- `std/assert.diva`: `assert_true`, `assert_eq_int`
- `std/mem.diva`: `mem_alloc` / `mem_free` / `mem_get` / `mem_set` and growable `int_buf_*` (see `docs/heap-mem.md`)

Usage:

```di
import "std/math.diva"
import "std/range.diva"
import "std/io.diva"

func main(): int {
    print_int(sum_range(0, 5))
    print_int(clamp(99, 0, 10))
    print_hex(stdout("ok"))
    return 0
}
```

The install scripts copy `stdlib/` alongside the compiler so `import "std/..."` works from user projects.

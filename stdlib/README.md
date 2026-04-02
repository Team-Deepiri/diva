# Di Standard Library

The standard library starts small on purpose, but it is now shipped as real `Di` modules.

Available modules:

- `std/math.di`: `abs`, `max`, `min`, `clamp`
- `std/logic.di`: `all`, `any`, `bool_to_int`
- `std/range.di`: `sum_range`, `count_range`, `contains_range`
- `std/io.di`: `stdout`, `stderr`, `print_bool`, `panic`
- `std/int.di`: `sign`, `is_even`, `is_odd`, `gcd`
- `std/assert.di`: `assert_true`, `assert_eq_int`
- `std/host.di`: `host_argc`, `host_argv`, `read_file`, `file_size`, `str_len`, `str_byte` (hosted runtime; see `docs/selfhost-bootstrap.md`)
- `std/vec.di`: `int_vec_*`, `str_builder_*` (dynamic structures for self-hosting; see `docs/selfhost-bootstrap.md`)

Usage:

```di
import "std/math.di"
import "std/range.di"
import "std/io.di"

func main(): int {
    print_int(sum_range(0, 5))
    print_int(clamp(99, 0, 10))
    print_hex(stdout("ok"))
    return 0
}
```

The install scripts copy `stdlib/` alongside the compiler so `import "std/..."` works from user projects.

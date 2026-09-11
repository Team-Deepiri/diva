# Stdlib package boundaries (Issue #28)

Stable import surface for SDK consumers. Paths stay under `stdlib/std/*.diva`
(`import "std/…"`); the table below is the **logical** package map.

| Package | Role | Modules today |
|---------|------|----------------|
| **core** | Primitives, asserts, conversion | `core`, `assert`, `conv`, `logic`, `int`, `char`, `bitwise` |
| **mem** | Heap + growable buffers (pure ELF) | `mem` (`mem_*`, `int_buf_*`) — see `docs/heap-mem.md` |
| **io** | Print / panic / streams | `io`, `fmt`, `log`, `color` |
| **str** | String helpers + builders | `str`, `vec` (`str_builder_*`), `pattern`, `hex`, `base64` |
| **math** | Numeric helpers | `math`, `random`, `matrix` |
| **collections** | Growable containers | `collections` (IntBuf on `int_buf_*`), `vec` (`int_vec_*`), `stack`, `queue`, `map`, `table`, `sort` — `IntBuf_min` / `int_buf_min` |
| **iter** | Range / fold helpers | `iter`, `range`, `algo` |
| **os** | Process / env / files | `os`, `host`, `fs`, `path`, `args`, `process`, `syscall_linux` |

## Rules

1. **Higher-level code is Diva** — new helpers go in `.diva` modules above; only syscall/blob hooks stay as `extern` (host/mem builtins).
2. **Do not import the reverse of the layering** — e.g. `mem` must not import `collections`; `os` may use `io`/`str` but not the reverse for package-stable APIs.
3. **Prefer package names in docs** (`std/mem`, `std/iter`) even while files remain flat under `std/`.
4. **Kernel / freestanding** may omit `os` and hosted `host_*`; `mem` + `core` remain the portable floor.

## Example

```di
import "std/mem.diva"
import "std/collections.diva"
import "std/iter.diva"
import "std/io.diva"

func main(): int {
    var b = int_buf_new()
    int_buf_push(b, 10)
    int_buf_push(b, 20)
    print_int(int_buf_sum(b))
    int_buf_free(b)
    return 0
}
```

See `examples/stdlib_packages.diva`.

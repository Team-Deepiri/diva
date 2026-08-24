# User heap (`mem_*`) — Issue #62

Pure-ELF programs can allocate beyond fixed stack slots via mmap-backed builtins:

| Extern | Role |
|--------|------|
| `mem_alloc(nbytes)` | Page-rounded map; returns user pointer (`int`) or `0` |
| `mem_free(ptr)` | `munmap` using a hidden size header |
| `mem_get(ptr, i)` / `mem_set(ptr, i, v)` | 8-byte slot load/store at `ptr[i]` |

Wrappers and a growable int buffer live in `stdlib/std/mem.diva` (`int_buf_*`).
See that file for lifetime rules. Example: `examples/heap_buf.diva`.

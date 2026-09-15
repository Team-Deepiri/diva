# Leave-off — AST bump arena (2026-08-05)

**Parent:** PR #12/#13. **This PR:** AST arena.

**Self-host:** yes — seed promoted to arena fixed point (`bootstrap/diva-linux-amd64`).

## Finding

The string arena cut RSS 28 GiB → ~567 MiB, but ~135k live 4 KiB `int_vec` AST pages were
still a ~0.5 GiB floor. Every AST node constructor calls `int_vec_new()` → one `mmap` per node.

## Fix

Packed bump arena at `0x540000000000` (2 GiB) in `pure_int_vec_new` / `pure_int_vec_push` /
`pure_int_vec_free`:

- Fixed 128-byte slots (`cap = 13` ints); `map_bytes == 0` marks an arena slot.
- `push` promotes a full arena slot to a 4 KiB `mmap` (copy header + payload, update handle
  table), then continues with the normal `mremap` growth path.
- `free` skips `munmap` for arena slots (process-lifetime arena).
- Falls back to a plain 4 KiB `mmap` if the arena is exhausted.

## Result

| Metric | Before | After |
|--------|--------|-------|
| Max RSS full `build compiler/` | ~567 MiB | **~168 MiB** |
| stage2≡stage3 | — | `c0620891…` |
| arena map at `0x540000000000` | absent | live |

## Residual

- Arena slots are process-lifetime (no reuse); a free-list would help pathological churn.
- The fallback 4 KiB `mmap` path (past 2 GiB of live AST) is untested at scale.
- Optional micro-opt: skip per-call `FIXED_NOREPLACE` probes now that HT/arena are live.

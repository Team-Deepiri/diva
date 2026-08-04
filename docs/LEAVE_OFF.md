# Leave-off — pure ELF self-host (2026-08-04)

## Done

| Gate | Result |
|------|--------|
| Second + third-stage pure self-host | green; stage2≡stage3 (`md5 455fe3e8…`) |
| No `DIVA_SKIP_NATIVE_EXTERN_CHECK` on seed | `check` / tiny / full `build compiler/` green |
| `verify-pure-only` + `DIVA_PURE_FULL=1` | OK |
| `tests/run-strict-pure.sh` on seed | **21/21 OK** (outs under `build/`, not `/tmp`) |
| Seed | `bootstrap/diva-linux-amd64` ← stage2 pure |

## Fixes this arc

1. Inlined `ret` in unlink/chmod → SIGSEGV  
2. CLI out path (no `/tmp` keepers)  
3. `write_elf_chunk` save `is_first` across mmap (was 4608-byte junk)  
4. **strict-pure** writes/runs via `build/strict-pure-exe`  
5. **cc-link** default SEED → hosted `bak-before-retfix-*` (avoids full-asm SEGV)  
6. **abort-on-full** for pure `int_vec_push` / `str_builder_append` (`exit_group(2)`) — sizes **42→54**, **115→127** (needs stage2→pure rebuild to land in seed)

## Hosted stage2 full-`asm` SEGV (root-caused)

`build/diva-stage2-from-cc asm merged.diva` dies in glibc **`__vsnprintf_internal`** via `di_runtime_int_to_str` during `cg_module_to_str` / `cmd_asm` (large module). Not a pure-ELF bug. **Workaround:** bak SEED (now default in `scripts/legacy/build-compiler-cc-link.sh`). Fix later in hosted `int_to_str` / buffer sizing.

## Realloc note

Moving `mremap` is **unsafe** while handles are raw mmap pointers (stale refs after move). Needs a stable handle table first. Until then: 16 MiB fixed mmap + **abort-on-full** (no silent skip).

## Rebuild after emit/size edits

```sh
# sizes + emits must both be saved before starting
SEED=…bak-before-retfix… ASM_TIMEOUT_SECS=7200 \
  sh scripts/legacy/build-compiler-cc-link.sh build/diva-stage2-from-cc-new
# (SEED now auto-picks bak if unset)
set -o pipefail
ROOT_DIR=$PWD DI_STDLIB_DIR=$PWD/stdlib DIVA_NO_EXTERNAL=1 \
  ./build/diva-stage2-from-cc build compiler/ $PWD/build/diva-compiler-pure-elf
./build/diva-compiler-pure-elf build compiler/ $PWD/build/diva-compiler-pure-elf-stage2
cp -a build/diva-compiler-pure-elf-stage2 bootstrap/diva-linux-amd64
```

## Do next

1. **Rebuild + promote** so abort-on-full (54/127) is in the seed.  
2. Fix hosted **`di_runtime_int_to_str` / asm SEGV** on large modules.  
3. **Handle-table realloc** for pure vec/builder (real grow).  
4. Broader CI beyond strict-pure list.

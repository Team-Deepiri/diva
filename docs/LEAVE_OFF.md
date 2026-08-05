# Leave-off — pure ELF self-host (2026-08-04)

## Done

| Gate | Result |
|------|--------|
| Second + third-stage pure self-host | green; stage2≡stage3 (`md5 455fe3e8…`) |
| No `DIVA_SKIP_NATIVE_EXTERN_CHECK` on seed | `check` / tiny / full `build compiler/` green |
| `verify-pure-only` + `DIVA_PURE_FULL=1` | OK |
| `tests/run-strict-pure.sh` on seed | **21/21 OK** (outs under `build/`, not `/tmp`) |
| Seed | `bootstrap/diva-linux-amd64` ← stage2 pure (**abort-on-full** landed; ~750KiB) |
| Hosted full-package `asm` | **fixed** — ring-buffer `di_runtime_int_to_str` (no malloc, no snprintf) |


## Fixes this arc

1. Inlined `ret` in unlink/chmod → SIGSEGV  
2. CLI out path (no `/tmp` keepers)  
3. `write_elf_chunk` save `is_first` across mmap (was 4608-byte junk)  
4. **strict-pure** writes/runs via `build/strict-pure-exe`  
5. **cc-link** default SEED → hosted `bak-before-retfix-*` (safe seed while rebuilding)  
6. **abort-on-full** for pure `int_vec_push` / `str_builder_append` (`exit_group(2)`) — sizes **42→54**, **115→127** — **in seed** after 2026-08-04 promote  
7. **Hosted `int_to_str` leak** — stock `runtime.o` malloc'd 32B/`%d` per call and never freed; millions of calls in `cg_module_to_str` died in glibc snprintf. Fix: `compiler/res/legacy/runtime_int_to_str.c` (8×32 ring, hand digit convert) + `objcopy --weaken-symbol` in `build-compiler-cc-link.sh`. Verified: stage2 `asm merged.diva` → ~2.2MiB `.s`, exit 0.


## Hosted stage2 full-`asm` SEGV (fixed)

Was: `di_runtime_int_to_str` → malloc leak + snprintf crash mid-`cmd_asm`.  
Now: link override wins over weakened stock symbol. Asm-only BSS override still hit snprintf; C digit path is the keeper.

## Realloc note

Moving `mremap` is **unsafe** while handles are raw mmap pointers (stale refs after move). Needs a stable handle table first. Until then: 16 MiB fixed mmap + **abort-on-full** (no silent skip).

## Rebuild after emit/size edits

```sh
# sizes + emits must both be saved before starting
ASM_TIMEOUT_SECS=7200 \
  sh scripts/legacy/build-compiler-cc-link.sh build/diva-stage2-from-cc
# (SEED auto-picks bak if unset; new link includes int_to_str override)
set -o pipefail
ROOT_DIR=$PWD DI_STDLIB_DIR=$PWD/stdlib DIVA_NO_EXTERNAL=1 \
  ./build/diva-stage2-from-cc build compiler/ $PWD/build/diva-compiler-pure-elf
./build/diva-compiler-pure-elf build compiler/ $PWD/build/diva-compiler-pure-elf-stage2
cp -a build/diva-compiler-pure-elf-stage2 bootstrap/diva-linux-amd64
```

## Do next

1. ~~Fix hosted stage2 `asm` SEGV~~ — done on this branch.  
2. **Handle-table realloc** for pure vec/builder (real grow).  
3. More CI beyond `tests/strict-pure.list`.

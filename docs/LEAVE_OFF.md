# Leave-off — grow INIT RSS (2026-08-04)

**Parent:** PR #12. **This PR:** #13.

## Finding

64 KiB init still ~**27 GiB** RSS — hundreds of thousands of live tiny AST `int_vec`s each own a full mmap. Need **page-sized (4 KiB)** init: ~400k × 4 KiB ≈ 1.6 GiB upper bound if all stay small.

## Status

| Step | Result |
|------|--------|
| INIT 1 MiB → 64 KiB | verified stage2≡stage3; RSS still ~27 GiB |
| INIT → **4 KiB** (`0x1000`) | sources + math + smoke green |
| stage2 rebuild / RSS / seed | in progress |

## Rebuild

```sh
ASM_TIMEOUT_SECS=7200 sh scripts/legacy/build-compiler-cc-link.sh build/diva-stage2-grow
ROOT_DIR=$PWD DI_STDLIB_DIR=$PWD/stdlib DIVA_NO_EXTERNAL=1 \
  ./build/diva-stage2-grow build compiler/ $PWD/build/diva-compiler-pure-elf-grow
/usr/bin/time -v ./build/diva-compiler-pure-elf-grow build compiler/ $PWD/build/diva-compiler-pure-elf-grow-stage2
# Max RSS should be ≪ 28GiB; md5 stage2≡stage3; promote seed
```

# Leave-off — grow INIT RSS (2026-08-04)

**Parent:** PR #12 handle-table grow seed.

## Goal

Cut ~28 GiB peak RSS on full `build compiler/` by shrinking initial object mmap **1 MiB → 64 KiB** (still doubles via mremap).

## Status

| Step | Result |
|------|--------|
| INIT_BYTES = `0x10000` in `pure_*_new.s` | done |
| emit + `check-pure-mmap-math` | green |
| smoke grow | green |
| stage2 rebuild / stage2≡stage3 / RSS | in progress |
| seed promote | pending verify |

## Rebuild

```sh
ASM_TIMEOUT_SECS=7200 sh scripts/legacy/build-compiler-cc-link.sh build/diva-stage2-grow
ROOT_DIR=$PWD DI_STDLIB_DIR=$PWD/stdlib DIVA_NO_EXTERNAL=1 \
  ./build/diva-stage2-grow build compiler/ $PWD/build/diva-compiler-pure-elf-grow
./build/diva-compiler-pure-elf-grow build compiler/ $PWD/build/diva-compiler-pure-elf-grow-stage2
# compare md5; /usr/bin/time -v for Max RSS
cp -a build/diva-compiler-pure-elf-grow-stage2 bootstrap/diva-linux-amd64
```

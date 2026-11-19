# Incremental build cache (issue #115)

`diva build <src> <out>` caches a successfully built executable in `.diva-cache/`
beside `<out>`. The cache key is a 64-bit FNV-1a hash over:

1. the bytes of every transitively imported source file, in the same order the
   loader merges them (dependencies first, entry last);
2. the compiler version or build id (`DIVA_BUILD_ID`, then
   `DIVA_COMPILER_VERSION`, then the built-in `diva-v0.5.0`);
3. the debug-build flag, so `-g` and non-`-g` outputs cannot collide.

The output path is deliberately not part of the key. Rebuilding the same sources
to a different path in the same directory reuses the same entry.

## Layout

```text
<out-dir>/.diva-cache/<hash>.bin    executable copy of the built program
<out-dir>/.diva-cache/<hash>.meta   hash, version, and ordered source list
```

On a hit, the cached binary is copied to `<out>` with its executable bit set and
`[cache] hit <hash>` is written to stderr. On a miss, the compiler builds
normally, stores the binary and metadata, and writes `[cache] miss <hash>` to
stderr. Failed builds are not stored.

## Bypass

Either of these disables cache reads and writes for a build:

```sh
diva build src/main.diva out/app --no-cache
DIVA_NO_CACHE=1 diva build src/main.diva out/app
```

`build --ast` and `watch` do not use this cache.

## Verification

```sh
DI_STDLIB_DIR=$PWD/stdlib DIVA_NO_EXTERNAL=1 \
DI_RUNTIME_O=$PWD/bootstrap/runtime-linux-amd64.o \
./bootstrap/diva-linux-amd64 build "$PWD/compiler" /tmp/opencode/drv-inc

DIVA=/tmp/opencode/drv-inc bash tests/incremental.sh
```

## Deferred

Per-function or per-module invalidation is not implemented. Any change to any
transitive source invalidates the whole program key and triggers one full
rebuild; the cache stores whole executables, not compilation units.

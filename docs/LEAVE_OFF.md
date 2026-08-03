# Leave-off: pure-only driver and full self-host bootstrap

## What was wrong

1. **64 KiB mmap** for pure `int_vec` / `str_builder` — silent overflow on merged `compiler/` (~285 KiB).
2. **4 MiB still too small for self-build** — codegen stores **one machine-code byte per int_vec slot**. Full compiler pure ELF is ~700 KiB+ of code → needs >700k slots. At 4 MiB, qword cap is only `0x7fffd` (~524k); `int_vec_push` fails silently → `ir_br_cond size mismatch expected=21 got=0`.
3. Brief **str_builder** mis-encode: cap `0x3ffff8` (= mmap−8) instead of mmap−24.

## What changed

Raised pure mmap to **16 MiB** (`0x1000000`) in `emit_pure_int_vec_new_*` / `emit_pure_str_builder_new_*`:

| Buffer | Cap | Exact fit |
|--------|-----|-----------|
| `int_vec` | `(0x1000000−24)/8 = 0x1ffffd` qwords | `H + 8·cap = mmap` |
| `str_builder` | `0x1000000−24 = 0xffffe8` bytes | `H + cap = mmap` |

Blob size for builtins **9** / **14** still **96** bytes. Static check: `python3 scripts/check-pure-mmap-math.py`.

## Rebuild + promote (self-sustainable seed)

Hosted `build/diva-stage2-from-cc` compiles **source** (including the new imm32s) into the pure ELF — no need to re-cc-link stage2 after mmap-only edits.

```sh
# 1) math
python3 scripts/check-pure-mmap-math.py

# 2) pure driver from hosted stage2
DIVA_SKIP_NATIVE_EXTERN_CHECK=1 DIVA_NO_EXTERNAL=1 \
  ./build/diva-stage2-from-cc build compiler/ /tmp/diva-native-exe

# 3) smoke + package check
DIVA_PURE_DRIVER=/tmp/diva-native-exe ./scripts/verify-pure-only-driver.sh
ROOT_DIR="$PWD" DI_STDLIB_DIR="$PWD/stdlib" /tmp/diva-native-exe check compiler/

# 4) second-stage: pure rebuilds itself (the real gate)
DIVA_SKIP_NATIVE_EXTERN_CHECK=1 DIVA_NO_EXTERNAL=1 \
  /tmp/diva-native-exe build compiler/ /tmp/diva-native-exe-stage2

# 5) promote converged binary
cp -a /tmp/diva-native-exe-stage2 bootstrap/diva-linux-amd64
# or: ./scripts/promote-bootstrap-seed.sh
```

## Follow-ups

- Real **reallocation** in push/append (stop fixed mmap caps).
- Clear `DIVA_SKIP_NATIVE_EXTERN_CHECK` once seed lists every pure extern.
- `DIVA_PURE_FULL=1 ./scripts/verify-pure-only-driver.sh` when ret-to-0 / ir pipeline is green.

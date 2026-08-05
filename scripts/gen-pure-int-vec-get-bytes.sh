#!/usr/bin/env bash
# Regenerate the decimal byte list for emit_pure_int_vec_get in pure_elf_builtins.diva
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="$ROOT/compiler/res/pure_int_vec_get.s"
TMP=$(mktemp)
trap 'rm -f "$TMP" "$TMP.bin"' EXIT
as --64 -o "$TMP" "$SRC"
objcopy -O binary -j .text "$TMP" "$TMP.bin"
python3 - <<'PY'
import sys
p = sys.argv[1]
data = open(p, 'rb').read()
for i, b in enumerate(data):
    if i % 10 == 0:
        print()
        print('    ', end='')
    print(b, end='')
    if i + 1 < len(data):
        print(' ', end='')
print()
print(f'# len={len(data)}', file=sys.stderr)
PY
"$TMP.bin"

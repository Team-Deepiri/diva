#!/usr/bin/env bash
# Issue #63: diva build -g + addr2line resolves entry VA.
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
export ROOT_DIR DI_STDLIB_DIR="${DI_STDLIB_DIR:-$ROOT_DIR/stdlib}"
DIVA="${DIVA:-$ROOT_DIR/bootstrap/diva-linux-amd64}"
OUT="${TMPDIR:-/tmp}/diva-dwarf-smoke-$$"
trap 'rm -f "$OUT"' EXIT

export DIVA_NATIVE_EXE_OUT="$OUT"
"$DIVA" build "$ROOT_DIR/examples/hello.diva" -g >/tmp/diva-dwarf-build.out 2>&1 || {
  echo "dwarf smoke: build -g failed" >&2
  cat /tmp/diva-dwarf-build.out >&2
  exit 1
}
readelf -S "$OUT" | grep -q '\.debug_line' || {
  echo "dwarf smoke: missing .debug_line" >&2
  readelf -S "$OUT" >&2
  exit 1
}
# Non -g must not grow section table (spot-check: build without -g has no .debug_line)
OUT2="${OUT}.nodbg"
export DIVA_NATIVE_EXE_OUT="$OUT2"
"$DIVA" build "$ROOT_DIR/examples/hello.diva" >/tmp/diva-dwarf-nodbg.out 2>&1
if readelf -S "$OUT2" 2>/dev/null | grep -q '\.debug_line'; then
  echo "dwarf smoke: non -g unexpectedly has .debug_line" >&2
  exit 1
fi
rm -f "$OUT2"

LINE="$(addr2line -e "$OUT" 0x1000)"
echo "addr2line 0x1000 -> $LINE"
case "$LINE" in
  *hello.diva:*) ;;
  *)
    echo "dwarf smoke: expected hello.diva:N, got: $LINE" >&2
    exit 1
    ;;
esac
echo "dwarf smoke: ok"

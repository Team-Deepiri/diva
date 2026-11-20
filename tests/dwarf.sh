#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/diva-dwarf-XXXXXX")"
trap 'rm -rf "$TMP_DIR"' EXIT
if [ -n "${DIVA:-}" ]; then
    DRIVER="$DIVA"
elif [ -x "${ROOT_DIR}/build/diva-compiler-pure-elf" ]; then
    DRIVER="${ROOT_DIR}/build/diva-compiler-pure-elf"
else
    DRIVER="$TMP_DIR/driver"
    echo "[dwarf] building driver from bootstrap seed"
    if ! ROOT_DIR="${ROOT_DIR}" DI_STDLIB_DIR="${ROOT_DIR}/stdlib" DIVA_NO_EXTERNAL=1 \
        DI_RUNTIME_O="${ROOT_DIR}/bootstrap/runtime-linux-amd64.o" \
        timeout 1200 "${ROOT_DIR}/bootstrap/diva-linux-amd64" build "${ROOT_DIR}/compiler" "${DRIVER}" \
        >"$TMP_DIR/driver-build.log" 2>&1; then
        sed -n '1,80p' "$TMP_DIR/driver-build.log" >&2
        exit 1
    fi
fi
SRC="$TMP_DIR/dwarf_line.diva"
OUT="$TMP_DIR/dwarf_line"
cat >"$SRC" <<'DIVA'
extern func print_int(x: int): void

func main(): int {
    print_int(114)
    return 0
}
DIVA
export DI_STDLIB_DIR="${DI_STDLIB_DIR:-$ROOT_DIR/stdlib}"
export DIVA_NO_EXTERNAL=1
export DI_RUNTIME_O="${DI_RUNTIME_O:-$ROOT_DIR/bootstrap/runtime-linux-amd64.o}"
export DIVA_NATIVE_EXE_OUT="$OUT"
"$DRIVER" build "$SRC" --debug-info >"$TMP_DIR/build.out" 2>"$TMP_DIR/build.err"
grep -q "DWARF line tables enabled" "$TMP_DIR/build.err"
"$OUT" >"$TMP_DIR/run.out"
grep -q '^114$' "$TMP_DIR/run.out"
MAIN_LINE="$(grep -n '^func main' "$SRC" | cut -d: -f1)"
if command -v readelf >/dev/null 2>&1; then
    readelf -S "$OUT" >"$TMP_DIR/sections.txt"
    grep -q '\.debug_line' "$TMP_DIR/sections.txt"
    readelf --debug-dump=decodedline "$OUT" >"$TMP_DIR/lines.txt" 2>&1
    grep -q 'dwarf_line.diva' "$TMP_DIR/lines.txt"
    awk -v want="$MAIN_LINE" '$2 == want { found = 1 } END { exit(found ? 0 : 1) }' "$TMP_DIR/lines.txt"
else
    grep -a -q '\.debug_line' "$OUT"
fi
echo "dwarf line-table test: ok"

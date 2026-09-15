#!/usr/bin/env bash
# Smoke: one poll cycle exits; then a rebuild cycle after a touch.
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
export ROOT_DIR
export DI_STDLIB_DIR="${DI_STDLIB_DIR:-$ROOT_DIR/stdlib}"
DIVA="${DIVA:-$ROOT_DIR/bootstrap/diva-linux-amd64}"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

mkdir -p "$TMP/pkg/src"
cat >"$TMP/pkg/package.diva" <<'EOF'
name = "watch_smoke"
kind = "app"
entry = "src/main.diva"
EOF
cat >"$TMP/pkg/src/main.diva" <<'EOF'
func main(): int {
    return 1
}
EOF

export DIVA_NATIVE_EXE_OUT="$TMP/out"
export DIVA_WATCH_MAX_ITERS=1
LOG1="$TMP/log1.txt"
if ! "$DIVA" watch "$TMP/pkg" >"$LOG1" 2>&1; then
  echo "watch smoke: initial MAX_ITERS=1 failed" >&2
  cat "$LOG1" >&2
  exit 1
fi
grep -q '\[watch\] ok' "$LOG1" || { echo "missing ok line"; cat "$LOG1"; exit 1; }
grep -q 'max iters reached' "$LOG1" || { echo "missing max iters"; cat "$LOG1"; exit 1; }

# Rebuild cycle: touch after watcher starts (background), expect change detected.
export DIVA_WATCH_MAX_ITERS=5
LOG2="$TMP/log2.txt"
"$DIVA" watch "$TMP/pkg" >"$LOG2" 2>&1 &
WPID=$!
sleep 1.5
printf '%s\n' 'func main(): int { return 2 }' >"$TMP/pkg/src/main.diva"
wait "$WPID" || true
if ! grep -q 'change detected' "$LOG2"; then
  echo "watch smoke: expected rebuild after touch" >&2
  cat "$LOG2" >&2
  exit 1
fi
grep -q '\[watch\] ok' "$LOG2" || { echo "missing rebuild ok"; cat "$LOG2"; exit 1; }
echo "watch smoke: ok"

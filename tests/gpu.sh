#!/usr/bin/env sh
# Issue #117: kernel functions + launch syntax (CPU fallback).
#
# Self-contained: with no DIVA_PURE_DRIVER set, builds a fresh driver from the
# bootstrap seed. Checks runtime behavior, stub emission, and sema negatives.
#
# Usage (repo root):
#   sh tests/gpu.sh
# Optional: DIVA_PURE_DRIVER=/path/to/diva to pin a specific driver.
set -eu

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "${ROOT_DIR}"

WORK="$(mktemp -d "${TMPDIR:-/tmp}/diva-gpu.XXXXXX")"
trap 'rm -rf "${WORK}"' EXIT

if [ -n "${DIVA_PURE_DRIVER:-}" ] && [ -x "${DIVA_PURE_DRIVER}" ]; then
  DRIVER="${DIVA_PURE_DRIVER}"
else
  DRIVER="${WORK}/driver"
  echo "[gpu] building driver from bootstrap seed"
  if ! ROOT_DIR="${ROOT_DIR}" DI_STDLIB_DIR="${ROOT_DIR}/stdlib" DIVA_NO_EXTERNAL=1 \
       DI_RUNTIME_O="${ROOT_DIR}/bootstrap/runtime-linux-amd64.o" \
       timeout 300 "${ROOT_DIR}/bootstrap/diva-linux-amd64" build compiler "${DRIVER}" \
       >"${WORK}/driver-build.log" 2>&1; then
    sed -n '1,40p' "${WORK}/driver-build.log" >&2
    echo "[gpu] driver build failed" >&2
    exit 1
  fi
fi

echo "[gpu] DRIVER=${DRIVER}"

total=0
failed=0
fail() {
  failed=$((failed + 1))
  echo "[gpu] FAIL $1" >&2
}

build_env() {
  ROOT_DIR="${ROOT_DIR}" DI_STDLIB_DIR="${ROOT_DIR}/stdlib" DIVA_NO_EXTERNAL=1 \
    DI_RUNTIME_O="${ROOT_DIR}/bootstrap/runtime-linux-amd64.o" "$@"
}

cat >"${WORK}/smoke.diva" <<'EOF'
import "std/io.diva"

#[kernel]
func fill(out: [int], base: int): void {
    var i = block_idx() * 2 + thread_idx()
    out[i] = base + i
}

func main(): int {
    var a: [int] = [0, 0, 0, 0]
    launch fill(grid: 2, block: 2, a, 10)
    var i = 0
    while i < 4 {
        print_int(a[i])
        i = i + 1
    }
    return 0
}
EOF

printf '%s\n' 10 11 12 13 >"${WORK}/expected.txt"
total=$((total + 1))
if ! build_env timeout 60 "${DRIVER}" build "${WORK}/smoke.diva" "${WORK}/smoke.exe" \
    >"${WORK}/smoke.build.log" 2>&1; then
  fail "smoke (build)"
  sed -n '1,40p' "${WORK}/smoke.build.log" >&2
elif ! timeout 60 "${WORK}/smoke.exe" </dev/null >"${WORK}/smoke.out" 2>"${WORK}/smoke.err"; then
  fail "smoke (run)"
  sed -n '1,20p' "${WORK}/smoke.err" >&2
elif ! diff -u "${WORK}/expected.txt" "${WORK}/smoke.out" >"${WORK}/smoke.diff"; then
  fail "smoke (output)"
  sed -n '1,20p' "${WORK}/smoke.diff" >&2
else
  echo "[gpu] OK   smoke"
fi

total=$((total + 1))
if ! build_env timeout 60 "${DRIVER}" asm "${WORK}/smoke.diva" >"${WORK}/smoke.s" 2>&1; then
  fail "stub emission (asm)"
  sed -n '1,40p' "${WORK}/smoke.s" >&2
elif ! grep -F "_diva_diva_kernel_launch" "${WORK}/smoke.s" >/dev/null; then
  fail "stub emission (missing label)"
  sed -n '1,20p' "${WORK}/smoke.s" >&2
else
  echo "[gpu] OK   stub emission"
fi

check_fail() {
  _name=$1
  _src=$2
  _needle=$3
  total=$((total + 1))
  if build_env timeout 60 "${DRIVER}" build "${_src}" "${WORK}/${_name}.exe" \
      >"${WORK}/${_name}.log" 2>&1; then
    fail "${_name} (expected build failure)"
    return 0
  fi
  if ! grep -F "${_needle}" "${WORK}/${_name}.log" >/dev/null; then
    fail "${_name} (missing needle '${_needle}')"
    sed -n '1,20p' "${WORK}/${_name}.log" >&2
    return 0
  fi
  echo "[gpu] OK   ${_name} (fail)"
}

cat >"${WORK}/noattr.diva" <<'EOF'
func fill(a: int): void { }
func main(): int { launch fill(grid: 1, block: 1, a) return 0 }
EOF

cat >"${WORK}/unknown.diva" <<'EOF'
func main(): int { launch nope(grid: 1, block: 1) return 0 }
EOF

cat >"${WORK}/toomany.diva" <<'EOF'
#[kernel] func fill(a: int, b: int, c: int, d: int, e: int): void { }
func main(): int { launch fill(grid: 1, block: 1, a, b, c, d, e) return 0 }
EOF

cat >"${WORK}/outside.diva" <<'EOF'
func main(): int { var i = thread_idx() return i }
EOF

check_fail noattr "${WORK}/noattr.diva" "launch target is not a kernel function"
check_fail unknown "${WORK}/unknown.diva" "launch target is not a declared function"
check_fail toomany "${WORK}/toomany.diva" "kernel accepts at most four explicit arguments"
check_fail outside "${WORK}/outside.diva" "kernel index builtin used outside a kernel"

echo "[gpu] ${total} checks, ${failed} failed"
if [ "${failed}" -ne 0 ]; then
  exit 1
fi

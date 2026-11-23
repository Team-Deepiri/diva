#!/usr/bin/env bash
set -u

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "${ROOT_DIR}"

WORK="$(mktemp -d "${TMPDIR:-/tmp}/diva-linalg.XXXXXX")"
trap 'rm -rf "${WORK}"' EXIT

if [ -n "${DIVA_PURE_DRIVER:-}" ] && [ -x "${DIVA_PURE_DRIVER}" ]; then
  DRIVER="${DIVA_PURE_DRIVER}"
else
  DRIVER="${WORK}/driver"
  echo "[linalg] building driver from bootstrap seed"
  if ! ROOT_DIR="${ROOT_DIR}" DI_STDLIB_DIR="${ROOT_DIR}/stdlib" DIVA_NO_EXTERNAL=1 \
       DI_RUNTIME_O="${ROOT_DIR}/bootstrap/runtime-linux-amd64.o" \
       timeout 900 "${ROOT_DIR}/bootstrap/diva-linux-amd64" build compiler "${DRIVER}" \
       >"${WORK}/driver-build.log" 2>&1; then
    sed -n '1,40p' "${WORK}/driver-build.log" >&2
    echo "[linalg] driver build failed" >&2
    exit 1
  fi
fi

echo "[linalg] DRIVER=${DRIVER}"
CASES="${ROOT_DIR}/tests/cases/linalg"

total=0
failed=0
fail() {
  failed=$((failed + 1))
  echo "[linalg] FAIL $1" >&2
}

run_env() {
  DI_STDLIB_DIR="${ROOT_DIR}/stdlib" DIVA_NO_EXTERNAL=1 \
    DI_RUNTIME_O="${ROOT_DIR}/bootstrap/runtime-linux-amd64.o" "$@"
}

build() {
  if ! run_env timeout 120 "${DRIVER}" build "$1" "$2" >"${WORK}/build.log" 2>&1; then
    sed -n '1,40p' "${WORK}/build.log" >&2
    return 1
  fi
  return 0
}

has_fragment() {
  if ! grep -F -- "$2" "$1" >/dev/null; then
    fail "missing '$2'"
  fi
}

check_case() {
  name=$1
  src=$2
  want=$3
  total=$((total + 1))
  exe="${WORK}/${name}.exe"
  if ! build "${src}" "${exe}"; then
    fail "${name} (build)"
    return 0
  fi
  out=$(timeout 60 "${exe}" </dev/null 2>&1) || true
  if [ "$out" != "$want" ]; then
    fail "${name} (output)"
    printf '[linalg] expected:\n%s\n[linalg] actual:\n%s\n' "$want" "$out" >&2
    return 0
  fi
  echo "[linalg] OK ${name} (runtime)"
}

check_trap() {
  name=$1
  src=$2
  want=$3
  total=$((total + 1))
  exe="${WORK}/${name}.exe"
  if ! build "${src}" "${exe}"; then
    fail "${name} (build)"
    return 0
  fi
  out=$(timeout 60 "${exe}" </dev/null 2>&1)
  rc=$?
  if [ "${rc}" != 1 ]; then
    fail "${name} (expected rc=1 got=${rc})"
    return 0
  fi
  if [ "$out" != "$want" ]; then
    fail "${name} (trap message)"
    printf '[linalg] expected:\n%s\n[linalg] actual:\n%s\n' "$want" "$out" >&2
    return 0
  fi
  echo "[linalg] OK ${name} (trap)"
}

check_build_error() {
  name=$1
  src=$2
  needle=$3
  total=$((total + 1))
  if build "${src}" "${WORK}/${name}.exe"; then
    fail "${name} (expected build failure)"
    return 0
  fi
  if ! grep -F -- "${needle}" "${WORK}/build.log" >/dev/null; then
    fail "${name} (expected error: ${needle})"
    sed -n '1,40p' "${WORK}/build.log" >&2
    return 0
  fi
  echo "[linalg] OK ${name} (sema)"
}

check_case runtime "${CASES}/runtime.diva" $'5\n5\n24\n58\n64\n139\n154'

total=$((total + 1))
if run_env timeout 60 "${DRIVER}" emit-mlir "${CASES}/runtime.diva" \
     >"${WORK}/runtime.mlir" 2>"${WORK}/runtime.err"; then
  has_fragment "${WORK}/runtime.mlir" 'linalg.add ins('
  has_fragment "${WORK}/runtime.mlir" 'tensor<4xi64>, tensor<4xi64>) outs('
  has_fragment "${WORK}/runtime.mlir" 'linalg.dot ins('
  has_fragment "${WORK}/runtime.mlir" 'linalg.matmul ins('
  has_fragment "${WORK}/runtime.mlir" 'tensor<2x3xi64>, tensor<3x2xi64>) outs('
  has_fragment "${WORK}/runtime.mlir" 'tensor<2x2xi64>) -> tensor<2x2xi64> // diva.tensor linalg.matmul'
  has_fragment "${WORK}/runtime.err" 'partial lowering (issue #119)'
  echo "[linalg] OK runtime (emit-mlir)"
else
  fail 'runtime (emit-mlir exit)'
  cat "${WORK}/runtime.err" >&2
fi

check_build_error sema_rank_fail "${CASES}/sema_rank_fail.diva" \
  'sema: tensor_add rank mismatch: expected rank 1 tensor, got rank 2'
check_trap add_shape_fail "${CASES}/add_shape_fail.diva" \
  'tensor_add: shapes must match'
check_trap shape_fail "${CASES}/shape_fail.diva" \
  'tensor_matmul: inner dimensions must match'

printf '[linalg] %d/%d passed\n' "$((total - failed))" "$total"
[ "${failed}" -eq 0 ]

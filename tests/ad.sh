#!/usr/bin/env sh
# Issue #121: forward-mode automatic differentiation.
#
# Covers the two-word Dual builtins, the #[differentiate] -> `diva grad`
# source transform, generated derivative correctness (x*x, 3*x+2, x*x*x),
# IR lowering, and negative cases.
#
# Self-contained: with no DIVA_PURE_DRIVER set, builds a fresh driver from the
# bootstrap seed. Usage (repo root): sh tests/ad.sh
set -eu

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "${ROOT_DIR}"

WORK="$(mktemp -d "${TMPDIR:-/tmp}/diva-ad.XXXXXX")"
trap 'rm -rf "${WORK}"' EXIT

if [ -n "${DIVA_PURE_DRIVER:-}" ] && [ -x "${DIVA_PURE_DRIVER}" ]; then
  DRIVER="${DIVA_PURE_DRIVER}"
else
  DRIVER="${WORK}/driver"
  echo "[ad] building driver from bootstrap seed"
  if ! ROOT_DIR="${ROOT_DIR}" DI_STDLIB_DIR="${ROOT_DIR}/stdlib" DIVA_NO_EXTERNAL=1 \
       DI_RUNTIME_O="${ROOT_DIR}/bootstrap/runtime-linux-amd64.o" \
       timeout 300 "${ROOT_DIR}/bootstrap/diva-linux-amd64" build compiler "${DRIVER}" \
       >"${WORK}/driver-build.log" 2>&1; then
    sed -n '1,40p' "${WORK}/driver-build.log" >&2
    echo "[ad] driver build failed" >&2
    exit 1
  fi
fi

echo "[ad] DRIVER=${DRIVER}"

total=0
failed=0
fail() {
  failed=$((failed + 1))
  echo "[ad] FAIL $1" >&2
}

build_env() {
  DI_STDLIB_DIR="${ROOT_DIR}/stdlib" DIVA_NO_EXTERNAL=1 \
    DI_RUNTIME_O="${ROOT_DIR}/bootstrap/runtime-linux-amd64.o" "$@"
}

run_exe() {
  _name=$1
  _exe=$2
  _want=$3
  set +e
  timeout 60 "${_exe}" </dev/null >/dev/null 2>&1
  _rc=$?
  set -e
  if [ "${_rc}" -ne "${_want}" ]; then
    fail "${_name} (exit ${_rc}, want ${_want})"
    return 0
  fi
  echo "[ad] OK   ${_name}"
}

check_run() {
  _name=$1
  _src=$2
  _want=$3
  total=$((total + 1))
  _exe="${WORK}/${_name}.exe"
  if ! build_env timeout 60 "${DRIVER}" build "${_src}" "${_exe}" >"${WORK}/${_name}.build.log" 2>&1; then
    fail "${_name} (build)"
    sed -n '1,40p' "${WORK}/${_name}.build.log" >&2
    return 0
  fi
  run_exe "${_name}" "${_exe}" "${_want}"
}

check_grad() {
  _name=$1
  _func=$2
  _want=$3
  total=$((total + 1))
  _src="${CASES}/${_name}.diva"
  _gen="${WORK}/${_name}.gen.diva"
  _exe="${WORK}/${_name}.exe"
  if ! timeout 60 "${DRIVER}" grad "${_src}" "${_func}" >"${_gen}" 2>"${WORK}/${_name}.grad.log"; then
    fail "${_name} (grad)"
    sed -n '1,40p' "${WORK}/${_name}.grad.log" >&2
    return 0
  fi
  if ! grep -F "func ${_func}_dual" "${_gen}" >/dev/null; then
    fail "${_name} (no generated dual function)"
    return 0
  fi
  if ! grep -F "func ${_func}_deriv" "${_gen}" >/dev/null; then
    fail "${_name} (no generated derivative wrapper)"
    return 0
  fi
  if ! build_env timeout 60 "${DRIVER}" build "${_gen}" "${_exe}" >"${WORK}/${_name}.build.log" 2>&1; then
    fail "${_name} (generated build)"
    sed -n '1,40p' "${WORK}/${_name}.build.log" >&2
    return 0
  fi
  run_exe "${_name} (grad)" "${_exe}" "${_want}"
}

check_grad_fail() {
  _name=$1
  _func=$2
  _needle=$3
  total=$((total + 1))
  if timeout 60 "${DRIVER}" grad "${CASES}/${_name}.diva" "${_func}" \
      >"${WORK}/${_name}.gen.out" 2>"${WORK}/${_name}.grad.log"; then
    fail "${_name} (expected grad failure)"
    return 0
  fi
  if ! grep -F "${_needle}" "${WORK}/${_name}.grad.log" >/dev/null; then
    fail "${_name} (missing needle '${_needle}')"
    sed -n '1,20p' "${WORK}/${_name}.grad.log" >&2
    return 0
  fi
  echo "[ad] OK   ${_name} (grad fail)"
}

check_fail() {
  _name=$1
  _needle=$2
  total=$((total + 1))
  if build_env timeout 60 "${DRIVER}" build "${CASES}/${_name}.diva" "${WORK}/${_name}.exe" \
      >"${WORK}/${_name}.log" 2>&1; then
    fail "${_name} (expected build failure)"
    return 0
  fi
  if ! grep -F "${_needle}" "${WORK}/${_name}.log" >/dev/null; then
    fail "${_name} (missing needle '${_needle}')"
    sed -n '1,20p' "${WORK}/${_name}.log" >&2
    return 0
  fi
  echo "[ad] OK   ${_name} (fail)"
}

CASES="${ROOT_DIR}/tests/cases/ad"

check_run builtin_product "${CASES}/builtin_product.diva" 6
check_run builtin_scale   "${CASES}/builtin_scale.diva"   3

check_grad grad_square  square  6
check_grad grad_linear  linear  3
check_grad grad_cube    cube    12
check_grad grad_locals  poly    7

check_grad_fail unmarked    square    "not marked #[differentiate]"
check_grad_fail unsupported branching "unsupported statement"
check_fail fail_dual_arith "dual arithmetic requires dual_* builtins"
check_fail fail_dual_arg   "expected dual, got int"

_gen_square="${WORK}/grad_square.gen.diva"
total=$((total + 1))
if ! build_env timeout 60 "${DRIVER}" grad "${CASES}/grad_square.diva" square >"${_gen_square}" 2>/dev/null; then
  fail "ir lowering (grad)"
elif ! build_env timeout 60 "${DRIVER}" emit-ir "${_gen_square}" >"${WORK}/grad_square.ir" 2>&1; then
  fail "ir lowering (emit-ir)"
elif ! grep -F " mul " "${WORK}/grad_square.ir" >/dev/null; then
  fail "ir lowering (missing mul)"
else
  echo "[ad] OK   ir lowering"
fi

echo "[ad] total=${total} failed=${failed}"
[ "${failed}" -eq 0 ]
echo "[ad] all tests passed"

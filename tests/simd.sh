#!/usr/bin/env sh
# Issue #99: vec4 SIMD foundation (scalar fallback over four stack lanes).
#
# Self-contained: with no DIVA_PURE_DRIVER set, builds a fresh driver from the
# bootstrap seed. Checks runtime semantics, sema rejections, and IR lowering.
#
# Usage (repo root):
#   sh tests/simd.sh
# Optional: DIVA_PURE_DRIVER=/path/to/diva to pin a specific driver.
set -eu

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "${ROOT_DIR}"

WORK="$(mktemp -d "${TMPDIR:-/tmp}/diva-simd.XXXXXX")"
trap 'rm -rf "${WORK}"' EXIT

if [ -n "${DIVA_PURE_DRIVER:-}" ] && [ -x "${DIVA_PURE_DRIVER}" ]; then
  DRIVER="${DIVA_PURE_DRIVER}"
else
  DRIVER="${WORK}/driver"
  echo "[simd] building driver from bootstrap seed"
  if ! ROOT_DIR="${ROOT_DIR}" DI_STDLIB_DIR="${ROOT_DIR}/stdlib" DIVA_NO_EXTERNAL=1 \
       DI_RUNTIME_O="${ROOT_DIR}/bootstrap/runtime-linux-amd64.o" \
       timeout 300 "${ROOT_DIR}/bootstrap/diva-linux-amd64" build compiler "${DRIVER}" \
       >"${WORK}/driver-build.log" 2>&1; then
    sed -n '1,40p' "${WORK}/driver-build.log" >&2
    echo "[simd] driver build failed" >&2
    exit 1
  fi
fi

echo "[simd] DRIVER=${DRIVER}"

total=0
failed=0
fail() {
  failed=$((failed + 1))
  echo "[simd] FAIL $1" >&2
}

build_env() {
  DI_STDLIB_DIR="${ROOT_DIR}/stdlib" DIVA_NO_EXTERNAL=1 \
    DI_RUNTIME_O="${ROOT_DIR}/bootstrap/runtime-linux-amd64.o" "$@"
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
  set +e
  timeout 60 "${_exe}" </dev/null >/dev/null 2>&1
  _rc=$?
  set -e
  if [ "${_rc}" -ne "${_want}" ]; then
    fail "${_name} (exit ${_rc}, want ${_want})"
    return 0
  fi
  echo "[simd] OK   ${_name}"
}

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
  echo "[simd] OK   ${_name} (fail)"
}

check_ir() {
  _name=$1
  _src=$2
  _needle=$3
  total=$((total + 1))
  if ! build_env timeout 60 "${DRIVER}" emit-ir "${_src}" >"${WORK}/${_name}.ir" 2>&1; then
    fail "${_name} (emit-ir)"
    sed -n '1,40p' "${WORK}/${_name}.ir" >&2
    return 0
  fi
  if ! grep -F "${_needle}" "${WORK}/${_name}.ir" >/dev/null; then
    fail "${_name} (missing IR '${_needle}')"
    return 0
  fi
  echo "[simd] OK   ${_name} (ir)"
}

CASES="${ROOT_DIR}/tests/cases/simd"

check_run splat_mul_sum      "${CASES}/splat_mul_sum.diva"      42
check_run load_get_sum       "${CASES}/load_get_sum.diva"       42
check_run add_sum            "${CASES}/add_sum.diva"            42
check_run sub_sum            "${CASES}/sub_sum.diva"            42
check_run dynamic_get        "${CASES}/dynamic_get.diva"        42
check_run assign_copy        "${CASES}/assign_copy.diva"        42
check_run uninitialized_sum  "${CASES}/uninitialized_sum.diva"  42
check_run oob_runtime        "${CASES}/oob_runtime.diva"         1

LANE_MSG="sema: vec4 lane index out of range (0..3)"
ARITH_MSG="sema: vec4 arithmetic requires two vec4 operands"
check_fail lane_high    "${CASES}/fail_lane_high.diva"    "${LANE_MSG}"
check_fail lane_neg     "${CASES}/fail_lane_negative.diva" "${LANE_MSG}"
check_fail mixed_arith  "${CASES}/fail_mixed_arith.diva"  "${ARITH_MSG}"
check_fail compare      "${CASES}/fail_compare.diva"      "${ARITH_MSG}"
check_fail splat_type   "${CASES}/fail_splat_type.diva"   "expected int, got vec4"
check_fail fn_param     "${CASES}/fail_fn_param.diva"     "vec4 function parameters are not supported"
check_fail global       "${CASES}/fail_global.diva"       "vec4 globals are not supported"
check_fail field        "${CASES}/fail_field.diva"        "vec4 struct fields are not supported"
check_fail array        "${CASES}/fail_array.diva"        "vec4 arrays are not supported"

check_ir ir_mul        "${CASES}/splat_mul_sum.diva" " mul "
check_ir ir_add        "${CASES}/splat_mul_sum.diva" " add "
check_ir ir_array_load "${CASES}/dynamic_get.diva"   "array.load"

echo "[simd] total=${total} failed=${failed}"
[ "${failed}" -eq 0 ]
echo "[simd] all tests passed"

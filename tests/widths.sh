#!/usr/bin/env sh
# #86 integer width narrowing/sign-extension casts.
#
# Verifies that casts to i8/i16/i32 sign-extend and casts to u8/u16/u32
# zero-extend from the low bits of the machine-word value, while i64/u64 and
# float widths stay identity. Mirrors tests/casts.sh.
#
# Usage (repo root):
#   sh tests/widths.sh
# Optional: DIVA_PURE_DRIVER=/path/to/diva to pin a specific driver.
set -eu

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "${ROOT_DIR}"

WORK="$(mktemp -d "${TMPDIR:-/tmp}/diva-widths.XXXXXX")"
trap 'rm -rf "${WORK}"' EXIT

if [ -n "${DIVA_PURE_DRIVER:-}" ] && [ -x "${DIVA_PURE_DRIVER}" ]; then
  DRIVER="${DIVA_PURE_DRIVER}"
else
  DRIVER="${WORK}/driver"
  echo "[widths] building driver from bootstrap seed"
  if ! ROOT_DIR="${ROOT_DIR}" DI_STDLIB_DIR="${ROOT_DIR}/stdlib" DIVA_NO_EXTERNAL=1 \
       DI_RUNTIME_O="${ROOT_DIR}/bootstrap/runtime-linux-amd64.o" \
       timeout 300 "${ROOT_DIR}/bootstrap/diva-linux-amd64" build compiler "${DRIVER}" \
       >"${WORK}/driver-build.log" 2>&1; then
    sed -n '1,40p' "${WORK}/driver-build.log" >&2
    echo "[widths] driver build failed" >&2
    exit 1
  fi
fi

echo "[widths] DRIVER=${DRIVER}"

total=0
failed=0
fail() {
  failed=$((failed + 1))
  echo "[widths] FAIL $1" >&2
}

# check_rc <name> <src> <expected_exit>
check_rc() {
  _name=$1
  _src=$2
  _want=$3
  total=$((total + 1))
  _exe="${WORK}/${_name}.exe"
  if ! DI_STDLIB_DIR="${ROOT_DIR}/stdlib" DIVA_NO_EXTERNAL=1 \
       DI_RUNTIME_O="${ROOT_DIR}/bootstrap/runtime-linux-amd64.o" \
       timeout 60 "${DRIVER}" build "${_src}" "${_exe}" >"${WORK}/${_name}.build.log" 2>&1; then
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
  echo "[widths] OK   ${_name}"
}

# check_ir_op <name> <src> <opname>
check_ir_op() {
  _name=$1
  _src=$2
  _op=$3
  total=$((total + 1))
  if ! DI_STDLIB_DIR="${ROOT_DIR}/stdlib" DIVA_NO_EXTERNAL=1 \
       timeout 60 "${DRIVER}" emit-ir "${_src}" >"${WORK}/${_name}.ir" 2>&1; then
    fail "${_name} (emit-ir)"
    sed -n '1,40p' "${WORK}/${_name}.ir" >&2
    return 0
  fi
  if ! grep -q " ${_op} " "${WORK}/${_name}.ir"; then
    fail "${_name} (missing IR op '${_op}')"
    return 0
  fi
  echo "[widths] OK   ${_name}"
}

check_rc narrow_i8 "${ROOT_DIR}/tests/cases/widths/narrow_i8.diva" 44
check_rc narrow_u8 "${ROOT_DIR}/tests/cases/widths/narrow_u8.diva" 44
check_rc u8_from_neg "${ROOT_DIR}/tests/cases/widths/u8_from_neg.diva" 0
check_rc i8_high_bit "${ROOT_DIR}/tests/cases/widths/i8_high_bit.diva" 0
check_rc narrow_16 "${ROOT_DIR}/tests/cases/widths/narrow_16.diva" 0
check_rc narrow_32 "${ROOT_DIR}/tests/cases/widths/narrow_32.diva" 0
check_rc identity_widths "${ROOT_DIR}/tests/cases/widths/identity_widths.diva" 0
check_rc narrow_in_expr "${ROOT_DIR}/tests/cases/widths/narrow_in_expr.diva" 0
check_ir_op ir_sign_extend "${ROOT_DIR}/tests/cases/widths/narrow_i8.diva" sar
check_ir_op ir_zero_extend "${ROOT_DIR}/tests/cases/widths/narrow_u8.diva" shr

echo "[widths] total=${total} failed=${failed}"
[ "${failed}" -eq 0 ]

#!/usr/bin/env sh
# #95 extension: #[repr(C)] / #[repr(iN)] attribute parsing.
#
# Self-contained: with no DIVA_PURE_DRIVER set, builds a fresh driver from the
# bootstrap seed (same shape as tests/ffi.sh).
#
# Usage (repo root):
#   sh tests/reprc.sh
# Optional: DIVA_PURE_DRIVER=/path/to/diva to pin a specific driver.
set -eu

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "${ROOT_DIR}"

WORK="$(mktemp -d "${TMPDIR:-/tmp}/diva-reprc.XXXXXX")"
trap 'rm -rf "${WORK}"' EXIT

if [ -n "${DIVA_PURE_DRIVER:-}" ] && [ -x "${DIVA_PURE_DRIVER}" ]; then
  DRIVER="${DIVA_PURE_DRIVER}"
else
  DRIVER="${WORK}/driver"
  echo "[reprc] building driver from bootstrap seed"
  if ! ROOT_DIR="${ROOT_DIR}" DI_STDLIB_DIR="${ROOT_DIR}/stdlib" DIVA_NO_EXTERNAL=1 \
       DI_RUNTIME_O="${ROOT_DIR}/bootstrap/runtime-linux-amd64.o" \
       timeout 300 "${ROOT_DIR}/bootstrap/diva-linux-amd64" build compiler "${DRIVER}" \
       >"${WORK}/driver-build.log" 2>&1; then
    sed -n '1,40p' "${WORK}/driver-build.log" >&2
    echo "[reprc] driver build failed" >&2
    exit 1
  fi
fi

echo "[reprc] DRIVER=${DRIVER}"

total=0
failed=0
fail() {
  failed=$((failed + 1))
  echo "[reprc] FAIL $1" >&2
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
  echo "[reprc] OK   ${_name}"
}

# check_fail <name> <src> <needle>
check_fail() {
  _name=$1
  _src=$2
  _needle=$3
  total=$((total + 1))
  if DI_STDLIB_DIR="${ROOT_DIR}/stdlib" DIVA_NO_EXTERNAL=1 \
     DI_RUNTIME_O="${ROOT_DIR}/bootstrap/runtime-linux-amd64.o" \
     timeout 60 "${DRIVER}" build "${_src}" "${WORK}/${_name}.exe" \
     >"${WORK}/${_name}.log" 2>&1; then
    fail "${_name} (expected build failure)"
    return 0
  fi
  if ! grep -q "${_needle}" "${WORK}/${_name}.log"; then
    fail "${_name} (missing needle '${_needle}')"
    sed -n '1,20p' "${WORK}/${_name}.log" >&2
    return 0
  fi
  echo "[reprc] OK   ${_name} (fail)"
}

CASES="${ROOT_DIR}/tests/cases/reprc"

check_rc repr_c_struct "${CASES}/repr_c_struct.diva" 42
check_rc repr_i32_enum "${CASES}/repr_i32_enum.diva" 1
check_rc multiple_attrs "${CASES}/multiple_attrs.diva" 42
check_rc no_attr_struct "${ROOT_DIR}/tests/cases/structs/construct_read.diva" 42

check_fail fail_repr_missing_arg "${CASES}/fail_repr_missing_arg.diva" "repr expects a layout name"
check_fail fail_repr_empty_arg "${CASES}/fail_repr_empty_arg.diva" "repr expects a layout name"
check_fail fail_repr_unknown_layout "${CASES}/fail_repr_unknown_layout.diva" "unknown repr layout"
check_fail fail_repr_many_args "${CASES}/fail_repr_many_args.diva" "repr accepts a single layout argument"
check_fail fail_attr_no_bracket "${CASES}/fail_attr_no_bracket.diva" "expected LBRACK"
check_fail fail_attr_no_name "${CASES}/fail_attr_no_name.diva" "expected attribute name after"
check_fail fail_attr_no_close "${CASES}/fail_attr_no_close.diva" "expected RPAREN"

echo "[reprc] total=${total} failed=${failed}"
[ "${failed}" -eq 0 ]

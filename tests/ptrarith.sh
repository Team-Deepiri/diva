#!/usr/bin/env sh
# #94 Phase 3: typed raw pointer arithmetic (`p.add(n)`, `p.sub(n)`).
#
# Self-contained: with no DIVA_PURE_DRIVER set, builds a fresh driver from the
# bootstrap seed.
#
# Usage (repo root):
#   sh tests/ptrarith.sh
# Optional: DIVA_PURE_DRIVER=/path/to/diva to pin a specific driver.
set -eu

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "${ROOT_DIR}"

WORK="$(mktemp -d "${TMPDIR:-/tmp}/diva-ptrarith.XXXXXX")"
trap 'rm -rf "${WORK}"' EXIT

if [ -n "${DIVA_PURE_DRIVER:-}" ] && [ -x "${DIVA_PURE_DRIVER}" ]; then
  DRIVER="${DIVA_PURE_DRIVER}"
else
  DRIVER="${WORK}/driver"
  echo "[ptrarith] building driver from bootstrap seed"
  if ! ROOT_DIR="${ROOT_DIR}" DI_STDLIB_DIR="${ROOT_DIR}/stdlib" DIVA_NO_EXTERNAL=1 \
       DI_RUNTIME_O="${ROOT_DIR}/bootstrap/runtime-linux-amd64.o" \
       timeout 300 "${ROOT_DIR}/bootstrap/diva-linux-amd64" build compiler "${DRIVER}" \
       >"${WORK}/driver-build.log" 2>&1; then
    sed -n '1,40p' "${WORK}/driver-build.log" >&2
    echo "[ptrarith] driver build failed" >&2
    exit 1
  fi
fi

echo "[ptrarith] DRIVER=${DRIVER}"

total=0
failed=0
fail() {
  failed=$((failed + 1))
  echo "[ptrarith] FAIL $1" >&2
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
  echo "[ptrarith] OK   ${_name}"
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
  echo "[ptrarith] OK   ${_name} (fail)"
}

check_rc store_offset "${ROOT_DIR}/tests/cases/ptrarith/store_offset.diva" 46
check_rc sub_offset "${ROOT_DIR}/tests/cases/ptrarith/sub_offset.diva" 7
check_rc dynamic_offset "${ROOT_DIR}/tests/cases/ptrarith/dynamic_offset.diva" 21

check_fail nonpointer "${ROOT_DIR}/tests/cases/ptrarith/nonpointer.diva" \
  "pointer arithmetic requires a raw pointer receiver"
check_fail outside_unsafe "${ROOT_DIR}/tests/cases/ptrarith/outside_unsafe.diva" \
  "raw pointer arithmetic requires an unsafe block"
check_fail bad_arity "${ROOT_DIR}/tests/cases/ptrarith/bad_arity.diva" \
  "pointer arithmetic expects one integer argument"
check_fail noninteger_offset "${ROOT_DIR}/tests/cases/ptrarith/noninteger_offset.diva" \
  "pointer arithmetic offset must be an integer"

echo "[ptrarith] total=${total} failed=${failed}"
[ "${failed}" -eq 0 ]

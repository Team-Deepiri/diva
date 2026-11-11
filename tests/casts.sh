#!/usr/bin/env sh
# #86 Phase 1 (foundation): `expr as Type` cast expressions.
#
# This slice adds the `as` cast operator between numeric/bool types. All
# current numeric widths share the machine-word representation, so a cast
# lowers to its operand; per-width narrowing/widening codegen is a follow-up.
# The negative case locks the existing strict assignment check (no implicit
# int-to-bool), which casts must be used to cross.
#
# Self-contained: with no DIVA_PURE_DRIVER set, builds a fresh driver from the
# bootstrap seed.
#
# Usage (repo root):
#   sh tests/casts.sh
# Optional: DIVA_PURE_DRIVER=/path/to/diva to pin a specific driver.
set -eu

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "${ROOT_DIR}"

WORK="$(mktemp -d "${TMPDIR:-/tmp}/diva-casts.XXXXXX")"
trap 'rm -rf "${WORK}"' EXIT

if [ -n "${DIVA_PURE_DRIVER:-}" ] && [ -x "${DIVA_PURE_DRIVER}" ]; then
  DRIVER="${DIVA_PURE_DRIVER}"
else
  DRIVER="${WORK}/driver"
  echo "[casts] building driver from bootstrap seed"
  if ! ROOT_DIR="${ROOT_DIR}" DI_STDLIB_DIR="${ROOT_DIR}/stdlib" DIVA_NO_EXTERNAL=1 \
       DI_RUNTIME_O="${ROOT_DIR}/bootstrap/runtime-linux-amd64.o" \
       timeout 300 "${ROOT_DIR}/bootstrap/diva-linux-amd64" build compiler "${DRIVER}" \
       >"${WORK}/driver-build.log" 2>&1; then
    sed -n '1,40p' "${WORK}/driver-build.log" >&2
    echo "[casts] driver build failed" >&2
    exit 1
  fi
fi

echo "[casts] DRIVER=${DRIVER}"

total=0
failed=0
fail() {
  failed=$((failed + 1))
  echo "[casts] FAIL $1" >&2
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
  echo "[casts] OK   ${_name}"
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
  echo "[casts] OK   ${_name} (fail)"
}

check_rc cast_chain "${ROOT_DIR}/tests/cases/casts/cast_chain.diva" 7
check_rc cast_arith "${ROOT_DIR}/tests/cases/casts/cast_arith.diva" 9
check_fail fail_bool_from_int "${ROOT_DIR}/tests/cases/casts/fail_bool_from_int.diva" "type mismatch"

echo "[casts] total=${total} failed=${failed}"
[ "${failed}" -eq 0 ]

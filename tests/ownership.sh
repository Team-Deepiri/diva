#!/usr/bin/env sh
# #88 Phase 1: ownership / move checking for value types.
#
# Covers:
#   - assigning or passing a struct local moves it (source becomes invalid),
#   - using a moved value (read, field access, second move) is a sema error,
#   - reassignment re-initialises a moved binding,
#   - struct field reads do not move,
#   - int/bool/str/text are Copy and stay usable after assignment.
#
# Self-contained: with no DIVA_PURE_DRIVER set, builds a fresh driver from the
# bootstrap seed.
#
# Usage (repo root):
#   sh tests/ownership.sh
# Optional: DIVA_PURE_DRIVER=/path/to/diva to pin a specific driver.
set -eu

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "${ROOT_DIR}"

WORK="$(mktemp -d "${TMPDIR:-/tmp}/diva-ownership.XXXXXX")"
trap 'rm -rf "${WORK}"' EXIT

if [ -n "${DIVA_PURE_DRIVER:-}" ] && [ -x "${DIVA_PURE_DRIVER}" ]; then
  DRIVER="${DIVA_PURE_DRIVER}"
else
  DRIVER="${WORK}/driver"
  echo "[ownership] building driver from bootstrap seed"
  if ! ROOT_DIR="${ROOT_DIR}" DI_STDLIB_DIR="${ROOT_DIR}/stdlib" DIVA_NO_EXTERNAL=1 \
       DI_RUNTIME_O="${ROOT_DIR}/bootstrap/runtime-linux-amd64.o" \
       timeout 300 "${ROOT_DIR}/bootstrap/diva-linux-amd64" build compiler "${DRIVER}" \
       >"${WORK}/driver-build.log" 2>&1; then
    sed -n '1,40p' "${WORK}/driver-build.log" >&2
    echo "[ownership] driver build failed" >&2
    exit 1
  fi
fi

echo "[ownership] DRIVER=${DRIVER}"

total=0
failed=0
fail() {
  failed=$((failed + 1))
  echo "[ownership] FAIL $1" >&2
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
  echo "[ownership] OK   ${_name}"
}

# check_fail <name> <src> <needle>
check_fail() {
  _name=$1
  _src=$2
  _needle=$3
  total=$((total + 1))
  if DI_STDLIB_DIR="${ROOT_DIR}/stdlib" DIVA_NO_EXTERNAL=1 \
       DI_RUNTIME_O="${ROOT_DIR}/bootstrap/runtime-linux-amd64.o" \
       timeout 60 "${DRIVER}" build "${_src}" "${WORK}/${_name}.exe" >"${WORK}/${_name}.build.log" 2>&1; then
    fail "${_name} (expected compile error)"
    return 0
  fi
  if ! grep -F "${_needle}" "${WORK}/${_name}.build.log" >/dev/null; then
    fail "${_name} (missing diagnostic: ${_needle})"
    sed -n '1,40p' "${WORK}/${_name}.build.log" >&2
    return 0
  fi
  echo "[ownership] OK   ${_name} (rejected)"
}

check_fail move_then_use "${ROOT_DIR}/tests/cases/ownership/move_then_use.diva" "sema: use of moved value 'p'"
check_fail move_field_access "${ROOT_DIR}/tests/cases/ownership/move_field_access.diva" "sema: use of moved value 'p'"
check_fail move_again "${ROOT_DIR}/tests/cases/ownership/move_again.diva" "sema: use of moved value 'p'"
check_fail move_to_call "${ROOT_DIR}/tests/cases/ownership/move_to_call.diva" "sema: use of moved value 'p'"
check_fail move_param_again "${ROOT_DIR}/tests/cases/ownership/move_param_again.diva" "sema: use of moved value 'p'"

check_rc reassign_revives "${ROOT_DIR}/tests/cases/ownership/reassign_revives.diva" 23
check_rc reassign_from_move "${ROOT_DIR}/tests/cases/ownership/reassign_from_move.diva" 47
check_rc move_ok "${ROOT_DIR}/tests/cases/ownership/move_ok.diva" 42
check_rc field_read_no_move "${ROOT_DIR}/tests/cases/ownership/field_read_no_move.diva" 42
check_rc copy_types_usable "${ROOT_DIR}/tests/cases/ownership/copy_types_usable.diva" 42

echo "[ownership] total=${total} failed=${failed}"
[ "${failed}" -eq 0 ]

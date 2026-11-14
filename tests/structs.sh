#!/usr/bin/env sh
# #87 Phase 1: value-type structs.
#
# Covers struct declaration/registration, stack-resident locals, struct
# literals `Point { x: 1, y: 2 }`, mutable field reads/writes, and copy
# semantics (`let q: Point = p` copies every field; mutation of one binding
# does not affect the other).
#
# Self-contained: with no DIVA_PURE_DRIVER set, builds a fresh driver from the
# bootstrap seed.
#
# Usage (repo root):
#   sh tests/structs.sh
# Optional: DIVA_PURE_DRIVER=/path/to/diva to pin a specific driver.
set -eu

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "${ROOT_DIR}"

WORK="$(mktemp -d "${TMPDIR:-/tmp}/diva-structs.XXXXXX")"
trap 'rm -rf "${WORK}"' EXIT

if [ -n "${DIVA_PURE_DRIVER:-}" ] && [ -x "${DIVA_PURE_DRIVER}" ]; then
  DRIVER="${DIVA_PURE_DRIVER}"
else
  DRIVER="${WORK}/driver"
  echo "[structs] building driver from bootstrap seed"
  if ! ROOT_DIR="${ROOT_DIR}" DI_STDLIB_DIR="${ROOT_DIR}/stdlib" DIVA_NO_EXTERNAL=1 \
       DI_RUNTIME_O="${ROOT_DIR}/bootstrap/runtime-linux-amd64.o" \
       timeout 300 "${ROOT_DIR}/bootstrap/diva-linux-amd64" build compiler "${DRIVER}" \
       >"${WORK}/driver-build.log" 2>&1; then
    sed -n '1,40p' "${WORK}/driver-build.log" >&2
    echo "[structs] driver build failed" >&2
    exit 1
  fi
fi

echo "[structs] DRIVER=${DRIVER}"

total=0
failed=0
fail() {
  failed=$((failed + 1))
  echo "[structs] FAIL $1" >&2
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
  echo "[structs] OK   ${_name}"
}

check_rc construct_read "${ROOT_DIR}/tests/cases/structs/construct_read.diva" 42
check_rc field_write "${ROOT_DIR}/tests/cases/structs/field_write.diva" 42
check_rc copy_isolation "${ROOT_DIR}/tests/cases/structs/copy_isolation.diva" 77
check_rc copy_source_isolation "${ROOT_DIR}/tests/cases/structs/copy_source_isolation.diva" 63
check_rc reassign_copy "${ROOT_DIR}/tests/cases/structs/reassign_copy.diva" 47
check_rc infer_literal "${ROOT_DIR}/tests/cases/structs/infer_literal.diva" 42

echo "[structs] total=${total} failed=${failed}"
[ "${failed}" -eq 0 ]

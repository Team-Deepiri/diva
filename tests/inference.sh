#!/usr/bin/env sh
# #96: expression type inference (foundation).
#
# Covers:
#   - untyped let/var bindings infer from a local or extern function call
#   - if-expressions infer a result type when both branches agree
#   - match-expressions infer a result type from their arms
#   - branch type disagreement is diagnosed
#   - unannotated struct copies keep struct (value) semantics
#
# Self-contained: with no DIVA_PURE_DRIVER set, builds a fresh driver from the
# bootstrap seed.
#
# Usage (repo root):
#   sh tests/inference.sh
# Optional: DIVA_PURE_DRIVER=/path/to/diva to pin a specific driver.
set -eu

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "${ROOT_DIR}"

WORK="$(mktemp -d "${TMPDIR:-/tmp}/diva-inference.XXXXXX")"
trap 'rm -rf "${WORK}"' EXIT

if [ -n "${DIVA_PURE_DRIVER:-}" ] && [ -x "${DIVA_PURE_DRIVER}" ]; then
  DRIVER="${DIVA_PURE_DRIVER}"
else
  DRIVER="${WORK}/driver"
  echo "[inference] building driver from bootstrap seed"
  if ! ROOT_DIR="${ROOT_DIR}" DI_STDLIB_DIR="${ROOT_DIR}/stdlib" DIVA_NO_EXTERNAL=1 \
       DI_RUNTIME_O="${ROOT_DIR}/bootstrap/runtime-linux-amd64.o" \
       timeout 300 "${ROOT_DIR}/bootstrap/diva-linux-amd64" build compiler "${DRIVER}" \
       >"${WORK}/driver-build.log" 2>&1; then
    sed -n '1,40p' "${WORK}/driver-build.log" >&2
    echo "[inference] driver build failed" >&2
    exit 1
  fi
fi

echo "[inference] DRIVER=${DRIVER}"

total=0
failed=0
fail() {
  failed=$((failed + 1))
  echo "[inference] FAIL $1" >&2
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
  echo "[inference] OK   ${_name}"
}

# check_build_fail <name> <src> <expected_message>
check_build_fail() {
  _name=$1
  _src=$2
  _want=$3
  total=$((total + 1))
  set +e
  DI_STDLIB_DIR="${ROOT_DIR}/stdlib" DIVA_NO_EXTERNAL=1 \
    DI_RUNTIME_O="${ROOT_DIR}/bootstrap/runtime-linux-amd64.o" \
    timeout 60 "${DRIVER}" build "${_src}" "${WORK}/${_name}.exe" \
    >"${WORK}/${_name}.build.log" 2>&1
  _rc=$?
  set -e
  if [ "${_rc}" -eq 0 ]; then
    fail "${_name} (build succeeded, want failure)"
    return 0
  fi
  if ! grep -F "${_want}" "${WORK}/${_name}.build.log" >/dev/null; then
    fail "${_name} (missing diagnostic: ${_want})"
    sed -n '1,40p' "${WORK}/${_name}.build.log" >&2
    return 0
  fi
  echo "[inference] OK   ${_name}"
}

check_rc untyped_from_call "${ROOT_DIR}/tests/cases/inference/untyped_from_call.diva" 42
check_rc if_expr_type "${ROOT_DIR}/tests/cases/inference/if_expr_type.diva" 42
check_rc match_expr_type "${ROOT_DIR}/tests/cases/inference/match_expr_type.diva" 42
check_rc untyped_struct_copy "${ROOT_DIR}/tests/cases/inference/untyped_struct_copy.diva" 23
check_build_fail branch_mismatch "${ROOT_DIR}/tests/cases/inference/branch_mismatch.diva" \
  "if branches have inconsistent types"

echo "[inference] total=${total} failed=${failed}"
[ "${failed}" -eq 0 ]

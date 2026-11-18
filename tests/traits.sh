#!/usr/bin/env sh
# #135 Phase 1: trait objects and dynamic dispatch.
#
# Covers `dyn Trait` type syntax, storing concrete struct values into a dyn
# local, calling a trait method through the dyn value, and tag dispatch across
# two concrete impls (including a reassignment to a different impl).
#
# Dispatch representation: a dyn value is a tagged pair/record. Slot 0 holds a
# closed-set impl tag (declaration order per trait); the remaining slots hold
# the concrete struct's fields. Method calls lower to a compare-and-branch
# chain over known tags, calling the impl function directly. This is not a
# general vtable ABI; see docs/trait-objects.md for limitations.
#
# Self-contained: with no DIVA_PURE_DRIVER set, builds a fresh driver from the
# bootstrap seed.
#
# Usage (repo root):
#   sh tests/traits.sh
# Optional: DIVA_PURE_DRIVER=/path/to/diva to pin a specific driver.
set -eu

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "${ROOT_DIR}"

WORK="$(mktemp -d "${TMPDIR:-/tmp}/diva-traits.XXXXXX")"
trap 'rm -rf "${WORK}"' EXIT

if [ -n "${DIVA_PURE_DRIVER:-}" ] && [ -x "${DIVA_PURE_DRIVER}" ]; then
  DRIVER="${DIVA_PURE_DRIVER}"
else
  DRIVER="${WORK}/driver"
  echo "[traits] building driver from bootstrap seed"
  if ! ROOT_DIR="${ROOT_DIR}" DI_STDLIB_DIR="${ROOT_DIR}/stdlib" DIVA_NO_EXTERNAL=1 \
       DI_RUNTIME_O="${ROOT_DIR}/bootstrap/runtime-linux-amd64.o" \
       timeout 300 "${ROOT_DIR}/bootstrap/diva-linux-amd64" build compiler "${DRIVER}" \
       >"${WORK}/driver-build.log" 2>&1; then
    sed -n '1,40p' "${WORK}/driver-build.log" >&2
    echo "[traits] driver build failed" >&2
    exit 1
  fi
fi

echo "[traits] DRIVER=${DRIVER}"

total=0
failed=0
fail() {
  failed=$((failed + 1))
  echo "[traits] FAIL $1" >&2
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
  echo "[traits] OK   ${_name}"
}

check_rc dyn_two_impls "${ROOT_DIR}/tests/cases/traits/dyn_two_impls.diva" 42
check_rc dyn_from_local "${ROOT_DIR}/tests/cases/traits/dyn_from_local.diva" 32
check_rc dyn_reassign "${ROOT_DIR}/tests/cases/traits/dyn_reassign.diva" 42

echo "[traits] total=${total} failed=${failed}"
[ "${failed}" -eq 0 ]

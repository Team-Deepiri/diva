#!/usr/bin/env sh
# #93 Phase 1: Option<T> / Result<T,E> as first-class language types.
#
# Builds and runs the focused optres cases against the pure-ELF native path and
# checks their stdout. `option_result_basic` covers the stdlib accessor surface
# for Option and Result; `enum_basic` covers the tagged-variant mechanism
# (unit-variant ordering, `.tag`, `==`, reassignment, enum-typed parameters).
#
# These cases need a driver built from this branch: enums are not in the pinned
# bootstrap seed. With no DIVA_PURE_DRIVER set, this script builds a fresh driver
# from the seed itself (like tests/enums.sh), so it works in CI with no build/.
#
#   sh tests/optres.sh
# Optional: DIVA_PURE_DRIVER=/path/to/diva to pin a specific driver.
set -eu

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "${ROOT_DIR}"

WORK="$(mktemp -d "${TMPDIR:-/tmp}/diva-optres.XXXXXX")"
trap 'rm -rf "${WORK}"' EXIT

if [ -n "${DIVA_PURE_DRIVER:-}" ] && [ -x "${DIVA_PURE_DRIVER}" ]; then
  DRIVER="${DIVA_PURE_DRIVER}"
elif [ -x "${ROOT_DIR}/build/diva-compiler-pure-elf-optres" ]; then
  DRIVER="${ROOT_DIR}/build/diva-compiler-pure-elf-optres"
else
  DRIVER="${WORK}/driver"
  echo "[optres] building driver from bootstrap seed"
  if ! ROOT_DIR="${ROOT_DIR}" DI_STDLIB_DIR="${ROOT_DIR}/stdlib" DIVA_NO_EXTERNAL=1 \
       DI_RUNTIME_O="${ROOT_DIR}/bootstrap/runtime-linux-amd64.o" \
       timeout 900 "${ROOT_DIR}/bootstrap/diva-linux-amd64" build compiler "${DRIVER}" \
       >"${WORK}/driver-build.log" 2>&1; then
    sed -n '1,40p' "${WORK}/driver-build.log" >&2
    echo "[optres] driver build failed" >&2
    exit 1
  fi
fi

echo "[optres] DRIVER=${DRIVER}"

total=0
failed=0
fail() {
  failed=$((failed + 1))
  echo "[optres] FAIL $1" >&2
}

# build <src> <exe> -> 0 on success
build() {
  if ! DI_STDLIB_DIR="${ROOT_DIR}/stdlib" DIVA_NO_EXTERNAL=1 \
       DI_RUNTIME_O="${ROOT_DIR}/bootstrap/runtime-linux-amd64.o" \
       timeout 60 "${DRIVER}" build "$1" "$2" >"${WORK}/build.log" 2>&1; then
    sed -n '1,40p' "${WORK}/build.log" >&2
    return 1
  fi
  return 0
}

# check_case <name> <src> <expected>
check_case() {
  _name=$1
  _src=$2
  _want=$3
  total=$((total + 1))
  _exe="${WORK}/${_name}.exe"
  if ! build "${_src}" "${_exe}"; then
    fail "${_name} (build)"
    return 0
  fi
  if ! _out=$(timeout 60 "${_exe}" </dev/null 2>/dev/null); then
    fail "${_name} (run)"
    return 0
  fi
  if [ "${_out}" != "${_want}" ]; then
    fail "${_name} (output)"
    printf '[optres] expected:\n%s\n[optres] actual:\n%s\n' "${_want}" "${_out}" >&2
    return 0
  fi
  echo "[optres] OK   ${_name}"
}

check_case option_result_basic "${ROOT_DIR}/tests/cases/optres/option_result_basic.diva" '0
1
1
1
0'

check_case enum_basic "${ROOT_DIR}/tests/cases/optres/enum_basic.diva" '2
1
0'

# Negative sema diagnostics for enum declarations/construction. These live in
# tests/cases/sema/ but are gated here (not tests/sema.list) because the seed
# driver used by CI's native-broad gate cannot parse the `enum` keyword yet.
check_fail() {
  _name=$1
  _src=$2
  _needle=$3
  total=$((total + 1))
  if DI_STDLIB_DIR="${ROOT_DIR}/stdlib" DIVA_NO_EXTERNAL=1 \
       DI_RUNTIME_O="${ROOT_DIR}/bootstrap/runtime-linux-amd64.o" \
       timeout 60 "${DRIVER}" build "${_src}" "${WORK}/${_name}.exe" >"${WORK}/fail.log" 2>&1; then
    fail "${_name} (expected failure, build succeeded)"
    return 0
  fi
  if ! grep -F "${_needle}" "${WORK}/fail.log" >/dev/null; then
    fail "${_name} (missing diagnostic '${_needle}')"
    sed -n '1,20p' "${WORK}/fail.log" >&2
    return 0
  fi
  echo "[optres] OK   ${_name} (rejected)"
}

check_fail fail_enum_payload_type "${ROOT_DIR}/tests/cases/sema/fail_enum_payload_type.diva" "type mismatch"
check_fail fail_enum_wrong_arity "${ROOT_DIR}/tests/cases/sema/fail_enum_wrong_arity.diva" "expects 1 payload argument"
check_fail fail_enum_bare_variant "${ROOT_DIR}/tests/cases/sema/fail_enum_bare_variant.diva" "must be called"
check_fail fail_enum_type_mismatch "${ROOT_DIR}/tests/cases/sema/fail_enum_type_mismatch.diva" "expected enum"
check_fail fail_enum_dup_variant "${ROOT_DIR}/tests/cases/sema/fail_enum_dup_variant.diva" "duplicate variant"
check_fail fail_enum_assign_variant "${ROOT_DIR}/tests/cases/sema/fail_enum_assign_variant.diva" "cannot assign to enum variant"

echo "[optres] total=${total} failed=${failed}"
[ "${failed}" -eq 0 ]

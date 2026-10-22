#!/usr/bin/env sh
# #91 Phase 1: match expressions — patterns, guards, exhaustiveness.
#
# The positive cases cover int/bool/string literal patterns, enum variant
# patterns (qualified and bare), payload binding, guard clauses and
# whole-value binding. The `fail_*` cases lock the sema diagnostics
# (non-exhaustive match, unreachable pattern, inconsistent arm types, unknown
# pattern/enum/variant, payload arity); they run here because negative.list is
# driven by the pinned seed, which predates match support.
#
# Self-contained: with no DIVA_PURE_DRIVER set, builds a fresh driver from the
# bootstrap seed (the shared build/diva-compiler-pure-elf symlink may not
# support match yet).
#
# Usage (repo root):
#   sh tests/match.sh
# Optional: DIVA_PURE_DRIVER=/path/to/diva to pin a specific driver.
set -eu

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "${ROOT_DIR}"

WORK="$(mktemp -d "${TMPDIR:-/tmp}/diva-match.XXXXXX")"
trap 'rm -rf "${WORK}"' EXIT

if [ -n "${DIVA_PURE_DRIVER:-}" ] && [ -x "${DIVA_PURE_DRIVER}" ]; then
  DRIVER="${DIVA_PURE_DRIVER}"
else
  DRIVER="${WORK}/driver"
  echo "[match] building driver from bootstrap seed"
  if ! ROOT_DIR="${ROOT_DIR}" DI_STDLIB_DIR="${ROOT_DIR}/stdlib" DIVA_NO_EXTERNAL=1 \
       DI_RUNTIME_O="${ROOT_DIR}/bootstrap/runtime-linux-amd64.o" \
       timeout 900 "${ROOT_DIR}/bootstrap/diva-linux-amd64" build compiler "${DRIVER}" \
       >"${WORK}/driver-build.log" 2>&1; then
    sed -n '1,40p' "${WORK}/driver-build.log" >&2
    echo "[match] driver build failed" >&2
    exit 1
  fi
fi

echo "[match] DRIVER=${DRIVER}"

total=0
failed=0
fail() {
  failed=$((failed + 1))
  echo "[match] FAIL $1" >&2
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
    printf '[match] expected:\n%s\n[match] actual:\n%s\n' "${_want}" "${_out}" >&2
    return 0
  fi
  echo "[match] OK   ${_name}"
}

# check_fail <name> <src> <needle> — build must fail with needle in output
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
  echo "[match] OK   ${_name} (fail)"
}

CASES="${ROOT_DIR}/tests/cases/match"

check_case int "${CASES}/int_match.diva" '10
20
30
40
1'

check_case bool "${CASES}/bool_match.diva" '1
4'

check_case str "${CASES}/str_match.diva" '2
6'

check_case enum "${CASES}/enum_match.diva" '100
3'

check_case payload "${CASES}/payload_match.diva" '42
7'

check_case guard "${CASES}/guard_match.diva" '50
60'

check_case binding "${CASES}/binding_match.diva" '6
abc'

check_fail fail_missing_variants "${CASES}/fail_missing_variants.diva" "missing variants 'Green', 'Blue'"
check_fail fail_missing_bool "${CASES}/fail_missing_bool.diva" "missing pattern 'false'"
check_fail fail_unreachable "${CASES}/fail_unreachable.diva" "unreachable pattern"
check_fail fail_arm_types "${CASES}/fail_arm_types.diva" "match arms have inconsistent types"
check_fail fail_unknown_pattern "${CASES}/fail_unknown_pattern.diva" "unknown pattern 'Purple'"
check_fail fail_unknown_variant "${CASES}/fail_unknown_variant.diva" "unknown variant 'Purple' in enum 'Color'"
check_fail fail_unknown_enum "${CASES}/fail_unknown_enum.diva" "unknown enum 'Nope'"
check_fail fail_payload_binding "${CASES}/fail_payload_binding.diva" "variant 'Some' expects a payload binding"
check_fail fail_unit_payload "${CASES}/fail_unit_payload.diva" "unit variant 'None' takes no payload"
check_fail fail_no_wildcard "${CASES}/fail_no_wildcard.diva" "non-exhaustive match: add a wildcard arm"

echo "[match] total=${total} failed=${failed}"
[ "${failed}" -eq 0 ]

#!/usr/bin/env sh
# #85 Phase 1: enums and tagged variants with tagged variants.
#
# `unit_enum` covers declaration, qualified construction, reassignment and
# .tag reads/== on a payload-free enum; `payload_enum` covers tag+data slots,
# payload assignment, unit-variant payload reset, and .data reads.
#
# Self-contained: with no DIVA_PURE_DRIVER set, builds a fresh driver from the
# bootstrap seed (the shared build/diva-compiler-pure-elf symlink may not
# support enums yet).
#
# Usage (repo root):
#   sh tests/enums.sh
# Optional: DIVA_PURE_DRIVER=/path/to/diva to pin a specific driver.
set -eu

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "${ROOT_DIR}"

WORK="$(mktemp -d "${TMPDIR:-/tmp}/diva-enums.XXXXXX")"
trap 'rm -rf "${WORK}"' EXIT

if [ -n "${DIVA_PURE_DRIVER:-}" ] && [ -x "${DIVA_PURE_DRIVER}" ]; then
  DRIVER="${DIVA_PURE_DRIVER}"
else
  DRIVER="${WORK}/driver"
  echo "[enums] building driver from bootstrap seed"
  if ! ROOT_DIR="${ROOT_DIR}" DI_STDLIB_DIR="${ROOT_DIR}/stdlib" DIVA_NO_EXTERNAL=1 \
       DI_RUNTIME_O="${ROOT_DIR}/bootstrap/runtime-linux-amd64.o" \
       timeout 300 "${ROOT_DIR}/bootstrap/diva-linux-amd64" build compiler "${DRIVER}" \
       >"${WORK}/driver-build.log" 2>&1; then
    sed -n '1,40p' "${WORK}/driver-build.log" >&2
    echo "[enums] driver build failed" >&2
    exit 1
  fi
fi

echo "[enums] DRIVER=${DRIVER}"

total=0
failed=0
fail() {
  failed=$((failed + 1))
  echo "[enums] FAIL $1" >&2
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
    printf '[enums] expected:\n%s\n[enums] actual:\n%s\n' "${_want}" "${_out}" >&2
    return 0
  fi
  echo "[enums] OK   ${_name}"
}

check_case unit "${ROOT_DIR}/tests/cases/enums/unit_enum.diva" '0
2
9
1'

check_case payload "${ROOT_DIR}/tests/cases/enums/payload_enum.diva" '0
0
1
42
0
0
7
5'

echo "[enums] total=${total} failed=${failed}"
[ "${failed}" -eq 0 ]

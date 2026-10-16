#!/usr/bin/env sh
# #123 key/value store module (stdlib/std/kv.diva).
#
# Builds and runs the focused kv cases against the pure-ELF native path and
# checks their stdout. `kv_basic` covers put/get/overwrite/del/missing/count/
# keys/iteration and an escaped save+load round-trip; `kv_stress` inserts 10k
# keys, checks every lookup, and round-trips them through save/load.
#
# Usage (repo root):
#   sh tests/kv.sh
# Optional: DIVA_PURE_DRIVER=/path/to/diva to pin a specific driver.
set -eu

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "${ROOT_DIR}"

if [ -n "${DIVA_PURE_DRIVER:-}" ] && [ -x "${DIVA_PURE_DRIVER}" ]; then
  DRIVER="${DIVA_PURE_DRIVER}"
elif [ -x "${ROOT_DIR}/build/diva-compiler-pure-elf" ]; then
  DRIVER="${ROOT_DIR}/build/diva-compiler-pure-elf"
else
  DRIVER="${ROOT_DIR}/build/diva-test"
fi
if [ ! -x "${DRIVER}" ]; then
  echo "[kv] missing driver: ${DRIVER}" >&2
  exit 1
fi

WORK="$(mktemp -d "${TMPDIR:-/tmp}/diva-kv.XXXXXX")"
trap 'rm -rf "${WORK}"' EXIT

echo "[kv] DRIVER=${DRIVER}"

total=0
failed=0
fail() {
  failed=$((failed + 1))
  echo "[kv] FAIL $1" >&2
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

# check_case <name> <src> <expected> <db path>
check_case() {
  _name=$1
  _src=$2
  _want=$3
  _db=$4
  total=$((total + 1))
  _exe="${WORK}/${_name}.exe"
  if ! build "${_src}" "${_exe}"; then
    fail "${_name} (build)"
    return 0
  fi
  if ! _out=$(timeout 60 "${_exe}" "${_db}" </dev/null 2>/dev/null); then
    fail "${_name} (run)"
    return 0
  fi
  if [ "${_out}" != "${_want}" ]; then
    fail "${_name} (output)"
    printf '[kv] expected:\n%s\n[kv] actual:\n%s\n' "${_want}" "${_out}" >&2
    return 0
  fi
  echo "[kv] OK   ${_name}"
}

check_case basic "${ROOT_DIR}/tests/cases/kv/kv_basic.diva" '0
c=3
a=1
d=4
failed=0' "${WORK}/basic.db"

check_case stress "${ROOT_DIR}/tests/cases/kv/kv_stress.diva" '10000
1
0
0
10000
1
5000
1' "${WORK}/stress.db"

echo "[kv] total=${total} failed=${failed}"
[ "${failed}" -eq 0 ]

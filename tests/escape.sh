#!/usr/bin/env sh
# Escape analysis (Issue #101) gate. Standalone like tests/cfg.sh; not wired
# into tests/run.sh. Usage: sh tests/escape.sh [DIVA_PURE_DRIVER=/path/to/diva]
set -eu

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "${ROOT_DIR}"

WORK="$(mktemp -d "${TMPDIR:-/tmp}/diva-escape.XXXXXX")"
trap 'rm -rf "${WORK}"' EXIT

if [ -n "${DIVA_PURE_DRIVER:-}" ] && [ -x "${DIVA_PURE_DRIVER}" ]; then
  DRIVER="${DIVA_PURE_DRIVER}"
elif [ -x "${ROOT_DIR}/build/diva-compiler-pure-elf-escape" ]; then
  DRIVER="${ROOT_DIR}/build/diva-compiler-pure-elf-escape"
else
  DRIVER="${WORK}/driver"
  echo "[escape] building driver from bootstrap seed"
  if ! ROOT_DIR="${ROOT_DIR}" DI_STDLIB_DIR="${ROOT_DIR}/stdlib" DIVA_NO_EXTERNAL=1 \
       DI_RUNTIME_O="${ROOT_DIR}/bootstrap/runtime-linux-amd64.o" \
       timeout 900 "${ROOT_DIR}/bootstrap/diva-linux-amd64" build compiler "${DRIVER}" \
       >"${WORK}/driver-build.log" 2>&1; then
    cat "${WORK}/driver-build.log" >&2
    echo "[escape] driver build failed" >&2
    exit 1
  fi
fi

echo "[escape] DRIVER=${DRIVER}"

total=0
failed=0
fail() {
  failed=$((failed + 1))
  echo "[escape] FAIL $1" >&2
}

assert_line() {
  if ! grep -F -- "$2" "$1" >/dev/null; then
    fail "missing '$2'"
    cat "$1" >&2
  fi
}

assert_clean_stderr() {
  if [ -s "${WORK}/err" ]; then
    fail "unexpected stderr"
    cat "${WORK}/err" >&2
  fi
}

analyze_case() {
  _name=$1
  _file="${ROOT_DIR}/tests/cases/escape/$2"
  total=$((total + 1))
  if ! DI_STDLIB_DIR="${ROOT_DIR}/stdlib" DIVA_NO_EXTERNAL=1 \
       DI_RUNTIME_O="${ROOT_DIR}/bootstrap/runtime-linux-amd64.o" \
       timeout 60 "${DRIVER}" analyze --escape "${_file}" \
       >"${WORK}/out" 2>"${WORK}/err"; then
    fail "${_name} (analyze exit)"
    cat "${WORK}/err" >&2
  fi
}

analyze_case global_store global_store.diva
assert_line "${WORK}/out" 'function leak: escaping=1 local=0'
assert_line "${WORK}/out" 'function keep: escaping=0 local=1'
assert_line "${WORK}/out" 'function main: escaping=0 local=0'
assert_line "${WORK}/err" 'warn: value escapes through global.store'
echo "[escape] OK   global_store (warning is non-fatal)"

analyze_case calls calls.diva
assert_line "${WORK}/out" 'function nonleaf: escaping=0 local=0'
assert_line "${WORK}/out" 'function leaf: escaping=0 local=0'
assert_line "${WORK}/out" 'function pass_nonleaf: escaping=1 local=0'
assert_line "${WORK}/out" 'function pass_leaf: escaping=0 local=1'
assert_line "${WORK}/out" 'function escaped_ret: escaping=1 local=0'
assert_line "${WORK}/out" 'function main: escaping=0 local=0'
assert_clean_stderr
echo "[escape] OK   calls"

analyze_case struct_field struct_field.diva
assert_line "${WORK}/out" 'function leak_field: escaping=2 local=0'
assert_line "${WORK}/err" 'warn: value escapes through global.store'
echo "[escape] OK   struct_field"

analyze_case indirect_global indirect_global.diva
assert_line "${WORK}/out" 'function leak_indirect: escaping=1 local=0'
assert_line "${WORK}/err" 'warn: value escapes through global.store'
echo "[escape] OK   indirect_global"

echo "[escape] total=${total} failed=${failed}"
[ "${failed}" -eq 0 ]

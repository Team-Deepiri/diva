#!/usr/bin/env sh
set -eu

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "${ROOT_DIR}"

WORK="$(mktemp -d "${TMPDIR:-/tmp}/diva-cfg.XXXXXX")"
trap 'rm -rf "${WORK}"' EXIT

if [ -n "${DIVA_PURE_DRIVER:-}" ] && [ -x "${DIVA_PURE_DRIVER}" ]; then
  DRIVER="${DIVA_PURE_DRIVER}"
elif [ -x "${ROOT_DIR}/build/diva-compiler-pure-elf-cfg" ]; then
  DRIVER="${ROOT_DIR}/build/diva-compiler-pure-elf-cfg"
else
  DRIVER="${WORK}/driver"
  echo "[cfg] building driver from bootstrap seed"
  if ! ROOT_DIR="${ROOT_DIR}" DI_STDLIB_DIR="${ROOT_DIR}/stdlib" DIVA_NO_EXTERNAL=1 \
       DI_RUNTIME_O="${ROOT_DIR}/bootstrap/runtime-linux-amd64.o" \
       timeout 900 "${ROOT_DIR}/bootstrap/diva-linux-amd64" build compiler "${DRIVER}" \
       >"${WORK}/driver-build.log" 2>&1; then
    cat "${WORK}/driver-build.log" >&2
    echo "[cfg] driver build failed" >&2
    exit 1
  fi
fi

echo "[cfg] DRIVER=${DRIVER}"

total=0
failed=0
fail() {
  failed=$((failed + 1))
  echo "[cfg] FAIL $1" >&2
}

assert_line() {
  if ! grep -F -- "$2" "$1" >/dev/null; then
    fail "missing '$2'"
    cat "$1" >&2
  fi
}

analyze_case() {
  _name=$1
  _file="${ROOT_DIR}/tests/cases/cfg/$2"
  total=$((total + 1))
  if ! DI_STDLIB_DIR="${ROOT_DIR}/stdlib" DIVA_NO_EXTERNAL=1 \
       DI_RUNTIME_O="${ROOT_DIR}/bootstrap/runtime-linux-amd64.o" \
       timeout 60 "${DRIVER}" analyze "${_file}" >"${WORK}/out" 2>"${WORK}/err"; then
    fail "${_name} (analyze exit)"
    cat "${WORK}/err" >&2
    return 0
  fi
  return 0
}

analyze_case if_branch if_branch.diva
assert_line "${WORK}/out" 'function pick: blocks=4 edges=4 unreachable=0'
assert_line "${WORK}/out" 'function main: blocks=1 edges=0 unreachable=0'
if [ -s "${WORK}/err" ]; then fail 'if_branch (unexpected stderr)'; fi
echo "[cfg] OK   if_branch"

analyze_case while_loop while_loop.diva
assert_line "${WORK}/out" 'function sum: blocks=4 edges=4 unreachable=0'
if [ -s "${WORK}/err" ]; then fail 'while_loop (unexpected stderr)'; fi
echo "[cfg] OK   while_loop"

analyze_case match_expr match_expr.diva
assert_line "${WORK}/out" 'function classify: blocks=10 edges=13 unreachable=0'
if [ -s "${WORK}/err" ]; then fail 'match_expr (unexpected stderr)'; fi
echo "[cfg] OK   match_expr"

analyze_case nested_control nested_control.diva
assert_line "${WORK}/out" 'function nested: blocks=14 edges=18 unreachable=0'
if [ -s "${WORK}/err" ]; then fail 'nested_control (unexpected stderr)'; fi
echo "[cfg] OK   nested_control"

analyze_case unreachable_after_ret unreachable_after_ret.diva
assert_line "${WORK}/out" 'function early: blocks=4 edges=3 unreachable=1'
assert_line "${WORK}/err" 'warn: early: unreachable instruction 7 (br) has no label target'
echo "[cfg] OK   unreachable_after_ret"

total=$((total + 1))
probe="${ROOT_DIR}/tests/cases/cfg/undefined_label_probe.diva"
if DI_STDLIB_DIR="${ROOT_DIR}/stdlib" DIVA_NO_EXTERNAL=1 \
     DI_RUNTIME_O="${ROOT_DIR}/bootstrap/runtime-linux-amd64.o" \
     timeout 60 "${DRIVER}" analyze --selftest-undefined-label "${probe}" \
     >"${WORK}/out" 2>"${WORK}/err"; then
  fail 'undefined_label (expected non-zero exit)'
else
  assert_line "${WORK}/err" 'cfg: error: undefined label 99 at instruction 0'
  assert_line "${WORK}/out" 'function probe: blocks=1 edges=0 unreachable=0'
  echo "[cfg] OK   undefined_label"
fi

echo "[cfg] total=${total} failed=${failed}"
[ "${failed}" -eq 0 ]

#!/usr/bin/env sh
# Issue #105: IR optimization pipeline smoke tests.
set -eu

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
WORK="$(mktemp -d "${TMPDIR:-/tmp}/diva-opts.XXXXXX")"
trap 'rm -rf "${WORK}"' EXIT

if [ -n "${DIVA_PURE_DRIVER:-}" ] && [ -x "${DIVA_PURE_DRIVER}" ]; then
  DRIVER="${DIVA_PURE_DRIVER}"
elif [ -x "${ROOT_DIR}/build/diva-compiler-pure-elf-opts" ]; then
  DRIVER="${ROOT_DIR}/build/diva-compiler-pure-elf-opts"
else
  DRIVER="${WORK}/driver"
  echo "[opt] building driver from bootstrap seed"
  if ! ROOT_DIR="${ROOT_DIR}" DI_STDLIB_DIR="${ROOT_DIR}/stdlib" DIVA_NO_EXTERNAL=1 \
       DI_RUNTIME_O="${ROOT_DIR}/bootstrap/runtime-linux-amd64.o" \
       timeout 1200 "${ROOT_DIR}/bootstrap/diva-linux-amd64" build compiler "${DRIVER}" \
       >"${WORK}/driver-build.log" 2>&1; then
    sed -n '1,60p' "${WORK}/driver-build.log" >&2
    echo "[opt] driver build failed" >&2
    exit 1
  fi
fi

echo "[opt] DRIVER=${DRIVER}"

total=0
failed=0
fail() {
  failed=$((failed + 1))
  echo "[opt] FAIL $1" >&2
}

driver() {
  DI_STDLIB_DIR="${ROOT_DIR}/stdlib" DIVA_NO_EXTERNAL=1 \
  DI_RUNTIME_O="${ROOT_DIR}/bootstrap/runtime-linux-amd64.o" \
  timeout 120 "${DRIVER}" "$@"
}

ir_dump() {
  _mode=$1
  _src=$2
  _out="${WORK}/ir-${_mode}.out"
  if [ "${_mode}" = "opt" ]; then
    if ! driver opt "${_src}" >"${_out}" 2>&1; then
      sed -n '1,80p' "${_out}" >&2
      fail "opt ir (${_src})"
      return 1
    fi
  else
    if ! driver opt --no-opt "${_src}" >"${_out}" 2>&1; then
      sed -n '1,80p' "${_out}" >&2
      fail "opt --no-opt ir (${_src})"
      return 1
    fi
  fi
  printf '%s\n' "${_out}"
}

assert_contains() {
  _file=$1
  _needle=$2
  _label=$3
  total=$((total + 1))
  if ! grep -F "${_needle}" "${_file}" >/dev/null; then
    fail "${_label}: missing '${_needle}'"
    sed -n '1,40p' "${_file}" >&2
  fi
}

assert_not_contains() {
  _file=$1
  _needle=$2
  _label=$3
  total=$((total + 1))
  if grep -F "${_needle}" "${_file}" >/dev/null; then
    fail "${_label}: unexpected '${_needle}'"
    sed -n '1,40p' "${_file}" >&2
  fi
}

check_run() {
  _name=$1
  _src=$2
  _want=$3
  total=$((total + 1))
  _exe="${WORK}/${_name}.exe"
  if ! DI_STDLIB_DIR="${ROOT_DIR}/stdlib" DIVA_NO_EXTERNAL=1 \
       DI_RUNTIME_O="${ROOT_DIR}/bootstrap/runtime-linux-amd64.o" \
       timeout 120 "${DRIVER}" build "${_src}" "${_exe}" >"${WORK}/${_name}.build.log" 2>&1; then
    sed -n '1,60p' "${WORK}/${_name}.build.log" >&2
    fail "${_name} (build)"
    return 0
  fi
  if ! _got=$(timeout 60 "${_exe}" </dev/null 2>/dev/null); then
    fail "${_name} (run)"
    return 0
  fi
  if [ "${_got}" != "${_want}" ]; then
    fail "${_name} (output)"
    printf '[opt] expected:\n%s\n[opt] actual:\n%s\n' "${_want}" "${_got}" >&2
    return 0
  fi
  echo "[opt] OK   ${_name} (runtime)"
}

CASES="${ROOT_DIR}/tests/cases/opt"

FOLD_BEFORE=$(ir_dump raw "${CASES}/folding.diva")
FOLD_AFTER=$(ir_dump opt "${CASES}/folding.diva")

assert_contains "${FOLD_BEFORE}" "v4 = mul v2, v3" "folding-before"
assert_contains "${FOLD_BEFORE}" "v5 = add v1, v4" "folding-before"
assert_contains "${FOLD_AFTER}" "v5 = const 14" "folding-after"
assert_not_contains "${FOLD_AFTER}" "v4 = mul v2, v3" "folding-after"
assert_not_contains "${FOLD_AFTER}" "v2 = const 3" "folding-after-dce"

ALG_BEFORE=$(ir_dump raw "${CASES}/algebraic.diva")
ALG_AFTER=$(ir_dump opt "${CASES}/algebraic.diva")

assert_contains "${ALG_BEFORE}" "v3 = add v1, v2" "algebraic-before"
assert_contains "${ALG_BEFORE}" "v3 = xor v1, v2" "algebraic-before"
assert_contains "${ALG_AFTER}" "v3 = v1" "algebraic-after-copy"
assert_contains "${ALG_AFTER}" "v3 = const 0" "algebraic-after-absorbing"
assert_not_contains "${ALG_AFTER}" "v3 = add v1, v2" "algebraic-after"

CONS_AFTER=$(ir_dump opt "${CASES}/conservative.diva")
assert_contains "${CONS_AFTER}" "const -17" "unary-minus"
assert_contains "${CONS_AFTER}" "div v" "variable-divisor-preserved"

SIDE_AFTER=$(ir_dump opt "${CASES}/side_effects.diva")
assert_contains "${SIDE_AFTER}" "call print_int" "call-preserved"
assert_contains "${SIDE_AFTER}" "store v" "store-preserved"
assert_contains "${SIDE_AFTER}" "br.cond" "branch-preserved"

total=$((total + 1))
if driver opt >"${WORK}/no-arg.out" 2>&1; then
  fail "opt without file should fail"
fi

check_run folding "${CASES}/folding.diva" '14'
check_run side_effects "${CASES}/side_effects.diva" '3
11
4'
check_run semantics "${CASES}/semantics.diva" '41
7
0
13
3
6
3
15
32
8
8
2
1
0
17'

echo "[opt] total=${total} failed=${failed}"
[ "${failed}" -eq 0 ]

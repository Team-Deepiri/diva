#!/usr/bin/env sh
# Issue #116: cross-function IR inlining / whole-program LTO foundation.
set -eu

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
WORK="$(mktemp -d "${TMPDIR:-/tmp}/diva-lto.XXXXXX")"
trap 'rm -rf "${WORK}"' EXIT

if [ -n "${DIVA_PURE_DRIVER:-}" ] && [ -x "${DIVA_PURE_DRIVER}" ]; then
  DRIVER="${DIVA_PURE_DRIVER}"
elif [ -x "${ROOT_DIR}/build/diva-compiler-pure-elf-lto" ]; then
  DRIVER="${ROOT_DIR}/build/diva-compiler-pure-elf-lto"
else
  DRIVER="${WORK}/driver"
  echo "[lto] building driver from bootstrap seed"
  if ! ROOT_DIR="${ROOT_DIR}" DI_STDLIB_DIR="${ROOT_DIR}/stdlib" DIVA_NO_EXTERNAL=1 \
       DI_RUNTIME_O="${ROOT_DIR}/bootstrap/runtime-linux-amd64.o" \
       timeout 1200 "${ROOT_DIR}/bootstrap/diva-linux-amd64" build compiler "${DRIVER}" \
       >"${WORK}/driver-build.log" 2>&1; then
    sed -n '1,60p' "${WORK}/driver-build.log" >&2
    echo "[lto] driver build failed" >&2
    exit 1
  fi
fi

echo "[lto] DRIVER=${DRIVER}"

total=0
failed=0
fail() {
  failed=$((failed + 1))
  echo "[lto] FAIL $1" >&2
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
  case "${_mode}" in
    *off)
    if ! driver opt --no-inline "${_src}" >"${_out}" 2>&1; then
      sed -n '1,80p' "${_out}" >&2
      fail "opt --no-inline (${_src})"
      return 1
    fi
      ;;
    *)
    if ! driver opt "${_src}" >"${_out}" 2>&1; then
      sed -n '1,80p' "${_out}" >&2
      fail "opt (${_src})"
      return 1
    fi
      ;;
  esac
  printf '%s\n' "${_out}"
}

assert_contains() {
  _file=$1
  _needle=$2
  _label=$3
  total=$((total + 1))
  if ! grep -F -- "${_needle}" "${_file}" >/dev/null; then
    fail "${_label}: missing '${_needle}'"
    sed -n '1,20p' "${_file}" >&2
  fi
}

assert_not_contains() {
  _file=$1
  _needle=$2
  _label=$3
  total=$((total + 1))
  if grep -F -- "${_needle}" "${_file}" >/dev/null; then
    fail "${_label}: unexpected '${_needle}'"
    sed -n '1,20p' "${_file}" >&2
  fi
}

check_runtime() {
  _name=$1
  _src=$2
  _want=$3
  total=$((total + 1))
  _on="${WORK}/${_name}.on.exe"
  _off="${WORK}/${_name}.off.exe"
  if ! DI_STDLIB_DIR="${ROOT_DIR}/stdlib" DIVA_NO_EXTERNAL=1 \
       DI_RUNTIME_O="${ROOT_DIR}/bootstrap/runtime-linux-amd64.o" \
       timeout 120 "${DRIVER}" build "${_src}" "${_on}" >"${WORK}/${_name}.on.build.log" 2>&1; then
    sed -n '1,60p' "${WORK}/${_name}.on.build.log" >&2
    fail "${_name} (build with inlining)"
    return 0
  fi
  if ! DI_STDLIB_DIR="${ROOT_DIR}/stdlib" DIVA_NO_EXTERNAL=1 \
       DI_RUNTIME_O="${ROOT_DIR}/bootstrap/runtime-linux-amd64.o" \
       timeout 120 "${DRIVER}" build --no-inline "${_src}" "${_off}" >"${WORK}/${_name}.off.build.log" 2>&1; then
    sed -n '1,60p' "${WORK}/${_name}.off.build.log" >&2
    fail "${_name} (build --no-inline)"
    return 0
  fi
  _got_on=$(timeout 60 "${_on}" </dev/null 2>/dev/null) || {
    fail "${_name} (run with inlining)"
    return 0
  }
  _got_off=$(timeout 60 "${_off}" </dev/null 2>/dev/null) || {
    fail "${_name} (run --no-inline)"
    return 0
  }
  if [ "${_got_on}" != "${_want}" ] || [ "${_got_off}" != "${_want}" ]; then
    fail "${_name} (output: on='${_got_on}' off='${_got_off}' want='${_want}')"
    return 0
  fi
  echo "[lto] OK   ${_name} (runtime, both modes)"
}

CASES="${ROOT_DIR}/tests/cases/lto"

LEAF_ON=$(ir_dump leaf-on "${CASES}/leaf.diva")
LEAF_OFF=$(ir_dump leaf-off "${CASES}/leaf.diva")
assert_not_contains "${LEAF_ON}" "func inc(" "leaf-inlined"
assert_not_contains "${LEAF_ON}" "call inc argc" "leaf-inlined"
assert_not_contains "${LEAF_ON}" "func sum3(" "leaf-inlined"
assert_not_contains "${LEAF_ON}" "call sum3 argc" "leaf-inlined"
assert_not_contains "${LEAF_ON}" "func store_g(" "leaf-inlined"
assert_not_contains "${LEAF_ON}" "call store_g argc" "leaf-inlined"
assert_contains "${LEAF_ON}" "global.store" "leaf-global-preserved"
assert_contains "${LEAF_ON}" "call print_int argc" "extern-call-preserved"
assert_contains "${LEAF_OFF}" "func inc(" "no-inline-leaf"
assert_contains "${LEAF_OFF}" "call inc argc" "no-inline-leaf"
assert_contains "${LEAF_OFF}" "func sum3(" "no-inline-leaf"
assert_contains "${LEAF_OFF}" "func store_g(" "no-inline-leaf"
check_runtime leaf "${CASES}/leaf.diva" "$(printf '42\n9\n7\n2')"

REC_ON=$(ir_dump rec-on "${CASES}/recursive.diva")
assert_contains "${REC_ON}" "func fact(" "recursive-preserved"
assert_contains "${REC_ON}" "call fact argc" "recursive-preserved"
check_runtime recursive "${CASES}/recursive.diva" "120"

MB_ON=$(ir_dump mb-on "${CASES}/multiblock.diva")
assert_contains "${MB_ON}" "func choose(" "multiblock-preserved"
assert_contains "${MB_ON}" "call choose argc" "multiblock-preserved"
check_runtime multiblock "${CASES}/multiblock.diva" "$(printf '12\n0')"

BIG_ON=$(ir_dump big-on "${CASES}/large.diva")
assert_contains "${BIG_ON}" "func big(" "size-threshold-preserved"
assert_contains "${BIG_ON}" "call big argc" "size-threshold-preserved"
check_runtime large "${CASES}/large.diva" "24"

echo "[lto] total=${total} failed=${failed}"
[ "${failed}" -eq 0 ]

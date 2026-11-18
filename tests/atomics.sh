#!/usr/bin/env sh
# Issue #98: atomic memory builtins (load/store/add/xchg/cas + mfence).
#
# Self-contained: with no DIVA_PURE_DRIVER set, builds a fresh driver from the
# bootstrap seed. Checks runtime semantics, the unsafe requirement, IR lowering,
# and both x86-64 backends (assembly text and pure bytes).
#
# Usage (repo root):
#   sh tests/atomics.sh
# Optional: DIVA_PURE_DRIVER=/path/to/diva to pin a specific driver.
set -eu

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "${ROOT_DIR}"

WORK="$(mktemp -d "${TMPDIR:-/tmp}/diva-atomics.XXXXXX")"
trap 'rm -rf "${WORK}"' EXIT

if [ -n "${DIVA_PURE_DRIVER:-}" ] && [ -x "${DIVA_PURE_DRIVER}" ]; then
  DRIVER="${DIVA_PURE_DRIVER}"
else
  DRIVER="${WORK}/driver"
  echo "[atomics] building driver from bootstrap seed"
  if ! ROOT_DIR="${ROOT_DIR}" DI_STDLIB_DIR="${ROOT_DIR}/stdlib" DIVA_NO_EXTERNAL=1 \
       DI_RUNTIME_O="${ROOT_DIR}/bootstrap/runtime-linux-amd64.o" \
       timeout 300 "${ROOT_DIR}/bootstrap/diva-linux-amd64" build compiler "${DRIVER}" \
       >"${WORK}/driver-build.log" 2>&1; then
    sed -n '1,40p' "${WORK}/driver-build.log" >&2
    echo "[atomics] driver build failed" >&2
    exit 1
  fi
fi

echo "[atomics] DRIVER=${DRIVER}"

total=0
failed=0
fail() {
  failed=$((failed + 1))
  echo "[atomics] FAIL $1" >&2
}

build_env() {
  DI_STDLIB_DIR="${ROOT_DIR}/stdlib" DIVA_NO_EXTERNAL=1 \
    DI_RUNTIME_O="${ROOT_DIR}/bootstrap/runtime-linux-amd64.o" "$@"
}

# check_rc <name> <src> <expected_exit>
check_rc() {
  _name=$1
  _src=$2
  _want=$3
  total=$((total + 1))
  _exe="${WORK}/${_name}.exe"
  if ! build_env timeout 60 "${DRIVER}" build "${_src}" "${_exe}" >"${WORK}/${_name}.build.log" 2>&1; then
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
  echo "[atomics] OK   ${_name}"
}

# check_fail <name> <src> <needle>
check_fail() {
  _name=$1
  _src=$2
  _needle=$3
  total=$((total + 1))
  if build_env timeout 60 "${DRIVER}" build "${_src}" "${WORK}/${_name}.exe" \
      >"${WORK}/${_name}.log" 2>&1; then
    fail "${_name} (expected build failure)"
    return 0
  fi
  if ! grep -F "${_needle}" "${WORK}/${_name}.log" >/dev/null; then
    fail "${_name} (missing needle '${_needle}')"
    sed -n '1,20p' "${WORK}/${_name}.log" >&2
    return 0
  fi
  echo "[atomics] OK   ${_name} (fail)"
}

# check_text <name> <src> <needle> — assembly-text backend
check_text() {
  _name=$1
  _src=$2
  _needle=$3
  total=$((total + 1))
  if ! build_env timeout 60 "${DRIVER}" asm "${_src}" >"${WORK}/${_name}.s" 2>&1; then
    fail "${_name} (asm)"
    sed -n '1,40p' "${WORK}/${_name}.s" >&2
    return 0
  fi
  if ! grep -F "${_needle}" "${WORK}/${_name}.s" >/dev/null; then
    fail "${_name} (missing assembly '${_needle}')"
    return 0
  fi
  echo "[atomics] OK   ${_name} (asm)"
}

# check_ir <name> <src> <needle>
check_ir() {
  _name=$1
  _src=$2
  _needle=$3
  total=$((total + 1))
  if ! build_env timeout 60 "${DRIVER}" emit-ir "${_src}" >"${WORK}/${_name}.ir" 2>&1; then
    fail "${_name} (emit-ir)"
    sed -n '1,40p' "${WORK}/${_name}.ir" >&2
    return 0
  fi
  if ! grep -F "${_needle}" "${WORK}/${_name}.ir" >/dev/null; then
    fail "${_name} (missing IR '${_needle}')"
    return 0
  fi
  echo "[atomics] OK   ${_name} (ir)"
}

CASES="${ROOT_DIR}/tests/cases/atomics"

check_rc load_store  "${CASES}/load_store.diva"  42
check_rc add         "${CASES}/add.diva"         42
check_rc xchg        "${CASES}/xchg.diva"        42
check_rc cas_success "${CASES}/cas_success.diva" 42
check_rc cas_fail    "${CASES}/cas_fail.diva"    42
check_rc fence       "${CASES}/fence.diva"       42

UNSAFE_MSG="atomic operation requires an unsafe block"
check_fail unsafe_load  "${CASES}/outside_load.diva"  "${UNSAFE_MSG}"
check_fail unsafe_store "${CASES}/outside_store.diva" "${UNSAFE_MSG}"
check_fail unsafe_add   "${CASES}/outside_add.diva"   "${UNSAFE_MSG}"
check_fail unsafe_xchg  "${CASES}/outside_xchg.diva"  "${UNSAFE_MSG}"
check_fail unsafe_cas   "${CASES}/outside_cas.diva"   "${UNSAFE_MSG}"
check_fail unsafe_fence "${CASES}/outside_fence.diva" "${UNSAFE_MSG}"

check_ir ir_load  "${CASES}/load_store.diva"  "atomic.load"
check_ir ir_store "${CASES}/load_store.diva"  "atomic.store"
check_ir ir_add   "${CASES}/add.diva"         "atomic.add"
check_ir ir_xchg  "${CASES}/xchg.diva"        "atomic.xchg"
check_ir ir_cas   "${CASES}/cas_success.diva" "atomic.cas"
check_ir ir_fence "${CASES}/fence.diva"       "fence"

check_text asm_load  "${CASES}/load_store.diva"  "movq (%rax), %rdx"
check_text asm_store "${CASES}/load_store.diva"  "movq %rdx, (%rax)"
check_text asm_add   "${CASES}/add.diva"         "lock xaddq %rdx, (%rax)"
check_text asm_xchg  "${CASES}/xchg.diva"        "xchgq %rdx, (%rax)"
check_text asm_cas   "${CASES}/cas_success.diva" "lock cmpxchgq %rcx, (%rdx)"
check_text asm_fence "${CASES}/fence.diva"       "mfence"

echo "[atomics] total=${total} failed=${failed}"
[ "${failed}" -eq 0 ]

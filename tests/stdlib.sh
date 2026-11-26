#!/usr/bin/env sh
set -eu

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "${ROOT_DIR}"

WORK="$(mktemp -d "${TMPDIR:-/tmp}/diva-stdlib.XXXXXX")"
trap 'rm -rf "${WORK}"' EXIT

if [ -n "${DIVA_PURE_DRIVER:-}" ] && [ -x "${DIVA_PURE_DRIVER}" ]; then
  DRIVER="${DIVA_PURE_DRIVER}"
else
  DRIVER="${WORK}/driver"
  echo "[stdlib] building driver from bootstrap seed"
  if ! ROOT_DIR="${ROOT_DIR}" DI_STDLIB_DIR="${ROOT_DIR}/stdlib" DIVA_NO_EXTERNAL=1 \
       DI_RUNTIME_O="${ROOT_DIR}/bootstrap/runtime-linux-amd64.o" \
       timeout 600 "${ROOT_DIR}/bootstrap/diva-linux-amd64" build compiler "${DRIVER}" \
       >"${WORK}/driver-build.log" 2>&1; then
    sed -n '1,60p' "${WORK}/driver-build.log" >&2
    echo "[stdlib] driver build failed" >&2
    exit 1
  fi
fi

echo "[stdlib] DRIVER=${DRIVER}"

export DI_STDLIB_DIR="${ROOT_DIR}/stdlib"
export DIVA_NO_EXTERNAL=1
export DI_RUNTIME_O="${ROOT_DIR}/bootstrap/runtime-linux-amd64.o"
export DIVA_STDLIB_TEST_ENV=diva-stdlib-ok
unset DIVA_STDLIB_MISSING_XYZ 2>/dev/null || true

total=0
failed=0

fail() {
  failed=$((failed + 1))
  echo "[stdlib] FAIL $1" >&2
}

check_rc() {
  _name=$1
  _src=$2
  _want=$3
  shift 3
  total=$((total + 1))
  _exe="${WORK}/${_name}.exe"
  if ! timeout 60 "${DRIVER}" build "${_src}" "${_exe}" >"${WORK}/${_name}.build.log" 2>&1; then
    fail "${_name} (build)"
    sed -n '1,60p' "${WORK}/${_name}.build.log" >&2
    return 0
  fi
  set +e
  timeout 60 "${_exe}" "$@" </dev/null >/dev/null 2>&1
  _rc=$?
  set -e
  if [ "${_rc}" -ne "${_want}" ]; then
    fail "${_name} (exit ${_rc}, want ${_want})"
    return 0
  fi
  echo "[stdlib] OK   ${_name}"
}

CASES="${ROOT_DIR}/tests/cases/stdlib"

check_rc sync_lock      "${CASES}/sync_lock.diva"      42
check_rc fmt_basic      "${CASES}/fmt_basic.diva"      42
check_rc fs_roundtrip   "${CASES}/fs_roundtrip.diva"   42 "${WORK}/roundtrip.txt"
check_rc process_env    "${CASES}/process_env.diva"    42
check_rc time_clock     "${CASES}/time_clock.diva"     42
check_rc imports_together "${CASES}/imports_together.diva" 42

echo "[stdlib] total=${total} failed=${failed}"
[ "${failed}" -eq 0 ]

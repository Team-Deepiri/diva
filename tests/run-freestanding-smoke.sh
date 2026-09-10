#!/usr/bin/env bash
# Issue #30: freestanding demo + system template smoke.
set -euo pipefail
ROOT_DIR="$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)"
cd "${ROOT_DIR}"
DRIVER="${ROOT_DIR}/build/diva-compiler-pure-elf"
if [ ! -x "${DRIVER}" ]; then
  DRIVER="${DIVA:-${ROOT_DIR}/bootstrap/diva-linux-amd64}"
fi
export DI_STDLIB_DIR="${ROOT_DIR}/stdlib" DIVA_NO_EXTERNAL=1 DIVA_FREESTANDING=1
export DI_RUNTIME_O="${ROOT_DIR}/bootstrap/runtime-linux-amd64.o"
WORK="$(mktemp -d "/tmp/diva_fs_XXXX")"
trap 'rm -rf "${WORK}"' EXIT
if ! DIVA_NATIVE_EXE_OUT="${WORK}/fs" \
  "${DRIVER}" build "${ROOT_DIR}/examples/freestanding_demo.diva" >"${WORK}/log" 2>&1; then
  echo "[freestanding] FAIL build demo" >&2
  sed -n '1,20p' "${WORK}/log" >&2
  exit 1
fi
if ! "${DRIVER}" new "${WORK}/pkg" --system >"${WORK}/new.log" 2>&1; then
  echo "[freestanding] FAIL diva new --system" >&2
  exit 1
fi
if ! "${DRIVER}" check "${WORK}/pkg" >"${WORK}/chk.log" 2>&1; then
  echo "[freestanding] FAIL check system pkg" >&2
  exit 1
fi
echo "[freestanding] OK"

#!/usr/bin/env bash
# Issue #26: generic monomorphization + generic class parse smoke.
set -euo pipefail
ROOT_DIR="$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)"
cd "${ROOT_DIR}"
DRIVER="${ROOT_DIR}/build/diva-compiler-pure-elf"
if [ ! -x "${DRIVER}" ]; then
  DRIVER="${DIVA:-${ROOT_DIR}/bootstrap/diva-linux-amd64}"
fi
export DI_STDLIB_DIR="${ROOT_DIR}/stdlib" DIVA_NO_EXTERNAL=1
export DI_RUNTIME_O="${ROOT_DIR}/bootstrap/runtime-linux-amd64.o"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/diva-generics.XXXXXX")"
trap 'rm -rf "${WORK}"' EXIT
for src in examples/generics.diva examples/generic_class.diva; do
  if ! DIVA_NATIVE_EXE_OUT="${WORK}/out" "${DRIVER}" build "${ROOT_DIR}/${src}" >/dev/null 2>&1; then
    echo "[generics] FAIL build ${src}" >&2
    exit 1
  fi
  echo "[generics] OK   ${src}"
done

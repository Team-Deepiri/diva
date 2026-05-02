#!/bin/sh
# Full end-to-end: compile the whole compiler package as a pure ELF (no cc/ld, no runtime.o).
# Uses the pinned bootstrap seed by default (override with DRIVER=/path/to/diva).
#
# Usage (repo root):
#   sh scripts/verify-pure-compiler-build.sh
# Optional:
#   LOG=/tmp/pure-compiler.log sh scripts/verify-pure-compiler-build.sh
set -eu

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "${ROOT_DIR}"

SEED="${ROOT_DIR}/bootstrap/diva-linux-amd64"
DRIVER="${DRIVER:-${SEED}}"
if ! test -x "${DRIVER}"; then
  echo "[verify-pure-compiler] missing executable DRIVER or seed: ${DRIVER}" >&2
  exit 1
fi

export ROOT_DIR
export DI_STDLIB_DIR="${DI_STDLIB_DIR:-${ROOT_DIR}/stdlib}"
export DIVA_NO_EXTERNAL=1
export DI_RUNTIME_O="${DI_RUNTIME_O:-${ROOT_DIR}/bootstrap/runtime-linux-amd64.o}"

LOG="${LOG:-${ROOT_DIR}/build/.pure-elf-compiler/verify-build.log}"
mkdir -p "$(dirname "${LOG}")"

echo "[verify-pure-compiler] DRIVER=${DRIVER}"
echo "[verify-pure-compiler] logging to ${LOG}"
echo "[verify-pure-compiler] start $(date -Is)"
set +e
ROOT_DIR="${ROOT_DIR}" DI_STDLIB_DIR="${DI_STDLIB_DIR}" DIVA_NO_EXTERNAL=1 \
  DI_RUNTIME_O="${DI_RUNTIME_O}" \
  "${DRIVER}" build "${ROOT_DIR}/compiler" >"${LOG}" 2>&1
rc=$?
set -e
echo "[verify-pure-compiler] end $(date -Is) rc=${rc}"

if test "${rc}" -ne 0; then
  echo "[verify-pure-compiler] FAILED; tail ${LOG}:" >&2
  tail -n 60 "${LOG}" >&2
  exit "${rc}"
fi

if ! test -x /tmp/diva-native-exe; then
  echo "[verify-pure-compiler] build claimed success but /tmp/diva-native-exe missing" >&2
  exit 1
fi

sz=$(wc -c </tmp/diva-native-exe)
echo "[verify-pure-compiler] OK -> /tmp/diva-native-exe (${sz} bytes)"
exit 0

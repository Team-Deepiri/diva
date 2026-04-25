#!/bin/sh
# Full end-to-end: compile the whole compiler package as a pure ELF (no cc/ld, no runtime.o).
# Requires ./build/diva-stage2 (build once with scripts/build-compiler-cc-link.sh if missing).
#
# Usage (repo root):
#   sh scripts/verify-pure-compiler-build.sh
# Optional:
#   LOG=/tmp/pure-compiler.log sh scripts/verify-pure-compiler-build.sh
set -eu

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "${ROOT_DIR}"

if ! test -x "${ROOT_DIR}/build/diva-stage2"; then
  echo "[verify-pure-compiler] missing ./build/diva-stage2; run scripts/build-compiler-cc-link.sh first" >&2
  exit 1
fi

export ROOT_DIR
export DI_STDLIB_DIR="${DI_STDLIB_DIR:-${ROOT_DIR}/stdlib}"
export DIVA_NO_EXTERNAL=1
unset DI_RUNTIME_O 2>/dev/null || true

LOG="${LOG:-${ROOT_DIR}/build/.pure-elf-compiler/verify-build.log}"
mkdir -p "$(dirname "${LOG}")"

echo "[verify-pure-compiler] logging to ${LOG}"
echo "[verify-pure-compiler] start $(date -Is)"
set +e
"${ROOT_DIR}/build/diva-stage2" build "${ROOT_DIR}/compiler" >"${LOG}" 2>&1
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

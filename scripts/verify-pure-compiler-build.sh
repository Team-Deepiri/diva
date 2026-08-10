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
DRIVER="${DRIVER:-}"
if [ -z "${DRIVER}" ]; then
  for cand in "${ROOT_DIR}/build/diva-stage2-boot" "${ROOT_DIR}/build/diva-stage2" "${SEED}"; do
    if test -x "${cand}"; then
      DRIVER="${cand}"
      break
    fi
  done
fi
if ! test -x "${DRIVER}"; then
  echo "[verify-pure-compiler] missing executable DRIVER (set DRIVER= or build scripts/legacy/build-compiler-cc-link.sh)" >&2
  exit 1
fi

export ROOT_DIR
export DI_STDLIB_DIR="${DI_STDLIB_DIR:-${ROOT_DIR}/stdlib}"
export DIVA_NO_EXTERNAL=1
export DI_RUNTIME_O="${DI_RUNTIME_O:-${ROOT_DIR}/bootstrap/runtime-linux-amd64.o}"
# Pinned seed may lag new externs until promoted; gcc-linked stage2 does not. Default skip only for seed.
if [ "${DRIVER}" = "${SEED}" ]; then
  export DIVA_SKIP_NATIVE_EXTERN_CHECK="${DIVA_SKIP_NATIVE_EXTERN_CHECK:-1}"
else
  export DIVA_SKIP_NATIVE_EXTERN_CHECK="${DIVA_SKIP_NATIVE_EXTERN_CHECK:-}"
fi

LOG="${LOG:-${ROOT_DIR}/build/.pure-elf-compiler/verify-build.log}"
mkdir -p "$(dirname "${LOG}")"

OUT_EXE="${OUT_EXE:-${ROOT_DIR}/build/diva-compiler-pure-elf}"
DEFAULT_EXE="${ROOT_DIR}/build/diva-native-exe"

echo "[verify-pure-compiler] DRIVER=${DRIVER}"
echo "[verify-pure-compiler] logging to ${LOG}"
echo "[verify-pure-compiler] start $(date -Is)"
set +e
ROOT_DIR="${ROOT_DIR}" DI_STDLIB_DIR="${DI_STDLIB_DIR}" DIVA_NO_EXTERNAL=1 \
  DI_RUNTIME_O="${DI_RUNTIME_O}" \
  "${DRIVER}" build "${ROOT_DIR}/compiler" "${OUT_EXE}" >"${LOG}" 2>&1
rc=$?
set -e
echo "[verify-pure-compiler] end $(date -Is) rc=${rc}"

if test "${rc}" -ne 0; then
  echo "[verify-pure-compiler] FAILED; tail ${LOG}:" >&2
  tail -n 60 "${LOG}" >&2
  exit "${rc}"
fi

CAND="${OUT_EXE}"
if ! test -x "${CAND}"; then
  if test -x "${DEFAULT_EXE}"; then
    CAND="${DEFAULT_EXE}"
  elif test -x /tmp/diva-native-exe; then
    CAND=/tmp/diva-native-exe
  else
    echo "[verify-pure-compiler] build claimed success but missing ${OUT_EXE} (also tried ${DEFAULT_EXE}, /tmp/diva-native-exe)" >&2
    exit 1
  fi
fi

sz=$(wc -c <"${CAND}")
echo "[verify-pure-compiler] OK -> ${CAND} (${sz} bytes)"
exit 0

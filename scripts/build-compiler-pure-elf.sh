#!/usr/bin/env bash
# Build the merged compiler driver as a single ELF using only Diva's in-process emitter
# (no cc/ld/runtime.o). Uses the pinned seed unless DRIVER or ./build/diva-compiler-pure-elf is set.
#
# Usage (repo root):
#   ./scripts/build-compiler-pure-elf.sh
#
# Output: ./build/diva-compiler-pure-elf (override with OUT_EXE=...)
set -euo pipefail

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "${ROOT_DIR}"

WORK="${ROOT_DIR}/build/.pure-elf-compiler"
OUT_EXE="${OUT_EXE:-${ROOT_DIR}/build/diva-compiler-pure-elf}"
mkdir -p "${WORK}"

DRIVER="${DRIVER:-}"
if [[ -z "${DRIVER}" ]]; then
  if [[ -x "${ROOT_DIR}/build/diva-compiler-pure-elf" ]]; then
    DRIVER="${ROOT_DIR}/build/diva-compiler-pure-elf"
  else
    DRIVER="${ROOT_DIR}/bootstrap/diva-linux-amd64"
  fi
fi
if [[ ! -x "${DRIVER}" ]]; then
  echo "build-compiler-pure-elf: need executable DRIVER or bootstrap seed at bootstrap/diva-linux-amd64" >&2
  exit 1
fi

DI_STDLIB_DIR="${DI_STDLIB_DIR:-${ROOT_DIR}/stdlib}"
export DI_STDLIB_DIR ROOT_DIR

export DIVA_NO_EXTERNAL=1
# Pinned seed still expects DI_RUNTIME_O to point at a file; driver uses pure ELF emit regardless.
export DI_RUNTIME_O="${DI_RUNTIME_O:-${ROOT_DIR}/bootstrap/runtime-linux-amd64.o}"

LOG="${WORK}/build.log"
PKG="${ROOT_DIR}/compiler"
# Full compiler package can take 12–20+ minutes on slower hosts; override with BUILD_TIMEOUT_SECS.
BUILD_TIMEOUT_SECS="${BUILD_TIMEOUT_SECS:-1800}"
echo "[pure-elf-compiler] ${DRIVER} build ${PKG} ${OUT_EXE} (DIVA_NO_EXTERNAL=1, DI_RUNTIME_O=${DI_RUNTIME_O}, timeout=${BUILD_TIMEOUT_SECS}s)"
set +e
if command -v stdbuf >/dev/null 2>&1; then
  timeout "${BUILD_TIMEOUT_SECS}" stdbuf -o0 -e0 "${DRIVER}" build "${PKG}" "${OUT_EXE}" >"${LOG}" 2>&1
else
  timeout "${BUILD_TIMEOUT_SECS}" "${DRIVER}" build "${PKG}" "${OUT_EXE}" >"${LOG}" 2>&1
fi
RC=$?
set -e
if [[ "${RC}" -ne 0 ]]; then
  if [[ "${RC}" -eq 124 ]]; then
    echo "[pure-elf-compiler] build timed out after ${BUILD_TIMEOUT_SECS}s" >&2
  else
    echo "[pure-elf-compiler] build failed (exit=${RC}); first lines of ${LOG}:" >&2
  fi
  sed -n '1,80p' "${LOG}" >&2
  exit 1
fi

# Drivers that still hardcode /tmp: rescue. Prefer OUT_EXE when the CLI path is honored.
CAND="${OUT_EXE}"
if [[ ! -x "${CAND}" ]]; then
  if [[ -x /tmp/diva-native-exe ]]; then
    cp -f /tmp/diva-native-exe "${OUT_EXE}"
    chmod +x "${OUT_EXE}"
    CAND="${OUT_EXE}"
  elif [[ -x "${ROOT_DIR}/build/diva-native-exe" ]]; then
    cp -f "${ROOT_DIR}/build/diva-native-exe" "${OUT_EXE}"
    chmod +x "${OUT_EXE}"
    CAND="${OUT_EXE}"
  else
    echo "[pure-elf-compiler] missing executable after build (tried ${OUT_EXE}, build/diva-native-exe, /tmp/diva-native-exe)" >&2
    exit 1
  fi
fi

chmod +x "${OUT_EXE}"
echo "[pure-elf-compiler] OK -> ${OUT_EXE}"

#!/usr/bin/env sh
# Rebuild the compiler driver using only Diva: merge sources (Python), then seed `diva build`
# on the merged file under compiler/src/ so import paths match the package layout.
# Writes the executable to OUT (default: build/diva-driver-merged).
set -eu

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "${ROOT_DIR}"

SEED="${SEED:-${ROOT_DIR}/bootstrap/diva-linux-amd64}"
DI_STDLIB_DIR="${DI_STDLIB_DIR:-${ROOT_DIR}/stdlib}"
export DI_STDLIB_DIR

OUT_EXE="${1:-${ROOT_DIR}/build/diva-driver-merged}"
OUT_DIVA="${ROOT_DIR}/compiler/src/_bootstrap_merged.diva"
BUILD_LOG="${ROOT_DIR}/build/.merged-driver-build.log"

mkdir -p "${ROOT_DIR}/build"

echo "[merged-driver] merging compiler/ -> ${OUT_DIVA}"
ROOT_DIR="${ROOT_DIR}" DI_STDLIB_DIR="${DI_STDLIB_DIR}" python3 "${ROOT_DIR}/scripts/merge_compiler_package.py" >"${OUT_DIVA}"

echo "[merged-driver] build (seed native ELF) -> ${OUT_EXE}"
if ! "${SEED}" build "${OUT_DIVA}" >"${BUILD_LOG}" 2>&1
then
  echo "[merged-driver] seed build failed; log ${BUILD_LOG}:" >&2
  sed -n '1,60p' "${BUILD_LOG}" >&2
  exit 1
fi

if [ ! -x /tmp/diva-native-exe ]; then
  echo "[merged-driver] expected /tmp/diva-native-exe from diva build" >&2
  exit 1
fi

cp -f /tmp/diva-native-exe "${OUT_EXE}"
chmod +x "${OUT_EXE}"
echo "[merged-driver] OK: ${OUT_EXE}"

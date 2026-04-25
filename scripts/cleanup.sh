#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
BUILD_DIR="${ROOT_DIR}/build"

DRY_RUN=0
if [[ "${1:-}" == "--dry-run" ]]; then
  DRY_RUN=1
fi

TARGETS=(
  "${BUILD_DIR}/merged-compiler.diva"
  "${BUILD_DIR}/merged-compiler.s"
  "${BUILD_DIR}/merged-compiler-stage2.s"
  "${BUILD_DIR}/diva-stage2"
  "${BUILD_DIR}/diva-stage3"
  "${BUILD_DIR}/diva-stage3-native"
  "${BUILD_DIR}/diva-stage3-cc"
  "${BUILD_DIR}/diva-driver-merged"
  "${BUILD_DIR}/diva-driver-promote-candidate"
  "${BUILD_DIR}/stage2-build-compiler.out"
  "${BUILD_DIR}/stage3-build-compiler.out"
  "${BUILD_DIR}/stage3-cc-build-compiler.out"
  "${BUILD_DIR}/stage3-cc-pipeline.out"
  "${BUILD_DIR}/stage2-asm-merged.err"
  "${BUILD_DIR}/.promote-seed.log"
  "${BUILD_DIR}/.promote-seed.log.stage2"
  "${BUILD_DIR}/.merged-driver-build.log"
)

echo "[cleanup] root: ${ROOT_DIR}"
if [[ "${DRY_RUN}" -eq 1 ]]; then
  echo "[cleanup] dry-run mode (no files removed)"
fi

removed=0
for f in "${TARGETS[@]}"; do
  if [[ -e "${f}" ]]; then
    if [[ "${DRY_RUN}" -eq 1 ]]; then
      echo "[cleanup] would remove: ${f}"
    else
      rm -f -- "${f}"
      echo "[cleanup] removed: ${f}"
      removed=$((removed + 1))
    fi
  fi
done

if [[ "${DRY_RUN}" -eq 0 ]]; then
  echo "[cleanup] done (${removed} files removed)"
fi

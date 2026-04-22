#!/usr/bin/env sh
# Promote a self-built compiler (from `compiler/`) to become the new bootstrap seed
# `bootstrap/diva-linux-amd64`. Same OS/ABI (Linux x86-64) as documented in bootstrap/README.md.
#
# Native bootstrap uses Diva ELF emission (no cc/ld on the compiler build path). You still
# need a normal Linux userland: sh, python3, chmod (used briefly when materializing the ELF).
#
# Usage (from repo root):
#   DI_STDLIB_DIR="$PWD/stdlib" ./scripts/promote-bootstrap-seed.sh
#
# Optional: SEED=/path/to/diva ./scripts/promote-bootstrap-seed.sh
set -eu

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "${ROOT_DIR}"

SEED="${SEED:-${ROOT_DIR}/bootstrap/diva-linux-amd64}"
DI_STDLIB_DIR="${DI_STDLIB_DIR:-${ROOT_DIR}/stdlib}"
export DI_STDLIB_DIR

if [ ! -x "${SEED}" ]; then
  echo "promote-bootstrap-seed: missing or non-executable SEED: ${SEED}" >&2
  exit 1
fi
BUILD_LOG="${ROOT_DIR}/build/.promote-seed.log"
mkdir -p "${ROOT_DIR}/build"

echo "[promote] Building compiler package with seed: ${SEED}"
MERGED_EXE="${ROOT_DIR}/build/diva-driver-promote-candidate"
if "${SEED}" build "${ROOT_DIR}/compiler" >"${BUILD_LOG}" 2>&1
then
  DRIVER=$(sed -n 's/^\[native\] built executable at //p' "${BUILD_LOG}" | tail -n 1)
  if [ -z "${DRIVER}" ]; then
    DRIVER=$(sed -n 's/^\[di\] built native executable at //p' "${BUILD_LOG}" | tail -n 1)
  fi
  if [ -z "${DRIVER}" ] || [ ! -x "${DRIVER}" ]; then
    echo "[promote] build exited 0 but no executable path in log; falling back to merged Diva build." >&2
    DRIVER=""
  fi
else
  echo "[promote] seed build failed; falling back to merged Diva build (see ${BUILD_LOG})." >&2
  sed -n '1,40p' "${BUILD_LOG}" >&2 || true
  DRIVER=""
fi

if [ -z "${DRIVER}" ] || [ ! -x "${DRIVER}" ]; then
  echo "[promote] building driver via scripts/build-bootstrap-driver-merged.sh -> ${MERGED_EXE}"
  sh "${ROOT_DIR}/scripts/build-bootstrap-driver-merged.sh" "${MERGED_EXE}"
  DRIVER="${MERGED_EXE}"
fi

if [ ! -x "${DRIVER}" ]; then
  echo "[promote] could not produce a driver executable." >&2
  exit 1
fi

TS=$(date +%Y%m%d%H%M%S)
BACKUP="${ROOT_DIR}/bootstrap/diva-linux-amd64.bak-${TS}"
echo "[promote] Backing up current seed -> ${BACKUP}"
cp -a "${ROOT_DIR}/bootstrap/diva-linux-amd64" "${BACKUP}"

echo "[promote] Installing ${DRIVER} -> bootstrap/diva-linux-amd64"
cp -a "${DRIVER}" "${ROOT_DIR}/bootstrap/diva-linux-amd64"
chmod +x "${ROOT_DIR}/bootstrap/diva-linux-amd64"

if [ "${PROMOTE_SKIP_VERIFY:-}" = "1" ]; then
  echo "[promote] PROMOTE_SKIP_VERIFY=1: skipping second-stage build (run locally to verify)."
else
  echo "[promote] Verifying second-stage build (new seed compiles compiler/) ..."
  if ! "${ROOT_DIR}/bootstrap/diva-linux-amd64" build "${ROOT_DIR}/compiler" >"${BUILD_LOG}.stage2" 2>&1
  then
    echo "[promote] second-stage build failed; restoring backup." >&2
    cp -a "${BACKUP}" "${ROOT_DIR}/bootstrap/diva-linux-amd64"
    sed -n '1,80p' "${BUILD_LOG}.stage2" >&2 || true
    exit 1
  fi
fi

echo "[promote] OK. New seed is bootstrap/diva-linux-amd64 (backup: ${BACKUP})."

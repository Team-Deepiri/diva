#!/usr/bin/env sh
# Promote a self-built compiler (from `compiler/`) to become the new bootstrap seed
# `bootstrap/diva-linux-amd64`. Same OS/ABI (Linux x86-64) as documented in bootstrap/README.md.
#
# Requires: host `cc` for the LLVM link step when using the current seed; the built driver
# uses `host_system("cc ...")` for native link, so this script must run in an environment
# where that succeeds (not a sandbox that blocks fork/exec).
#
# Usage (from repo root):
#   DI_STDLIB_DIR="$PWD/stdlib" DI_RUNTIME_O="$PWD/bootstrap/runtime-linux-amd64.o" \
#     ./scripts/promote-bootstrap-seed.sh
#
# Optional: SEED=/path/to/diva ./scripts/promote-bootstrap-seed.sh
set -eu

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "${ROOT_DIR}"

SEED="${SEED:-${ROOT_DIR}/bootstrap/diva-linux-amd64}"
DI_STDLIB_DIR="${DI_STDLIB_DIR:-${ROOT_DIR}/stdlib}"
DI_RUNTIME_O="${DI_RUNTIME_O:-${ROOT_DIR}/bootstrap/runtime-linux-amd64.o}"
export DI_STDLIB_DIR DI_RUNTIME_O

if [ ! -x "${SEED}" ]; then
  echo "promote-bootstrap-seed: missing or non-executable SEED: ${SEED}" >&2
  exit 1
fi
if [ ! -f "${DI_RUNTIME_O}" ]; then
  echo "promote-bootstrap-seed: set DI_RUNTIME_O to the prebuilt runtime .o (e.g. bootstrap/runtime-linux-amd64.o)" >&2
  exit 1
fi

BUILD_LOG="${ROOT_DIR}/build/.promote-seed.log"
mkdir -p "${ROOT_DIR}/build"

echo "[promote] Building compiler package with seed: ${SEED}"
if ! "${SEED}" build "${ROOT_DIR}/compiler" >"${BUILD_LOG}" 2>&1
then
  echo "[promote] build failed. Log:" >&2
  sed -n '1,80p' "${BUILD_LOG}" >&2 || true
  exit 1
fi

DRIVER=$(sed -n 's/^\[di\] built native executable at //p' "${BUILD_LOG}" | tail -n 1)
if [ -z "${DRIVER}" ] || [ ! -x "${DRIVER}" ]; then
  echo "[promote] could not find built executable in log (expected \"[di] built native executable at <path>\")." >&2
  sed -n '1,40p' "${BUILD_LOG}" >&2 || true
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
echo "[promote] Commit with: git add bootstrap/diva-linux-amd64 && git commit -m \"chore(bootstrap): promote self-built compiler seed\""

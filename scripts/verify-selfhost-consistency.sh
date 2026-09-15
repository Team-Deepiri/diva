#!/bin/sh
# Self-host consistency gate: build compiler/ twice with the pure in-process emitter
# and require stage2 ≡ stage3 (byte-identical), proving the compiler is a fixed point.
#
#   stage2 = seed driver builds compiler/  (seed = bootstrap/diva-linux-amd64)
#   stage3 = stage2 driver builds compiler/
#
# Usage (repo root):
#   sh scripts/verify-selfhost-consistency.sh
# Optional:
#   LOG=/tmp/selfhost.log sh scripts/verify-selfhost-consistency.sh
set -eu

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "${ROOT_DIR}"

SEED="${ROOT_DIR}/bootstrap/diva-linux-amd64"
if [ ! -x "${SEED}" ]; then
  echo "[selfhost-consistency] missing seed: ${SEED}" >&2
  exit 1
fi

WORK="${ROOT_DIR}/build/.selfhost-consistency"
mkdir -p "${WORK}"
STAGE2="${WORK}/stage2"
STAGE3="${WORK}/stage3"
LOG="${LOG:-${WORK}/selfhost.log}"
: > "${LOG}"

build_compiler() {
  _driver=$1
  _out=$2
  _skip_extern=$3
  echo "[selfhost-consistency] build compiler/ with ${_driver} -> ${_out}" | tee -a "${LOG}"
  DRIVER="${_driver}" \
    DIVA_SKIP_NATIVE_EXTERN_CHECK="${_skip_extern}" \
    OUT_EXE="${_out}" \
    bash "${ROOT_DIR}/scripts/build-compiler-pure-elf.sh" >>"${LOG}" 2>&1
}

# Promoted seed matches tip codegen — enforce native externs on both stages (Issue #55).
build_compiler "${SEED}" "${STAGE2}" ""
build_compiler "${STAGE2}" "${STAGE3}" ""

H2=$(sha256sum "${STAGE2}" | awk '{print $1}')
H3=$(sha256sum "${STAGE3}" | awk '{print $1}')
S2=$(wc -c <"${STAGE2}")
S3=$(wc -c <"${STAGE3}")

echo "[selfhost-consistency] stage2 = ${H2} (${S2} bytes)"
echo "[selfhost-consistency] stage3 = ${H3} (${S3} bytes)"

if [ "${H2}" = "${H3}" ]; then
  echo "[selfhost-consistency] OK: stage2 ≡ stage3 (self-host fixed point)"
  exit 0
fi

echo "[selfhost-consistency] FAIL: stage2 != stage3 (self-host not at fixed point)" >&2
echo "[selfhost-consistency] tail ${LOG}:" >&2
tail -n 40 "${LOG}" >&2
exit 1

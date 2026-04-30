#!/usr/bin/env sh
# Build the merged compiler driver with the pinned seed: `diva asm` (gas) + cc + runtime.o.
# Use when `diva build compiler/` fails with "link failed (requires cc and a valid DI_RUNTIME_O)"
# because the seed embeds a native driver that passes the whole asm through the shell (ARG_MAX).
set -eu

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "${ROOT_DIR}"

SEED="${SEED:-${ROOT_DIR}/bootstrap/diva-linux-amd64}"
DI_STDLIB_DIR="${DI_STDLIB_DIR:-${ROOT_DIR}/stdlib}"
RT_O="${DI_RUNTIME_O:-${ROOT_DIR}/bootstrap/runtime-linux-amd64.o}"
CRT_SRC="${ROOT_DIR}/compiler/res/native_crt.s"
OUT_EXE="${1:-${ROOT_DIR}/build/diva-stage2}"
WORK="${ROOT_DIR}/build/.compiler-cc-link"
ASM_TIMEOUT_SECS="${ASM_TIMEOUT_SECS:-300}"
MERGED="${WORK}/merged.diva"
ASM="${WORK}/merged.s"
USER_O="${WORK}/merged.o"
CRT_O="${WORK}/native_crt.o"

export ROOT_DIR DI_STDLIB_DIR

mkdir -p "${WORK}" "${ROOT_DIR}/build"

if ! [ -x "${SEED}" ]; then
  echo "build-compiler-cc-link: missing seed executable: ${SEED}" >&2
  exit 1
fi
if ! [ -f "${RT_O}" ]; then
  echo "build-compiler-cc-link: runtime object not found: ${RT_O} (set DI_RUNTIME_O)" >&2
  exit 1
fi
if ! [ -f "${CRT_SRC}" ]; then
  echo "build-compiler-cc-link: missing ${CRT_SRC}" >&2
  exit 1
fi

echo "[build-compiler-cc-link] merging compiler/ -> ${MERGED}"
ROOT_DIR="${ROOT_DIR}" DI_STDLIB_DIR="${DI_STDLIB_DIR}" \
  python3 "${ROOT_DIR}/scripts/merge_compiler_package.py" >"${MERGED}"

echo "[build-compiler-cc-link] seed asm -> ${ASM}"
set +e
DI_STDLIB_DIR="${DI_STDLIB_DIR}" ROOT_DIR="${ROOT_DIR}" \
  timeout "${ASM_TIMEOUT_SECS}" "${SEED}" asm "${MERGED}" >"${ASM}"
ASM_RC=$?
set -e
if [ "${ASM_RC}" -ne 0 ]; then
  echo "[build-compiler-cc-link] seed asm step failed or timed out (exit=${ASM_RC})" >&2
  exit 1
fi

echo "[build-compiler-cc-link] cc (user asm + crt + runtime)"
# PIE final link matches the seed binary (ET_DYN); a static ET_EXEC + this runtime mix
# broke di_runtime_argc/argv in practice while the same argv worked against the seed.
cc -fPIE -pie -c -o "${USER_O}" "${ASM}" -fno-stack-protector
cc -fPIC -pie -c -o "${CRT_O}" "${CRT_SRC}"
cc -pie -nostartfiles "${CRT_O}" "${USER_O}" "${RT_O}" -o "${OUT_EXE}" -lc -Wl,-z,noexecstack
chmod +x "${OUT_EXE}"
echo "[build-compiler-cc-link] OK -> ${OUT_EXE}"

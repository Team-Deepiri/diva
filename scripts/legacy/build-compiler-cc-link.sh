#!/usr/bin/env sh
# DEPRECATED: gas + cc + runtime.o was the old driver link path. The product now uses pure in-process
# ELF only. Kept for forensic/bisect. Prefer: scripts/build-compiler-pure-elf.sh
#
# Build the merged compiler driver with the pinned seed: `diva asm` (gas) + cc + runtime.o.
set -eu

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
cd "${ROOT_DIR}"

# Default SEED: pure bootstrap cannot `asm` a merged.diva (loader looks for sibling
# tokens.diva). Prefer a known-good hosted bak; current build/diva-stage2-from-cc may
# SIGSEGV on full-package `asm` (see docs/LEAVE_OFF.md).
if [ -z "${SEED:-}" ]; then
  BAK=$(ls -1t "${ROOT_DIR}"/build/diva-stage2-from-cc.bak-before-retfix-* 2>/dev/null | head -1 || true)
  if [ -n "${BAK}" ] && [ -x "${BAK}" ]; then
    SEED="${BAK}"
    echo "[build-compiler-cc-link] SEED default -> ${SEED} (hosted bak; avoids full-asm SEGV)"
  elif [ -x "${ROOT_DIR}/build/diva-stage2-from-cc" ]; then
    SEED="${ROOT_DIR}/build/diva-stage2-from-cc"
    echo "[build-compiler-cc-link] SEED default -> ${SEED} (may SEGV on full asm)"
  else
    SEED="${ROOT_DIR}/bootstrap/diva-linux-amd64"
  fi
fi
DI_STDLIB_DIR="${DI_STDLIB_DIR:-${ROOT_DIR}/stdlib}"
RT_O="${DI_RUNTIME_O:-${ROOT_DIR}/bootstrap/runtime-linux-amd64.o}"
CRT_SRC="${ROOT_DIR}/compiler/res/legacy/native_crt.s"
EXTRA_SRC="${ROOT_DIR}/compiler/res/legacy/runtime_extra.s"
OUT_EXE="${1:-${ROOT_DIR}/build/diva-stage2}"
WORK="${ROOT_DIR}/build/.compiler-cc-link"
ASM_TIMEOUT_SECS="${ASM_TIMEOUT_SECS:-1200}"
MERGED="${WORK}/merged.diva"
ASM="${WORK}/merged.s"
USER_O="${WORK}/merged.o"
CRT_O="${WORK}/native_crt.o"
EXTRA_O="${WORK}/runtime_extra.o"

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
if ! [ -f "${EXTRA_SRC}" ]; then
  echo "build-compiler-cc-link: missing ${EXTRA_SRC}" >&2
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

ASM_LINK="${ASM}"
DEDUP_ASM="${WORK}/merged.dedup.s"
echo "[build-compiler-cc-link] dedupe duplicate .globl blocks (merged std helpers) -> ${DEDUP_ASM}"
python3 "${ROOT_DIR}/scripts/dedupe_merged_gas.py" "${ASM}" "${DEDUP_ASM}"
ASM_LINK="${DEDUP_ASM}"

echo "[build-compiler-cc-link] cc (user asm + crt + runtime + runtime_extra)"
# PIE final link matches the seed binary (ET_DYN); a static ET_EXEC + this runtime mix
# broke di_runtime_argc/argv in practice while the same argv worked against the seed.
cc -fPIE -pie -c -o "${USER_O}" "${ASM_LINK}" -fno-stack-protector
cc -fPIC -pie -c -o "${CRT_O}" "${CRT_SRC}"
cc -fPIC -c -o "${EXTRA_O}" "${EXTRA_SRC}" -fno-stack-protector
cc -pie -nostartfiles "${CRT_O}" "${USER_O}" "${RT_O}" "${EXTRA_O}" -o "${OUT_EXE}" -lc -Wl,-z,noexecstack
chmod +x "${OUT_EXE}"
echo "[build-compiler-cc-link] OK -> ${OUT_EXE}"

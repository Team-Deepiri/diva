#!/usr/bin/env sh
# #187 Unicode text fuzz targets.
#
# Builds and runs tests/cases/text/text_fuzz.diva, which deterministically fuzzes
# the native text layer (valid codepoint sequences and raw/malformed byte
# strings). The process must exit 0 and report a full iteration count with zero
# invariant failures — a crash, hang, or short run fails the harness.
#
# Usage (repo root):
#   sh tests/text_fuzz.sh            # default 2000 iterations
#   FUZZ_ITERS=5000 sh tests/text_fuzz.sh
# Optional: DIVA_PURE_DRIVER=/path/to/diva to pin a specific driver.
set -eu

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "${ROOT_DIR}"

if [ -n "${DIVA_PURE_DRIVER:-}" ] && [ -x "${DIVA_PURE_DRIVER}" ]; then
  DRIVER="${DIVA_PURE_DRIVER}"
elif [ -x "${ROOT_DIR}/build/diva-compiler-pure-elf" ]; then
  DRIVER="${ROOT_DIR}/build/diva-compiler-pure-elf"
else
  DRIVER="${ROOT_DIR}/build/diva-test"
fi
if [ ! -x "${DRIVER}" ]; then
  echo "[text-fuzz] missing driver: ${DRIVER}" >&2
  exit 1
fi

ITERS="${FUZZ_ITERS:-2000}"

WORK="$(mktemp -d "${TMPDIR:-/tmp}/diva-text-fuzz.XXXXXX")"
trap 'rm -rf "${WORK}"' EXIT

SRC="${ROOT_DIR}/tests/cases/text/text_fuzz.diva"
if ! DI_STDLIB_DIR="${ROOT_DIR}/stdlib" DIVA_NO_EXTERNAL=1 \
     DI_RUNTIME_O="${ROOT_DIR}/bootstrap/runtime-linux-amd64.o" \
     timeout 60 "${DRIVER}" build "${SRC}" "${WORK}/fuzz.exe" >"${WORK}/build.log" 2>&1; then
  sed -n '1,40p' "${WORK}/build.log" >&2
  echo "[text-fuzz] build FAILED" >&2
  exit 1
fi

OUT="${WORK}/out.txt"
if ! timeout 120 "${WORK}/fuzz.exe" "${ITERS}" > "${OUT}" 2>&1; then
  echo "[text-fuzz] fuzz run FAILED (crash/timeout)" >&2
  cat "${OUT}" >&2
  exit 1
fi
cat "${OUT}"

got_iters=$(awk -F= '/^FUZZ iterations=/{print $2}' "${OUT}")
fails=$(awk -F= '/^FUZZ failures=/{print $2}' "${OUT}")
got_iters=${got_iters:-0}
fails=${fails:-0}

printf '[text-fuzz] requested=%s completed=%s failures=%s\n' "${ITERS}" "${got_iters}" "${fails}"
if [ "${fails}" -eq 0 ] && [ "${got_iters}" -eq "${ITERS}" ]; then
  echo "[text-fuzz] PASS"
  exit 0
fi
echo "[text-fuzz] FAIL" >&2
exit 1

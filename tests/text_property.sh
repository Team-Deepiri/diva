#!/usr/bin/env sh
# #186 Unicode text property / golden tests.
#
# Builds tests/cases/text/text_property.diva, runs it over every file in
# tests/data/text_corpus/, and fails if any property assertion fails. The corpus
# is committed (small, valid UTF-8); no network or Unicode data files required.
#
# Usage (repo root):
#   sh tests/text_property.sh
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
  echo "[text-property] missing driver: ${DRIVER}" >&2
  exit 1
fi

WORK="$(mktemp -d "${TMPDIR:-/tmp}/diva-text-property.XXXXXX")"
trap 'rm -rf "${WORK}"' EXIT

SRC="${ROOT_DIR}/tests/cases/text/text_property.diva"
if ! DI_STDLIB_DIR="${ROOT_DIR}/stdlib" DIVA_NO_EXTERNAL=1 \
     DI_RUNTIME_O="${ROOT_DIR}/bootstrap/runtime-linux-amd64.o" \
     timeout 60 "${DRIVER}" build "${SRC}" "${WORK}/prop.exe" >"${WORK}/build.log" 2>&1; then
  sed -n '1,40p' "${WORK}/build.log" >&2
  echo "[text-property] build FAILED" >&2
  exit 1
fi

OUT="${WORK}/out.txt"
set -- "${ROOT_DIR}"/tests/data/text_corpus/*.txt
timeout 30 "${WORK}/prop.exe" "$@" > "${OUT}" 2>&1 || true
cat "${OUT}"

checks=$(awk -F= '/^PROPERTY checks=/{print $2}' "${OUT}")
fails=$(awk -F= '/^PROPERTY failures=/{print $2}' "${OUT}")
checks=${checks:-0}
fails=${fails:-0}

printf '[text-property] checks=%s failures=%s\n' "${checks}" "${fails}"
if [ "${fails}" -eq 0 ]; then
  echo "[text-property] PASS"
  exit 0
fi
echo "[text-property] FAIL" >&2
exit 1

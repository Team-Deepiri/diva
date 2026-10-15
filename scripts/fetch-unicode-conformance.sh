#!/usr/bin/env sh
# Fetch and verify the Unicode conformance data used by tests/unicode_conformance.sh
# (#185) and the fuzz/bench harnesses (#187/#188).
#
# The data files themselves are large and version-pinned, so they are NOT checked
# into git (see .gitignore). This script downloads the exact release and verifies
# every file against tests/data/unicode/SHA256SUMS; the committed VERSION and
# SHA256SUMS are the source of truth for which release the suite targets.
#
# Usage (repo root):
#   sh scripts/fetch-unicode-conformance.sh
#   sh scripts/fetch-unicode-conformance.sh --verify   # verify only, no download
#
# Requires: curl or wget, sha256sum. Network access is required to download.
set -eu

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "${ROOT_DIR}"

DATA_DIR="${ROOT_DIR}/tests/data/unicode"
VER_FILE="${DATA_DIR}/VERSION"
SUMS_FILE="${DATA_DIR}/SHA256SUMS"

if [ ! -f "${VER_FILE}" ]; then
  echo "[fetch-unicode] missing ${VER_FILE}" >&2
  exit 1
fi
if [ ! -f "${SUMS_FILE}" ]; then
  echo "[fetch-unicode] missing ${SUMS_FILE}" >&2
  exit 1
fi

VERSION=$(tr -d ' \t\r\n' < "${VER_FILE}")
UCD_BASE="https://www.unicode.org/Public/${VERSION}/ucd"

# filename<TAB>url
FILES="
NormalizationTest.txt	${UCD_BASE}/NormalizationTest.txt
GraphemeBreakTest.txt	${UCD_BASE}/auxiliary/GraphemeBreakTest.txt
WordBreakTest.txt	${UCD_BASE}/auxiliary/WordBreakTest.txt
UTF-8-test.txt	https://www.cl.cam.ac.uk/~mgk25/ucs/examples/UTF-8-test.txt
"

DOWNLOAD=1
if [ "${1:-}" = "--verify" ]; then
  DOWNLOAD=0
fi

fetch() {
  url=$1
  out=$2
  if command -v curl >/dev/null 2>&1; then
    curl -fsSL --retry 3 -o "${out}" "${url}"
  elif command -v wget >/dev/null 2>&1; then
    wget -q -O "${out}" "${url}"
  else
    echo "[fetch-unicode] need curl or wget to download ${url}" >&2
    return 1
  fi
}

mkdir -p "${DATA_DIR}"

if [ "${DOWNLOAD}" -eq 1 ]; then
  echo "[fetch-unicode] Unicode ${VERSION} -> ${DATA_DIR}"
  printf '%s\n' "${FILES}" | while IFS="$(printf '\t')" read -r name url; do
    [ -n "${name}" ] || continue
    tmp="${DATA_DIR}/${name}.part"
    echo "[fetch-unicode]   ${name}"
    if ! fetch "${url}" "${tmp}"; then
      rm -f "${tmp}"
      echo "[fetch-unicode] failed to download ${url}" >&2
      exit 1
    fi
    mv "${tmp}" "${DATA_DIR}/${name}"
  done
fi

echo "[fetch-unicode] verifying SHA256SUMS"
if ! ( cd "${DATA_DIR}" && sha256sum -c SHA256SUMS ); then
  echo "[fetch-unicode] checksum verification FAILED" >&2
  exit 1
fi
echo "[fetch-unicode] OK (Unicode ${VERSION})"

#!/usr/bin/env sh
# #185 Unicode conformance suite.
#
# Runs tests/cases/text/ucd_conformance.diva against the version-pinned Unicode
# data fetched by scripts/fetch-unicode-conformance.sh and decides a verdict:
#
#   NORM      — NormalizationTest.txt (NFC/NFD; ~2.6 MB, sharded below the
#               pure-ELF runtime's 1 MiB read_file cap).
#   GRAPHEME  — GraphemeBreakTest.txt (UAX #29 cluster counts).
#   WORD      — WordBreakTest.txt (reported skipped: no text_words in this tree).
#
# Missing data is a soft SKIP (exit 0) so the suite can run offline; run the
# fetch script to enable the assertions.
#
# Usage (repo root):
#   sh tests/unicode_conformance.sh
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
  echo "[unicode-conformance] missing driver: ${DRIVER}" >&2
  exit 1
fi

DATA_DIR="${ROOT_DIR}/tests/data/unicode"
SRC="${ROOT_DIR}/tests/cases/text/ucd_conformance.diva"

if [ ! -f "${DATA_DIR}/NormalizationTest.txt" ]; then
  echo "[unicode-conformance] data absent (run scripts/fetch-unicode-conformance.sh)"
  echo "NORM status=absent total=0 pass=0 fail=0 skip=0"
  echo "GRAPHEME status=absent total=0 pass=0 fail=0 skip=0"
  echo "WORD status=absent total=0 pass=0 fail=0 skip=0"
  echo "[unicode-conformance] SKIP (no data)"
  exit 0
fi

WORK="$(mktemp -d "${TMPDIR:-/tmp}/diva-unicode-conf.XXXXXX")"
trap 'rm -rf "${WORK}"' EXIT

if [ -f "${DATA_DIR}/SHA256SUMS" ] && command -v sha256sum >/dev/null 2>&1; then
  if ! ( cd "${DATA_DIR}" && sha256sum -c SHA256SUMS >/dev/null 2>&1 ); then
    echo "[unicode-conformance] WARNING: data does not match SHA256SUMS" >&2
  fi
fi

if ! DI_STDLIB_DIR="${ROOT_DIR}/stdlib" DIVA_NO_EXTERNAL=1 \
     DI_RUNTIME_O="${ROOT_DIR}/bootstrap/runtime-linux-amd64.o" \
     timeout 60 "${DRIVER}" build "${SRC}" "${WORK}/ucd_conf.exe" >"${WORK}/build.log" 2>&1; then
  sed -n '1,40p' "${WORK}/build.log" >&2
  echo "[unicode-conformance] driver build FAILED" >&2
  exit 1
fi
EXE="${WORK}/ucd_conf.exe"

OUT="${WORK}/out.txt"
: > "${OUT}"

# NormalizationTest.txt exceeds the 1 MiB read cap: split on line boundaries and
# run one `norm` invocation per shard, then sum the counters.
split -C 900000 -d -a 3 "${DATA_DIR}/NormalizationTest.txt" "${WORK}/norm.shard."
for shard in "${WORK}"/norm.shard.*; do
  timeout 30 "${EXE}" norm "${shard}" >> "${OUT}"
done

if [ -f "${DATA_DIR}/GraphemeBreakTest.txt" ]; then
  timeout 30 "${EXE}" grapheme "${DATA_DIR}/GraphemeBreakTest.txt" >> "${OUT}"
else
  echo "GRAPHEME status=absent total=0 pass=0 fail=0 skip=0" >> "${OUT}"
fi

if [ -f "${DATA_DIR}/WordBreakTest.txt" ]; then
  timeout 30 "${EXE}" word "${DATA_DIR}/WordBreakTest.txt" >> "${OUT}"
else
  echo "WORD status=absent total=0 pass=0 fail=0 skip=0" >> "${OUT}"
fi

# Sum every `key=value` field for lines beginning with the given prefix.
agg() {
  awk -v p="$1" '
    $1==p { for (i=2; i<=NF; i++) { if (split($i,a,"=")==2) s[a[1]]+=a[2] } }
    END { printf "%d %d %d %d", s["total"], s["pass"], s["fail"], s["skip"] }' "${OUT}"
}

read -r n_total n_pass n_fail n_skip <<EOF
$(agg NORM)
EOF
read -r g_total g_pass g_fail g_skip <<EOF
$(agg GRAPHEME)
EOF
read -r w_total w_pass w_fail w_skip <<EOF
$(agg WORD)
EOF

echo "[unicode-conformance] DRIVER=${DRIVER}"
printf '[unicode-conformance] NORM      total=%s pass=%s fail=%s skip=%s\n' "${n_total}" "${n_pass}" "${n_fail}" "${n_skip}"
printf '[unicode-conformance] GRAPHEME  total=%s pass=%s fail=%s skip=%s (skip=GB11/ZWJ approximation)\n' "${g_total}" "${g_pass}" "${g_fail}" "${g_skip}"
printf '[unicode-conformance] WORD      total=%s pass=%s fail=%s skip=%s (no text_words)\n' "${w_total}" "${w_pass}" "${w_fail}" "${w_skip}"

if [ "${n_fail}" -eq 0 ] && [ "${g_fail}" -eq 0 ]; then
  echo "[unicode-conformance] PASS"
  exit 0
fi

echo "[unicode-conformance] FAIL: NORM fail=${n_fail} GRAPHEME fail=${g_fail}" >&2
exit 1

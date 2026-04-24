#!/usr/bin/env sh
set -eu

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "${ROOT_DIR}"

if [ ! -x "./build/diva-stage2" ]; then
  echo "[strict-pure] missing ./build/diva-stage2; build it first (scripts/build-compiler-cc-link.sh)" >&2
  exit 1
fi

LIST="${ROOT_DIR}/tests/strict-pure.list"
if [ ! -f "${LIST}" ]; then
  echo "[strict-pure] missing ${LIST}" >&2
  exit 1
fi

tmp_log="/tmp/diva-strict-pure.log"
tmp_sym="/tmp/diva-strict-pure.symbols"
tmp_fail="/tmp/diva-strict-pure.failures"
rm -f "${tmp_log}" "${tmp_sym}" "${tmp_fail}"

echo "[strict-pure] checking listed examples (tests/strict-pure.list) with DIVA_NO_EXTERNAL=1"

total=0
failed=0
timed_out=0

while IFS= read -r rel || [ -n "${rel}" ]; do
  rel=$(printf '%s' "${rel}" | tr -d '\r')
  case ${rel} in
  ''|'#'*) continue ;;
  esac
  f="${ROOT_DIR}/${rel}"
  if [ ! -f "${f}" ]; then
    echo "[strict-pure] missing file from list: ${rel}" >&2
    exit 1
  fi
  total=$((total + 1))
  DIVA_NO_EXTERNAL=1 timeout 30 ./build/diva-stage2 build "${f}" >"${tmp_log}" 2>&1 || rc=$?
  rc=${rc:-0}
  if [ "${rc}" -eq 0 ]; then
    echo "[strict-pure] OK   ${rel}"
  else
    failed=$((failed + 1))
    if [ "${rc}" -eq 124 ]; then
      timed_out=$((timed_out + 1))
    fi
    echo "[strict-pure] FAIL ${rel} (rc=${rc})"
    echo "${rel} (rc=${rc})" >> "${tmp_fail}"
    tr '\\' '\n' < "${tmp_log}" | sed -n 's/^n  - //p' >> "${tmp_sym}" || true
  fi
  rc=0
done < "${LIST}"

echo "[strict-pure] total=${total} failed=${failed} timeout=${timed_out}"

if [ -s "${tmp_sym}" ]; then
  echo "[strict-pure] unresolved extern symbols (unique):"
  sort -u "${tmp_sym}" | sed 's/^/  - /'
else
  echo "[strict-pure] unresolved extern symbols: none"
fi

if [ -s "${tmp_fail}" ]; then
  echo "[strict-pure] failing files:"
  sed 's/^/  - /' "${tmp_fail}"
fi

if [ "${failed}" -ne 0 ]; then
  exit 1
fi

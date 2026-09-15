#!/usr/bin/env bash
# Issue #53: sema positive + negative suite (tests/sema.list).
set -euo pipefail
ROOT_DIR="$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)"
cd "${ROOT_DIR}"
if [ -n "${DIVA_PURE_DRIVER:-}" ] && [ -x "${DIVA_PURE_DRIVER}" ]; then
  DRIVER="${DIVA_PURE_DRIVER}"
elif [ -x "${ROOT_DIR}/build/diva-compiler-pure-elf" ]; then
  DRIVER="${ROOT_DIR}/build/diva-compiler-pure-elf"
else
  DRIVER="${DIVA:-${ROOT_DIR}/bootstrap/diva-linux-amd64}"
fi
LIST="${ROOT_DIR}/tests/sema.list"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/diva-sema.XXXXXX")"
trap 'rm -rf "${WORK}"' EXIT
failed=0
total=0
echo "[sema] DRIVER=${DRIVER}"
while IFS= read -r line || [ -n "${line}" ]; do
  case "${line}" in ''|\#*) continue ;; esac
  path="${line%%	*}"
  rest="${line#*	}"
  needle="${rest%%	*}"
  kind="${rest#*	}"
  if [ "${kind}" = "${rest}" ]; then
    echo "[sema] bad line: ${line}" >&2
    failed=$((failed + 1))
    continue
  fi
  total=$((total + 1))
  src="${ROOT_DIR}/${path}"
  exe="${WORK}/out"
  log="${WORK}/case.log"
  if [ "${kind}" = "ok" ]; then
    if ! DI_STDLIB_DIR="${ROOT_DIR}/stdlib" DIVA_NO_EXTERNAL=1 \
      DI_RUNTIME_O="${ROOT_DIR}/bootstrap/runtime-linux-amd64.o" \
      DIVA_NATIVE_EXE_OUT="${exe}" \
      timeout 30 "${DRIVER}" build "${src}" >"${log}" 2>&1; then
      echo "[sema] FAIL ${path}: expected build ok" >&2
      sed -n '1,40p' "${log}" >&2
      failed=$((failed + 1))
    else
      echo "[sema] OK   ${path}"
    fi
  elif [ "${kind}" = "fail" ]; then
    if DI_STDLIB_DIR="${ROOT_DIR}/stdlib" DIVA_NO_EXTERNAL=1 \
      DI_RUNTIME_O="${ROOT_DIR}/bootstrap/runtime-linux-amd64.o" \
      DIVA_NATIVE_EXE_OUT="${exe}" \
      timeout 30 "${DRIVER}" build "${src}" >"${log}" 2>&1; then
      echo "[sema] FAIL ${path}: expected build failure" >&2
      failed=$((failed + 1))
    elif [ -n "${needle}" ] && ! grep -F "${needle}" "${log}" >/dev/null; then
      echo "[sema] FAIL ${path}: missing '${needle}'" >&2
      sed -n '1,40p' "${log}" >&2
      failed=$((failed + 1))
    else
      echo "[sema] OK   ${path}"
    fi
  fi
done < "${LIST}"
echo "[sema] total=${total} failed=${failed}"
[ "${failed}" -eq 0 ]

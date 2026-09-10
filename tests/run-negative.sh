#!/usr/bin/env bash
# Locked negative suite (Issue #61). Reads tests/negative.list.
set -euo pipefail

ROOT_DIR="$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)"
cd "${ROOT_DIR}"

if [ -n "${DIVA_PURE_DRIVER:-}" ] && [ -x "${DIVA_PURE_DRIVER}" ]; then
  DRIVER="${DIVA_PURE_DRIVER}"
elif [ -x "${ROOT_DIR}/build/diva-compiler-pure-elf" ]; then
  DRIVER="${ROOT_DIR}/build/diva-compiler-pure-elf"
else
  echo "[negative] missing driver (set DIVA_PURE_DRIVER or build diva-compiler-pure-elf)" >&2
  exit 1
fi

LIST="${ROOT_DIR}/tests/negative.list"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/diva-negative.XXXXXX")"
trap 'rm -rf "${WORK}"' EXIT

failed=0
total=0

echo "[negative] DRIVER=${DRIVER}"
echo "[negative] list=${LIST}"

while IFS= read -r line || [ -n "${line}" ]; do
  case "${line}" in
    ''|\#*) continue ;;
  esac
  # path\tneedle\tkind  (needle may be empty for runtime_abort)
  path="${line%%	*}"
  rest="${line#*	}"
  needle="${rest%%	*}"
  kind="${rest#*	}"
  if [ "${kind}" = "${rest}" ]; then
    echo "[negative] bad list line (need path, needle, kind): ${line}" >&2
    failed=$((failed + 1))
    continue
  fi

  total=$((total + 1))
  src="${ROOT_DIR}/${path}"
  log="${WORK}/case.log"
  exe="${WORK}/out-exe"

  if [ "${kind}" = "fail_build" ]; then
    if DI_STDLIB_DIR="${ROOT_DIR}/stdlib" DIVA_NO_EXTERNAL=1 \
      DI_RUNTIME_O="${ROOT_DIR}/bootstrap/runtime-linux-amd64.o" \
      timeout 30 "${DRIVER}" build "${src}" "${exe}" >"${log}" 2>&1; then
      echo "[negative] FAIL ${path}: expected build failure" >&2
      sed -n '1,40p' "${log}" >&2 || true
      failed=$((failed + 1))
      continue
    fi
    if [ -n "${needle}" ] && ! grep -F "${needle}" "${log}" >/dev/null; then
      echo "[negative] FAIL ${path}: missing needle '${needle}'" >&2
      sed -n '1,80p' "${log}" >&2 || true
      failed=$((failed + 1))
      continue
    fi
    echo "[negative] OK   ${path}"
    continue
  fi

  if [ "${kind}" = "runtime_abort" ]; then
    if ! DI_STDLIB_DIR="${ROOT_DIR}/stdlib" DIVA_NO_EXTERNAL=1 \
      DI_RUNTIME_O="${ROOT_DIR}/bootstrap/runtime-linux-amd64.o" \
      timeout 30 "${DRIVER}" build "${src}" "${exe}" >"${log}" 2>&1; then
      echo "[negative] FAIL ${path}: expected successful build for runtime abort case" >&2
      sed -n '1,40p' "${log}" >&2 || true
      failed=$((failed + 1))
      continue
    fi
    set +e
    timeout 5 "${exe}" >"${WORK}/run.log" 2>&1
    rc=$?
    set -e
    if [ "${rc}" -eq 0 ]; then
      echo "[negative] FAIL ${path}: expected non-zero exit" >&2
      failed=$((failed + 1))
      continue
    fi
    echo "[negative] OK   ${path} (rc=${rc})"
    continue
  fi

  echo "[negative] FAIL unknown kind '${kind}' for ${path}" >&2
  failed=$((failed + 1))
done < "${LIST}"

echo "[negative] total=${total} failed=${failed}"
if [ "${failed}" -ne 0 ]; then
  exit 1
fi
echo "[negative] all locked negative checks passed"

#!/usr/bin/env bash
# Issue #29: diva new template smoke.
set -euo pipefail
ROOT_DIR="$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)"
cd "${ROOT_DIR}"
DRIVER="${ROOT_DIR}/build/diva-compiler-pure-elf"
if [ ! -x "${DRIVER}" ]; then
  DRIVER="${DIVA:-${ROOT_DIR}/bootstrap/diva-linux-amd64}"
fi
WORK="$(mktemp -d "/tmp/diva_sdk_XXXX")"
trap 'rm -rf "${WORK}"' EXIT
export DI_STDLIB_DIR="${ROOT_DIR}/stdlib"
if ! "${DRIVER}" new "${WORK}/sys_pkg" --system >/dev/null 2>&1; then
  echo "[sdk] FAIL diva new --system" >&2
  exit 1
fi
grep -F 'kind = "system"' "${WORK}/sys_pkg/package.diva" >/dev/null
if ! "${DRIVER}" check "${WORK}/sys_pkg" >/dev/null 2>&1; then
  echo "[sdk] FAIL diva check --system package" >&2
  exit 1
fi
if ! bash "${ROOT_DIR}/scripts/package-release.sh" smoke-test >/dev/null 2>&1; then
  echo "[sdk] FAIL package-release.sh" >&2
  exit 1
fi
rm -f "${ROOT_DIR}/diva-sdk-smoke-test.tar.gz"
echo "[sdk] OK"

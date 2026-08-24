#!/usr/bin/env bash
# Issue #24: package merge cache + module graph trace.
set -euo pipefail
ROOT_DIR="$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)"
cd "${ROOT_DIR}"
if [ -x "${ROOT_DIR}/build/diva-compiler-pure-elf" ]; then
  DRIVER="${ROOT_DIR}/build/diva-compiler-pure-elf"
else
  DRIVER="${DIVA:-${ROOT_DIR}/bootstrap/diva-linux-amd64}"
fi
PKG="${ROOT_DIR}/examples/packages/app_with_dep"
CACHE="${ROOT_DIR}/.diva/cache"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/diva-modcache.XXXXXX")"
trap 'rm -rf "${WORK}"' EXIT
rm -rf "${CACHE}"
log="${WORK}/build.log"
export DI_STDLIB_DIR="${ROOT_DIR}/stdlib" DIVA_NO_EXTERNAL=1
export DI_RUNTIME_O="${ROOT_DIR}/bootstrap/runtime-linux-amd64.o"
export DIVA_PKG_CACHE=1 DIVA_PKG_CACHE_TRACE=1 DIVA_MODULE_GRAPH=1
echo "[module-cache] DRIVER=${DRIVER}"
if ! DIVA_NATIVE_EXE_OUT="${WORK}/out1" \
  "${DRIVER}" build "${PKG}" >"${log}" 2>&1; then
  echo "[module-cache] FAIL first build" >&2
  sed -n '1,40p' "${log}" >&2
  exit 1
fi
grep -F 'module-graph: app_with_dep -> math_lib' "${log}" >/dev/null || {
  echo "[module-cache] FAIL missing module-graph line" >&2
  sed -n '1,40p' "${log}" >&2
  exit 1
}
grep -F 'loader: cache store app_with_dep' "${log}" >/dev/null || {
  echo "[module-cache] FAIL missing cache store on first build" >&2
  sed -n '1,40p' "${log}" >&2
  exit 1
}
if ! DIVA_NATIVE_EXE_OUT="${WORK}/out2" \
  "${DRIVER}" build "${PKG}" >"${log}" 2>&1; then
  echo "[module-cache] FAIL second build" >&2
  sed -n '1,40p' "${log}" >&2
  exit 1
fi
grep -F 'loader: cache hit app_with_dep' "${log}" >/dev/null || {
  echo "[module-cache] FAIL missing cache hit on second build" >&2
  sed -n '1,40p' "${log}" >&2
  exit 1
}
echo "[module-cache] OK"

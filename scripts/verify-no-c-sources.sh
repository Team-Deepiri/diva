#!/usr/bin/env sh
# Repository policy: no tracked C or C header sources (hosted runtime is runtime/runtime.ll + bootstrap/*.o).
set -eu
ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "${ROOT_DIR}"
if ! command -v git >/dev/null 2>&1; then
  echo "[verify-no-c-sources] skip (git not found)" >&2
  exit 0
fi
if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "[verify-no-c-sources] skip (not a git checkout)" >&2
  exit 0
fi
bad=$(git ls-files | grep -E '\.(c|h)$' || true)
if [ -n "${bad}" ]; then
  echo "[verify-no-c-sources] error: tracked .c/.h files are not allowed:" >&2
  echo "${bad}" >&2
  exit 1
fi
echo "[verify-no-c-sources] OK (no tracked .c/.h)"

#!/usr/bin/env sh
# Maintainer-only: refresh bootstrap/runtime-linux-amd64.o from runtime/runtime.ll.
# Requires clang on PATH (not kept as C source in this repository).
set -eu
ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
LL="${ROOT_DIR}/runtime/runtime.ll"
OUT="${ROOT_DIR}/bootstrap/runtime-linux-amd64.o"
if ! command -v clang >/dev/null 2>&1; then
  echo "clang is required to compile ${LL}" >&2
  exit 1
fi
clang -c -O1 "${LL}" -o "${OUT}"
echo "Wrote ${OUT}"

#!/usr/bin/env sh
# Fail if the repository tracks any C or C++ header sources (.c / .h).
set -eu
ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "${ROOT_DIR}"

bad=$(git ls-files | grep -E '\.(c|h)$' || true)
if [ -n "${bad}" ]; then
  printf 'verify-no-c-sources: tracked C/C++ sources found:\n%s\n' "${bad}" >&2
  exit 1
fi

exit 0

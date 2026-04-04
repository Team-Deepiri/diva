#!/usr/bin/env sh
# Fail if the repository tracks C/C++-family sources or legacy .mod manifests.
# Goal: compiler and libraries are authored only in .diva (plus non-code assets).
set -eu
ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "${ROOT_DIR}"

bad=$(git ls-files | grep -E '\.(c|h|cc|cxx|cpp|hpp|hh)$' || true)
if [ -n "${bad}" ]; then
  printf 'verify-no-c-sources: tracked C/C++ sources found:\n%s\n' "${bad}" >&2
  exit 1
fi

mod=$(git ls-files | grep -E '\.mod$' || true)
if [ -n "${mod}" ]; then
  printf 'verify-no-c-sources: tracked .mod files found (should be package.diva):\n%s\n' "${mod}" >&2
  exit 1
fi

exit 0

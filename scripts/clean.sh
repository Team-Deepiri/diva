#!/usr/bin/env sh
# Remove generated build output (including ephemeral native glue from `di build` / `di run`).
set -eu
ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
rm -rf "${ROOT_DIR}/build"
mkdir -p "${ROOT_DIR}/build"
printf 'Removed %s/build\n' "${ROOT_DIR}"

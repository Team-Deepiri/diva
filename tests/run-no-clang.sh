#!/usr/bin/env sh
# Minimal no-clang smoke: same contract as scripts/verify-no-clang.sh, runnable from tests/.
set -eu
ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
exec sh "${ROOT_DIR}/scripts/verify-no-clang.sh"

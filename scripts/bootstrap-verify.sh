#!/usr/bin/env sh
# Runs the full integration suite (seed compiler, then self-host driver replacing `di`).
# Same as: sh tests/run.sh
set -eu
ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
exec sh "${ROOT_DIR}/tests/run.sh"

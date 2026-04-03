#!/usr/bin/env sh
# Fail if install.sh would invoke clang while NO_CLANG=1 is required for this check.
# Usage: NO_CLANG=1 sh scripts/verify-no-clang.sh
set -eu
ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
TEST_HOME=$(mktemp -d "${TMPDIR:-/tmp}/di-noclang.XXXXXX")
cleanup() { rm -rf "${TEST_HOME}"; }
trap cleanup EXIT INT TERM

export NO_CLANG=1
export HOME="${TEST_HOME}"
mkdir -p "${HOME}/.local/bin"

# Capture install log and reject any clang invocation
LOG="${TEST_HOME}/install.log"
if ! sh "${ROOT_DIR}/scripts/install.sh" >"${LOG}" 2>&1; then
  sed -n '1,80p' "${LOG}" >&2
  echo "[verify-no-clang] install failed" >&2
  exit 1
fi

if grep -q '[[:space:]]clang' "${LOG}" 2>/dev/null; then
  echo "[verify-no-clang] error: clang appeared in install output" >&2
  sed -n '1,120p' "${LOG}" >&2
  exit 1
fi

PATH="${HOME}/.local/bin:${PATH}"
export PATH
export DI_STDLIB_DIR="${ROOT_DIR}/stdlib"
RUNO="${HOME}/.local/share/di/runtime/runtime.o"
export DI_RUNTIME_O="${RUNO}"

if ! di run "${ROOT_DIR}/examples/hello.diri" >"${TEST_HOME}/out.txt" 2>&1; then
  sed -n '1,80p' "${TEST_HOME}/out.txt" >&2
  echo "[verify-no-clang] di run hello.diri failed" >&2
  exit 1
fi

echo "[verify-no-clang] OK (install + hello.diri under NO_CLANG=1)"

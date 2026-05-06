#!/usr/bin/env sh
# Pure-built driver smoke / gate (see docs/pure-only-driver.md).
#
# Usage (from repo root):
#   DIVA_SKIP_NATIVE_EXTERN_CHECK=1 build/diva-stage2 build compiler/ /tmp/diva-native-exe
#   ./scripts/verify-pure-only-driver.sh
#
# Env:
#   DIVA_PURE_DRIVER   — path to pure ELF driver (default /tmp/diva-native-exe)
#   DIVA_PURE_FULL=1   — also require `ir` + `asm` on a tiny file (fails until ret-to-0 bug fixed)
#
set -eu

ROOT_DIR=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
cd "${ROOT_DIR}"

DRIVER="${DIVA_PURE_DRIVER:-/tmp/diva-native-exe}"
if [ ! -x "${DRIVER}" ]; then
  echo "[verify-pure-only-driver] not executable: ${DRIVER}" >&2
  echo "  Build with: DIVA_SKIP_NATIVE_EXTERN_CHECK=1 build/diva-stage2 build compiler/ /tmp/diva-native-exe" >&2
  exit 1
fi

export ROOT_DIR
export DI_STDLIB_DIR="${DI_STDLIB_DIR:-${ROOT_DIR}/stdlib}"

fail() {
  echo "[verify-pure-only-driver] $1" >&2
  exit 1
}

run_one() {
  label=$1
  shift
  echo "[verify-pure-only-driver] ${label}: $*"
  set +e
  "$@"
  rc=$?
  set -e
  if [ "${rc}" -ne 0 ]; then
    fail "${label} failed (rc=${rc})"
  fi
}

# Negative test: expect a specific non-zero exit (e.g. sema error), not a crash.
run_one_expect_rc() {
  label=$1
  want=$2
  shift 2
  echo "[verify-pure-only-driver] ${label} (expect rc=${want}): $*"
  set +e
  "$@"
  rc=$?
  set -e
  if [ "${rc}" -ne "${want}" ]; then
    fail "${label} expected rc=${want} got rc=${rc}"
  fi
}

echo "[verify-pure-only-driver] DRIVER=${DRIVER}"

tiny=$(mktemp)
cleanup() { rm -f "${tiny}"; }
trap cleanup EXIT
printf '%s\n' 'func main(): int {' '    return 0' '}' >"${tiny}"

# Always-on smoke: lexer + parse (no merge_file_sources / ir pipeline).
run_one "lex tiny" "${DRIVER}" lex "${tiny}"
run_one "parse tiny" "${DRIVER}" parse "${tiny}"

# Full gate: ir/asm touch codegen + merge paths; known SIGSEGV (rip≈0, [rsp]=0) until fixed.
if [ "${DIVA_PURE_FULL:-0}" = "1" ]; then
  run_one "ir tiny" "${DRIVER}" ir "${tiny}"
  run_one "asm tiny" "${DRIVER}" asm "${tiny}"

  if [ -f "${ROOT_DIR}/tests/cases/fail/duplicate_decl.diva" ]; then
    run_one_expect_rc "ir duplicate_decl" 1 "${DRIVER}" ir "${ROOT_DIR}/tests/cases/fail/duplicate_decl.diva"
  fi

  if [ -f "${ROOT_DIR}/examples/ret0.diva" ]; then
    run_one "ir ret0" "${DRIVER}" ir "${ROOT_DIR}/examples/ret0.diva"
  fi
else
  echo "[verify-pure-only-driver] skip ir/asm (set DIVA_PURE_FULL=1 for full gate; see docs/pure-only-driver.md)"
fi

echo "[verify-pure-only-driver] OK"

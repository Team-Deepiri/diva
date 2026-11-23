#!/usr/bin/env sh
# Issue #100: typed SSA-form MIR — typed IR dumps and vreg type verification.
#
# Usage (repo root): sh tests/mirtypes.sh
# Optional: DIVA_PURE_DRIVER=/path/to/diva to pin a driver.
set -eu

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "${ROOT_DIR}"

WORK="$(mktemp -d "${TMPDIR:-/tmp}/diva-mirtypes.XXXXXX")"
trap 'rm -rf "${WORK}"' EXIT

if [ -n "${DIVA_PURE_DRIVER:-}" ] && [ -x "${DIVA_PURE_DRIVER}" ]; then
  DRIVER="${DIVA_PURE_DRIVER}"
else
  DRIVER="${WORK}/driver"
  echo "[mirtypes] building driver from bootstrap seed"
  if ! ROOT_DIR="${ROOT_DIR}" DI_STDLIB_DIR="${ROOT_DIR}/stdlib" DIVA_NO_EXTERNAL=1 \
       DI_RUNTIME_O="${ROOT_DIR}/bootstrap/runtime-linux-amd64.o" \
       timeout 900 "${ROOT_DIR}/bootstrap/diva-linux-amd64" build compiler "${DRIVER}" \
       >"${WORK}/driver-build.log" 2>&1; then
    cat "${WORK}/driver-build.log" >&2
    echo "[mirtypes] driver build failed" >&2
    exit 1
  fi
fi

echo "[mirtypes] DRIVER=${DRIVER}"

total=0
failed=0
fail() {
  failed=$((failed + 1))
  echo "[mirtypes] FAIL $1" >&2
}

has_line() {
  if ! grep -F -- "$2" "$1" >/dev/null; then
    fail "missing '$2'"
  fi
}

build_env() {
  DI_STDLIB_DIR="${ROOT_DIR}/stdlib" DIVA_NO_EXTERNAL=1 \
    DI_RUNTIME_O="${ROOT_DIR}/bootstrap/runtime-linux-amd64.o" "$@"
}

CASE="${ROOT_DIR}/tests/cases/mirtypes/typed.diva"

# Typed dump: result vregs carry type tags inferred from their defining ops.
total=$((total + 1))
if build_env timeout 60 "${DRIVER}" ir --types "${CASE}" >"${WORK}/typed.out" 2>"${WORK}/typed.err"; then
  has_line "${WORK}/typed.out" 'v0: int = const 41'
  has_line "${WORK}/typed.out" 'v1: int = call forty_one'
  has_line "${WORK}/typed.out" 'v3: int = load'
  has_line "${WORK}/typed.out" 'v0: ptr = alloca'
  if [ -s "${WORK}/typed.err" ]; then fail 'typed dump (unexpected stderr)'; fi
  echo "[mirtypes] OK   typed dump"
else
  fail 'typed dump (exit)'
  cat "${WORK}/typed.err" >&2
fi

# Plain dump is unchanged: no type annotations on result vregs.
total=$((total + 1))
if build_env timeout 60 "${DRIVER}" ir "${CASE}" >"${WORK}/plain.out" 2>"${WORK}/plain.err"; then
  has_line "${WORK}/plain.out" 'v0 = const 41'
  if grep -F 'v0: int' "${WORK}/plain.out" >/dev/null; then
    fail 'plain dump unexpectedly typed'
  fi
  if [ -s "${WORK}/plain.err" ]; then fail 'plain dump (unexpected stderr)'; fi
  echo "[mirtypes] OK   plain dump unchanged"
else
  fail 'plain dump (exit)'
  cat "${WORK}/plain.err" >&2
fi

# Crafted IR inconsistency: v0 defined as both int and ptr. The checking entry
# point must report it and exit non-zero.
total=$((total + 1))
set +e
build_env timeout 60 "${DRIVER}" ir --selftest-type-conflict \
  >"${WORK}/conflict.out" 2>"${WORK}/conflict.err"
conflict_rc=$?
set -e
if [ "${conflict_rc}" -eq 0 ]; then
  fail 'conflict selftest (expected non-zero exit)'
else
  has_line "${WORK}/conflict.err" 'sema: MIR type error:'
  has_line "${WORK}/conflict.err" 'v0 defined as int but also as ptr by addr.of'
  echo "[mirtypes] OK   conflict reported"
fi

# Automatic verification runs before optimization/codegen but stays non-fatal
# for ordinary programs.
total=$((total + 1))
if build_env timeout 60 "${DRIVER}" build "${CASE}" "${WORK}/typed.exe" \
    >"${WORK}/build.log" 2>&1; then
  got=$("${WORK}/typed.exe" 2>/dev/null || true)
  if [ "${got}" != "42" ]; then
    fail "build+run (got '${got}', want '42')"
  else
    echo "[mirtypes] OK   build+run"
  fi
else
  fail 'build+run (build failed)'
  cat "${WORK}/build.log" >&2
fi

echo "[mirtypes] total=${total} failed=${failed}"
[ "${failed}" -eq 0 ]

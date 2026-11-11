#!/usr/bin/env sh
# #97 Phase 1 (foundation): language-level `module`, `pub`, and `use` syntax.
#
# This slice lands parsing only: `module <name>` declarations, `use a::b`
# path imports (including glob `use a::*`), and the `pub` visibility modifier
# are accepted and represented in the AST. Module/use nodes are skipped by
# sema and the IR builder, so a `pub` item behaves like an ordinary top-level
# item (namespaces, per-symbol visibility enforcement, and re-export semantics
# are follow-ups). The cases assert the new syntax parses and does not disturb
# codegen.
#
# Self-contained: with no DIVA_PURE_DRIVER set, builds a fresh driver from the
# bootstrap seed.
#
# Usage (repo root):
#   sh tests/modules.sh
# Optional: DIVA_PURE_DRIVER=/path/to/diva to pin a specific driver.
set -eu

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "${ROOT_DIR}"

WORK="$(mktemp -d "${TMPDIR:-/tmp}/diva-modules.XXXXXX")"
trap 'rm -rf "${WORK}"' EXIT

if [ -n "${DIVA_PURE_DRIVER:-}" ] && [ -x "${DIVA_PURE_DRIVER}" ]; then
  DRIVER="${DIVA_PURE_DRIVER}"
else
  DRIVER="${WORK}/driver"
  echo "[modules] building driver from bootstrap seed"
  if ! ROOT_DIR="${ROOT_DIR}" DI_STDLIB_DIR="${ROOT_DIR}/stdlib" DIVA_NO_EXTERNAL=1 \
       DI_RUNTIME_O="${ROOT_DIR}/bootstrap/runtime-linux-amd64.o" \
       timeout 300 "${ROOT_DIR}/bootstrap/diva-linux-amd64" build compiler "${DRIVER}" \
       >"${WORK}/driver-build.log" 2>&1; then
    sed -n '1,40p' "${WORK}/driver-build.log" >&2
    echo "[modules] driver build failed" >&2
    exit 1
  fi
fi

echo "[modules] DRIVER=${DRIVER}"

total=0
failed=0
fail() {
  failed=$((failed + 1))
  echo "[modules] FAIL $1" >&2
}

# check_rc <name> <src> <expected_exit>
check_rc() {
  _name=$1
  _src=$2
  _want=$3
  total=$((total + 1))
  _exe="${WORK}/${_name}.exe"
  if ! DI_STDLIB_DIR="${ROOT_DIR}/stdlib" DIVA_NO_EXTERNAL=1 \
       DI_RUNTIME_O="${ROOT_DIR}/bootstrap/runtime-linux-amd64.o" \
       timeout 60 "${DRIVER}" build "${_src}" "${_exe}" >"${WORK}/${_name}.build.log" 2>&1; then
    fail "${_name} (build)"
    sed -n '1,40p' "${WORK}/${_name}.build.log" >&2
    return 0
  fi
  set +e
  timeout 60 "${_exe}" </dev/null >/dev/null 2>&1
  _rc=$?
  set -e
  if [ "${_rc}" -ne "${_want}" ]; then
    fail "${_name} (exit ${_rc}, want ${_want})"
    return 0
  fi
  echo "[modules] OK   ${_name}"
}

# check_fail <name> <src> <needle>
check_fail() {
  _name=$1
  _src=$2
  _needle=$3
  total=$((total + 1))
  if DI_STDLIB_DIR="${ROOT_DIR}/stdlib" DIVA_NO_EXTERNAL=1 \
     DI_RUNTIME_O="${ROOT_DIR}/bootstrap/runtime-linux-amd64.o" \
     timeout 60 "${DRIVER}" build "${_src}" "${WORK}/${_name}.exe" \
     >"${WORK}/${_name}.log" 2>&1; then
    fail "${_name} (expected build failure)"
    return 0
  fi
  if ! grep -q "${_needle}" "${WORK}/${_name}.log"; then
    fail "${_name} (missing needle '${_needle}')"
    sed -n '1,20p' "${WORK}/${_name}.log" >&2
    return 0
  fi
  echo "[modules] OK   ${_name} (fail)"
}

check_rc module_pub "${ROOT_DIR}/tests/cases/modules/module_pub.diva" 7
check_rc use_paths "${ROOT_DIR}/tests/cases/modules/use_paths.diva" 0
check_rc module_first_stmt "${ROOT_DIR}/tests/cases/modules/module_first_stmt.diva" 5
check_rc qualified_call "${ROOT_DIR}/tests/cases/modules/qualified_call.diva" 5
check_fail fail_unknown_fn "${ROOT_DIR}/tests/cases/modules/fail_unknown_fn.diva" "unknown function 'nope' in module 'math'"

echo "[modules] total=${total} failed=${failed}"
[ "${failed}" -eq 0 ]

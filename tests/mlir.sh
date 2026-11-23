#!/usr/bin/env sh
set -eu

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "${ROOT_DIR}"

WORK="$(mktemp -d "${TMPDIR:-/tmp}/diva-mlir.XXXXXX")"
trap 'rm -rf "${WORK}"' EXIT

if [ -n "${DIVA_PURE_DRIVER:-}" ] && [ -x "${DIVA_PURE_DRIVER}" ]; then
  DRIVER="${DIVA_PURE_DRIVER}"
else
  DRIVER="${WORK}/driver"
  echo "[mlir] building driver from bootstrap seed"
  if ! ROOT_DIR="${ROOT_DIR}" DI_STDLIB_DIR="${ROOT_DIR}/stdlib" DIVA_NO_EXTERNAL=1 \
       DI_RUNTIME_O="${ROOT_DIR}/bootstrap/runtime-linux-amd64.o" \
       timeout 900 "${ROOT_DIR}/bootstrap/diva-linux-amd64" build compiler "${DRIVER}" \
       >"${WORK}/driver-build.log" 2>&1; then
    cat "${WORK}/driver-build.log" >&2
    echo "[mlir] driver build failed" >&2
    exit 1
  fi
fi

echo "[mlir] DRIVER=${DRIVER}"

total=0
failed=0
fail() {
  failed=$((failed + 1))
  echo "[mlir] FAIL $1" >&2
}

has_line() {
  if ! grep -F -- "$2" "$1" >/dev/null; then
    fail "missing '$2'"
  fi
}

run_env() {
  DI_STDLIB_DIR="${ROOT_DIR}/stdlib" DIVA_NO_EXTERNAL=1 \
    DI_RUNTIME_O="${ROOT_DIR}/bootstrap/runtime-linux-amd64.o" "$@"
}

emit_case() {
  _name=$1
  _file="${ROOT_DIR}/tests/cases/mlir/$2"
  total=$((total + 1))
  if ! run_env timeout 60 "${DRIVER}" emit-mlir "${_file}" \
       >"${WORK}/${_name}.out" 2>"${WORK}/${_name}.err"; then
    fail "${_name} (emit-mlir exit)"
    cat "${WORK}/${_name}.err" >&2
    return 0
  fi
  has_line "${WORK}/${_name}.err" 'partial lowering (issue #119)'
  return 0
}

emit_case arith arith.diva
has_line "${WORK}/arith.out" 'module {'
has_line "${WORK}/arith.out" 'func.func @compute(%v0: i64, %v1: i64) -> i64 {'
has_line "${WORK}/arith.out" '%v5 = arith.addi %v3, %v4 : i64'
has_line "${WORK}/arith.out" '%v9 = arith.muli %v7, %v8 : i64'
has_line "${WORK}/arith.out" 'func.return %v10 : i64'
echo "[mlir] OK   arithmetic + SSA names"

emit_case control control.diva
has_line "${WORK}/control.out" 'func.func @pick(%v0: i64) -> i64 {'
has_line "${WORK}/control.out" '%v5 = arith.cmpi sgt, %v3, %v4 : i64'
has_line "${WORK}/control.out" 'cf.cond_br %v5, ^bb1, ^bb3'
has_line "${WORK}/control.out" '^bb1:'
has_line "${WORK}/control.out" 'cf.br ^bb2'
has_line "${WORK}/control.out" 'func.return %v8 : i64'
echo "[mlir] OK   control flow"

emit_case unsupported unsupported.diva
has_line "${WORK}/unsupported.out" '// diva.unsupported: text.concat'
if ! grep -E '^mlir: emitted [0-9]+ instruction\(s\), unsupported [1-9][0-9]*;' \
        "${WORK}/unsupported.err" >/dev/null; then
  fail 'unsupported summary count'
  cat "${WORK}/unsupported.err" >&2
fi
echo "[mlir] OK   unsupported-op comment + summary"

total=$((total + 1))
if run_env timeout 60 "${DRIVER}" emit-mlir --auto \
     "${ROOT_DIR}/tests/cases/mlir/arith.diva" >"${WORK}/auto.out" 2>"${WORK}/auto.err"; then
  if ! cmp -s "${WORK}/arith.out" "${WORK}/auto.out"; then
    fail '--auto changed emitted text'
  fi
  echo "[mlir] OK   --auto no-op"
else
  fail '--auto (emit-mlir exit)'
  cat "${WORK}/auto.err" >&2
fi

total=$((total + 1))
set +e
run_env timeout 60 "${DRIVER}" emit-mlir \
  "${ROOT_DIR}/tests/cases/mlir/sema_fail.diva" >"${WORK}/bad.out" 2>"${WORK}/bad.err"
bad_rc=$?
set -e
if [ "${bad_rc}" -eq 0 ]; then
  fail 'sema failure (expected non-zero exit)'
else
  has_line "${WORK}/bad.err" "sema: unknown identifier 'missing'"
  echo "[mlir] OK   sema failure exits non-zero"
fi

echo "[mlir] total=${total} failed=${failed}"
[ "${failed}" -eq 0 ]

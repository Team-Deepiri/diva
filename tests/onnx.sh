#!/usr/bin/env bash
# ONNX text-import foundation (issue #122): check, run, shape errors, MLIR.

set -eu

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "${ROOT_DIR}"

WORK="$(mktemp -d "${TMPDIR:-/tmp}/diva-onnx.XXXXXX")"
trap 'rm -rf "${WORK}"' EXIT

if [ -n "${DIVA_PURE_DRIVER:-}" ] && [ -x "${DIVA_PURE_DRIVER}" ]; then
  DRIVER="${DIVA_PURE_DRIVER}"
else
  DRIVER="${WORK}/driver"
  echo "[onnx] building driver from bootstrap seed"
  if ! ROOT_DIR="${ROOT_DIR}" DI_STDLIB_DIR="${ROOT_DIR}/stdlib" DIVA_NO_EXTERNAL=1 \
       DI_RUNTIME_O="${ROOT_DIR}/bootstrap/runtime-linux-amd64.o" \
       timeout 900 "${ROOT_DIR}/bootstrap/diva-linux-amd64" build compiler "${DRIVER}" \
       >"${WORK}/driver-build.log" 2>&1; then
    sed -n '1,40p' "${WORK}/driver-build.log" >&2
    echo "[onnx] driver build failed" >&2
    exit 1
  fi
fi

echo "[onnx] DRIVER=${DRIVER}"

total=0
failed=0
fail() {
  failed=$((failed + 1))
  echo "[onnx] FAIL $1" >&2
}

has_line() {
  if ! grep -F -- "$2" "$1" >/dev/null; then
    fail "missing '$2'"
  fi
}

run_env() {
  DI_STDLIB_DIR="${ROOT_DIR}/stdlib" DIVA_NO_EXTERNAL=1 \
    DI_RUNTIME_O="${ROOT_DIR}/bootstrap/runtime-linux-amd64.o" \
    DIVA_NATIVE_EXE_OUT="${WORK}/run.exe" "$@"
}

CASES="${ROOT_DIR}/tests/cases/onnx"

total=$((total + 1))
if ! run_env timeout 60 "${DRIVER}" onnx-check "${CASES}/two_nodes.txt" \
     >"${WORK}/check.out" 2>"${WORK}/check.err"; then
  fail "onnx-check exit"
  sed -n '1,40p' "${WORK}/check.err" >&2
else
  has_line "${WORK}/check.out" 'ok: 2 nodes'
  echo "[onnx] OK   check valid graph"
fi

total=$((total + 1))
if ! run_env timeout 60 "${DRIVER}" onnx-run "${CASES}/two_nodes.txt" \
     >"${WORK}/run.out" 2>"${WORK}/run.err"; then
  fail "onnx-run exit"
  sed -n '1,40p' "${WORK}/run.err" >&2
else
  has_line "${WORK}/run.out" 'y: 12 14 16 18'
  echo "[onnx] OK   two-node execution (Mul then Add)"
fi

total=$((total + 1))
if ! run_env timeout 60 "${DRIVER}" onnx-run "${CASES}/relu.txt" \
     >"${WORK}/relu.out" 2>"${WORK}/relu.err"; then
  fail "relu execution exit"
  sed -n '1,40p' "${WORK}/relu.err" >&2
else
  has_line "${WORK}/relu.out" 'y: 0 2 0 4 0 6'
  echo "[onnx] OK   rank-2 Relu execution"
fi

total=$((total + 1))
set +e
run_env timeout 60 "${DRIVER}" onnx-check "${CASES}/duplicate.txt" \
  >"${WORK}/dup.out" 2>"${WORK}/dup.err"
dup_rc=$?
set -e
if [ "${dup_rc}" -eq 0 ]; then
  fail "duplicate name (expected non-zero exit)"
else
  has_line "${WORK}/dup.err" "error: duplicate value name 'a'"
  echo "[onnx] OK   duplicate-name validation failure"
fi

total=$((total + 1))
set +e
run_env timeout 60 "${DRIVER}" onnx-check "${CASES}/shape_mismatch.txt" \
  >"${WORK}/shape.out" 2>"${WORK}/shape.err"
shape_rc=$?
set -e
if [ "${shape_rc}" -eq 0 ]; then
  fail "shape mismatch (expected non-zero exit)"
else
  has_line "${WORK}/shape.err" 'Add shape mismatch'
  echo "[onnx] OK   rank-2 shape mismatch rejected"
fi

total=$((total + 1))
if ! run_env timeout 60 "${DRIVER}" onnx-mlir "${CASES}/linalg.txt" \
     >"${WORK}/mlir.out" 2>"${WORK}/mlir.err"; then
  fail "onnx-mlir exit"
  sed -n '1,40p' "${WORK}/mlir.err" >&2
else
  has_line "${WORK}/mlir.out" '// diva.onnx node 0: Add -> linalg.add'
  has_line "${WORK}/mlir.out" '// diva.onnx node 1: MatMul -> linalg.matmul'
  if ! grep -F 'linalg.add ins(' "${WORK}/mlir.out" >/dev/null; then
    fail 'missing emitted linalg.add'
  fi
  if ! grep -F 'linalg.matmul ins(' "${WORK}/mlir.out" >/dev/null; then
    fail 'missing emitted linalg.matmul'
  fi
  echo "[onnx] OK   MLIR linalg output"
fi

total=$((total + 1))
if ! run_env timeout 60 "${DRIVER}" onnx-mlir "${CASES}/two_nodes.txt" \
     >"${WORK}/pending.out" 2>"${WORK}/pending.err"; then
  fail "onnx-mlir pending-op exit"
  sed -n '1,40p' "${WORK}/pending.err" >&2
else
  has_line "${WORK}/pending.out" '// diva.onnx node 0: Mul -> linalg.mul (pending; scalar arith.mul emitted)'
  echo "[onnx] OK   pending Linalg lowering comment"
fi

echo "[onnx] total=${total} failed=${failed}"
[ "${failed}" -eq 0 ]
echo "[onnx] all tests passed"

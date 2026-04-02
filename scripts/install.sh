#!/usr/bin/env sh
set -eu

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
INSTALL_DIR="${HOME}/.local/bin"
RUNTIME_DIR="${HOME}/.local/share/di/runtime"
STDLIB_DIR="${HOME}/.local/share/di/stdlib"
RUNTIME_SOURCE="${RUNTIME_DIR}/runtime.c"

mkdir -p "${ROOT_DIR}/build"
mkdir -p "${INSTALL_DIR}"
mkdir -p "${RUNTIME_DIR}"
mkdir -p "${STDLIB_DIR}"

cp "${ROOT_DIR}/runtime/runtime.c" "${RUNTIME_SOURCE}"
cp -R "${ROOT_DIR}/stdlib/." "${STDLIB_DIR}/"

cc -I"${ROOT_DIR}/include" \
  -DDI_RUNTIME_SOURCE="\"${RUNTIME_SOURCE}\"" \
  -DDI_STDLIB_DIR="\"${STDLIB_DIR}\"" \
  "${ROOT_DIR}/src/main.c" \
  "${ROOT_DIR}/src/driver.c" \
  "${ROOT_DIR}/src/diag.c" \
  "${ROOT_DIR}/src/token.c" \
  "${ROOT_DIR}/src/lexer.c" \
  "${ROOT_DIR}/src/ast.c" \
  "${ROOT_DIR}/src/ir.c" \
  "${ROOT_DIR}/src/parser.c" \
  "${ROOT_DIR}/src/sema.c" \
  "${ROOT_DIR}/src/codegen_llvm.c" \
  -o "${INSTALL_DIR}/di"

echo "Installed di to ${INSTALL_DIR}/di"
echo "Installed runtime to ${RUNTIME_SOURCE}"
echo "Installed stdlib to ${STDLIB_DIR}"
echo "Make sure ${INSTALL_DIR} is on your PATH."

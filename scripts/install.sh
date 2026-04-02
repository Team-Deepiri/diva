#!/usr/bin/env sh
set -eu

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
INSTALL_DIR="${HOME}/.local/bin"
RUNTIME_DIR="${HOME}/.local/share/di/runtime"
STDLIB_DIR="${HOME}/.local/share/di/stdlib"
RUNTIME_O="${RUNTIME_DIR}/runtime.o"

mkdir -p "${ROOT_DIR}/build"
mkdir -p "${INSTALL_DIR}"
mkdir -p "${RUNTIME_DIR}"
mkdir -p "${STDLIB_DIR}"

# Prefer LLVM IR (full hosted runtime). Without clang, merge bootstrap .o with runtime/extra.c
# (host_getenv / host_system for the Di bootstrap driver) — never use the stub runtime.c alone.
if command -v clang >/dev/null 2>&1 && [ -f "${ROOT_DIR}/runtime/runtime.ll" ]; then
  clang -c -O1 "${ROOT_DIR}/runtime/runtime.ll" -o "${RUNTIME_O}"
elif [ -f "${ROOT_DIR}/bootstrap/runtime-linux-amd64.o" ] && [ -f "${ROOT_DIR}/runtime/extra.c" ]; then
  cc -c -O2 "${ROOT_DIR}/runtime/extra.c" -o "${ROOT_DIR}/build/extra.o"
  ld -r "${ROOT_DIR}/bootstrap/runtime-linux-amd64.o" "${ROOT_DIR}/build/extra.o" -o "${RUNTIME_O}"
elif [ -f "${ROOT_DIR}/bootstrap/runtime-linux-amd64.o" ]; then
  cp "${ROOT_DIR}/bootstrap/runtime-linux-amd64.o" "${RUNTIME_O}"
elif [ -f "${ROOT_DIR}/runtime/runtime.c" ]; then
  cc -c -O2 "${ROOT_DIR}/runtime/runtime.c" -o "${RUNTIME_O}"
else
  echo "No runtime: need runtime/runtime.ll+clang, bootstrap/runtime-linux-amd64.o (+ runtime/extra.c), or runtime/runtime.c" >&2
  exit 1
fi

cp -R "${ROOT_DIR}/stdlib/." "${STDLIB_DIR}/"

if [ -f "${ROOT_DIR}/src/main.c" ]; then
  cc -std=c11 -O2 -Wall -Wextra -Wno-unused-parameter -Wno-format-truncation \
    -D_POSIX_C_SOURCE=200809L \
    -I"${ROOT_DIR}/include" \
    -DDI_STDLIB_DIR="\"${STDLIB_DIR}\"" \
    -DDI_RUNTIME_O="\"${RUNTIME_O}\"" \
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
else
  if [ ! -f "${ROOT_DIR}/bootstrap/di-linux-amd64" ]; then
    echo "Missing compiler sources and bootstrap/di-linux-amd64; cannot install." >&2
    exit 1
  fi
  cp "${ROOT_DIR}/bootstrap/di-linux-amd64" "${INSTALL_DIR}/di"
  chmod +x "${INSTALL_DIR}/di"
fi

echo "Installed di to ${INSTALL_DIR}/di"
echo "Installed runtime object to ${RUNTIME_O}"
echo "Installed stdlib to ${STDLIB_DIR}"
echo ""
echo "Add to your environment (e.g. ~/.profile):"
echo "  export PATH=\"${INSTALL_DIR}:\${PATH}\""
echo "  export DI_STDLIB_DIR=\"${STDLIB_DIR}\""
echo "  export DI_RUNTIME_O=\"${RUNTIME_O}\""
echo ""
echo "The compiler resolves DI_STDLIB_DIR and DI_RUNTIME_O at runtime; exports are optional if you use defaults under HOME."

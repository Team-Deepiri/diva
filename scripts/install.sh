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

# Hosted runtime: LLVM IR in-tree (runtime/runtime.ll). No C sources in this repository.
# - NO_CLANG=1: copy bootstrap/runtime-linux-amd64.o (must match runtime.ll; refresh when IR changes).
# - Else: compile .ll with clang when available, else copy the same bootstrap object.
if [ "${NO_CLANG:-}" = "1" ]; then
  if [ ! -f "${ROOT_DIR}/bootstrap/runtime-linux-amd64.o" ]; then
    echo "NO_CLANG=1: missing ${ROOT_DIR}/bootstrap/runtime-linux-amd64.o" >&2
    exit 1
  fi
  cp "${ROOT_DIR}/bootstrap/runtime-linux-amd64.o" "${RUNTIME_O}"
elif command -v clang >/dev/null 2>&1 && [ -f "${ROOT_DIR}/runtime/runtime.ll" ]; then
  clang -c -O1 "${ROOT_DIR}/runtime/runtime.ll" -o "${RUNTIME_O}"
elif [ -f "${ROOT_DIR}/bootstrap/runtime-linux-amd64.o" ]; then
  cp "${ROOT_DIR}/bootstrap/runtime-linux-amd64.o" "${RUNTIME_O}"
else
  echo "Need runtime/runtime.ll and clang, or bootstrap/runtime-linux-amd64.o" >&2
  exit 1
fi

cp -R "${ROOT_DIR}/stdlib/." "${STDLIB_DIR}/"

if [ ! -f "${ROOT_DIR}/bootstrap/di-linux-amd64" ]; then
  echo "Missing ${ROOT_DIR}/bootstrap/di-linux-amd64; cannot install." >&2
  exit 1
fi
cp "${ROOT_DIR}/bootstrap/di-linux-amd64" "${INSTALL_DIR}/di"
chmod +x "${INSTALL_DIR}/di"

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
echo "Linking user programs uses the system C compiler driver (cc) as a linker only — there are no C sources in this tree."

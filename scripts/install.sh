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

if command -v clang >/dev/null 2>&1; then
  clang -c -O1 "${ROOT_DIR}/runtime/runtime.ll" -o "${RUNTIME_O}"
else
  cp "${ROOT_DIR}/bootstrap/runtime-linux-amd64.o" "${RUNTIME_O}"
fi

cp -R "${ROOT_DIR}/stdlib/." "${STDLIB_DIR}/"

if [ ! -f "${ROOT_DIR}/bootstrap/di-linux-amd64" ]; then
  echo "Missing bootstrap/di-linux-amd64; cannot install." >&2
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

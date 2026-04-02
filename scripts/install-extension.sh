#!/usr/bin/env sh
set -eu

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
EXT_SRC="${ROOT_DIR}/tools/vscode-extension"
TARGET_ROOT="${1:-${HOME}/.cursor/extensions}"
TARGET_DIR="${TARGET_ROOT}/diri-lang"

mkdir -p "${TARGET_ROOT}"
rm -rf "${TARGET_DIR}"
cp -R "${EXT_SRC}" "${TARGET_DIR}"

echo "Installed Di editor extension to ${TARGET_DIR}"
echo "Use a different first argument to target VS Code, for example:"
echo "  ./scripts/install-extension.sh ~/.vscode/extensions"

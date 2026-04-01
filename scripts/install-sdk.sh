#!/usr/bin/env sh
set -eu

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)

sh "${ROOT_DIR}/scripts/install.sh"
sh "${ROOT_DIR}/scripts/install-filetype.sh"
sh "${ROOT_DIR}/scripts/install-extension.sh" "${1:-${HOME}/.cursor/extensions}"

echo
echo "Diri SDK install complete."
echo "Compiler: ${HOME}/.local/bin/diri"
echo "File type: .di"
echo "Extension target: ${1:-${HOME}/.cursor/extensions}"
echo
echo "Quickstart:"
echo "  diri new hello-di"
echo "  cd hello-di"
echo "  diri main.di"

#!/usr/bin/env sh
set -eu

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)

sh "${ROOT_DIR}/scripts/install.sh"
sh "${ROOT_DIR}/scripts/install-filetype.sh"
sh "${ROOT_DIR}/scripts/install-extension.sh" "${1:-${HOME}/.cursor/extensions}"

echo
echo "Diva SDK install complete."
echo "Compiler: ${HOME}/.local/bin/diva (symlink: di)"
echo "File type: .diva (MIME text/x-diva)"
echo "Extension target: ${1:-${HOME}/.cursor/extensions}"
echo
echo "Quickstart:"
echo "  diva new hello-diva"
echo "  cd hello-diva"
echo "  diva run ."

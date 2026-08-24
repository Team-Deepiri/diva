#!/usr/bin/env bash
# Issue #29: offline SDK tarball (bootstrap + stdlib + install scripts).
set -euo pipefail
ROOT_DIR="$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)"
cd "${ROOT_DIR}"
VER="${1:-dev}"
OUT="${ROOT_DIR}/diva-sdk-${VER}.tar.gz"
tar -czf "${OUT}" \
  bootstrap/ \
  stdlib/ \
  compiler/ \
  scripts/install-sdk.sh \
  scripts/install.sh \
  scripts/install-filetype.sh \
  scripts/install-extension.sh \
  docs/sdk-layout.md \
  docs/install-and-usage.md \
  docs/language-spec.md \
  README.md
echo "wrote ${OUT}"

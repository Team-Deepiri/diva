#!/usr/bin/env sh
# Build the reference C compiler and write bootstrap/diva-linux-amd64 (Linux x86-64 seed).
# The Diva-only tree has no compiler C sources; restore an older snapshot to rebuild:
#   git checkout <commit-with-c> -- src include runtime
#   sh scripts/build-bootstrap-seed.sh
set -eu

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
OUT="${ROOT_DIR}/bootstrap/diva-linux-amd64"
mkdir -p "${ROOT_DIR}/bootstrap"

if [ ! -f "${ROOT_DIR}/src/main.c" ]; then
  echo "Missing C sources under src/ (this tree is Diva-only)." >&2
  echo "Restore from an older commit, then run this script again. See bootstrap/README.md." >&2
  exit 1
fi

cc -std=c11 -O2 -Wall -Wextra -Wno-unused-parameter -Wno-format-truncation \
  -D_POSIX_C_SOURCE=200809L \
  -I"${ROOT_DIR}/include" \
  -DDI_RUNTIME_SOURCE="\"${ROOT_DIR}/runtime/runtime.c\"" \
  -DDI_STDLIB_DIR="\"${ROOT_DIR}/stdlib\"" \
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
  -o "${OUT}"

chmod +x "${OUT}"
echo "Wrote seed compiler: ${OUT}"

#!/usr/bin/env sh
# Integration test for tools/lsp/diva_text_lsp.diva (#190): a text-aware LSP
# server in pure Diva.
#
# Builds the server with the pure-ELF native driver, feeds it a scripted
# JSON-RPC session over stdio (regular-file redirect -> a single read, so
# read_file("/dev/stdin") sees the whole buffer), and asserts that every
# response carries the expected, grapheme-accurate fields.
#
# Usage (repo root):
#   sh tools/lsp/diva_text_lsp_test.sh
# Optional: DIVA_PURE_DRIVER=/path/to/diva to pin a specific driver.
set -eu

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
cd "${ROOT_DIR}"

if [ -n "${DIVA_PURE_DRIVER:-}" ] && [ -x "${DIVA_PURE_DRIVER}" ]; then
  DRIVER="${DIVA_PURE_DRIVER}"
elif [ -x "${ROOT_DIR}/build/diva-compiler-pure-elf" ]; then
  DRIVER="${ROOT_DIR}/build/diva-compiler-pure-elf"
else
  DRIVER="${ROOT_DIR}/build/diva-test"
fi
if [ ! -x "${DRIVER}" ]; then
  echo "[text-lsp] missing driver: ${DRIVER}" >&2
  exit 1
fi

WORK="$(mktemp -d "${TMPDIR:-/tmp}/diva-text-lsp.XXXXXX")"
trap 'rm -rf "${WORK}"' EXIT

echo "[text-lsp] DRIVER=${DRIVER}"

total=0
failed=0
fail() {
  failed=$((failed + 1))
  echo "[text-lsp] FAIL $1" >&2
}

# ---- build the server -------------------------------------------------------
SRC="${ROOT_DIR}/tools/lsp/diva_text_lsp.diva"
EXE="${WORK}/diva_text_lsp"
if ! DI_STDLIB_DIR="${ROOT_DIR}/stdlib" DIVA_NO_EXTERNAL=1 \
     DI_RUNTIME_O="${ROOT_DIR}/bootstrap/runtime-linux-amd64.o" \
     timeout 60 "${DRIVER}" build "${SRC}" "${EXE}" >"${WORK}/build.log" 2>&1; then
  sed -n '1,40p' "${WORK}/build.log" >&2
  echo "[text-lsp] FAIL build" >&2
  exit 1
fi

# ---- build the scripted session --------------------------------------------
FRAMES="${WORK}/frames.txt"
: > "${FRAMES}"
frame() { # frame <json>
  _body=$1
  _len=$(printf '%s' "${_body}" | wc -c | tr -d ' ')
  printf 'Content-Length: %s\r\n\r\n%s' "${_len}" "${_body}" >> "${FRAMES}"
}

# Document (line 0..4):
#   0: alpha
#   1:
#   2: café 日        (é = U+00E9, 日 = U+65E5)
#   3: e◌́x            (e + U+0301 combining acute + x)
#   4: func greet(): int
DOC='alpha\n\ncaf\u00e9 \u65e5\ne\u0301x\nfunc greet(): int'

frame '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{}}'
frame '{"jsonrpc":"2.0","method":"initialized","params":{}}'
frame '{"jsonrpc":"2.0","method":"textDocument/didOpen","params":{"textDocument":{"uri":"file:///t.diva","languageId":"diva","version":1,"text":"'"${DOC}"'"}}}'
frame '{"jsonrpc":"2.0","id":2,"method":"textDocument/hover","params":{"textDocument":{"uri":"file:///t.diva"},"position":{"line":2,"character":5}}}'
frame '{"jsonrpc":"2.0","id":3,"method":"textDocument/foldingRange","params":{"textDocument":{"uri":"file:///t.diva"}}}'
frame '{"jsonrpc":"2.0","id":4,"method":"textDocument/selectionRange","params":{"textDocument":{"uri":"file:///t.diva"},"positions":[{"line":3,"character":1}]}}'
frame '{"jsonrpc":"2.0","id":5,"method":"textDocument/documentSymbol","params":{"textDocument":{"uri":"file:///t.diva"}}}'
# full-sync change: doc becomes "aa\n\nbb\nend" (line 3 = "end")
frame '{"jsonrpc":"2.0","method":"textDocument/didChange","params":{"textDocument":{"uri":"file:///t.diva","version":2},"contentChanges":[{"text":"aa\n\nbb\nend"}]}}'
frame '{"jsonrpc":"2.0","id":6,"method":"textDocument/hover","params":{"textDocument":{"uri":"file:///t.diva"},"position":{"line":3,"character":0}}}'
frame '{"jsonrpc":"2.0","id":7,"method":"shutdown","params":{}}'
frame '{"jsonrpc":"2.0","method":"exit","params":{}}'

# ---- run --------------------------------------------------------------------
if ! timeout 10 "${EXE}" < "${FRAMES}" >"${WORK}/out.txt" 2>"${WORK}/err.txt"; then
  _rc=$?
  echo "[text-lsp] server exited ${_rc}" >&2
  sed -n '1,20p' "${WORK}/err.txt" >&2
  fail "server exit code"
fi
OUT=$(cat "${WORK}/out.txt")

check() { # check <name> <needle>
  total=$((total + 1))
  if printf '%s' "${OUT}" | grep -qF -- "$2"; then
    :
  else
    fail "$1 (missing: $2)"
  fi
}

check "initialize capabilities"  '"id":1,"result":{"capabilities":{"textDocumentSync":1,"hoverProvider":true'
check "hover byte offset"        'byteOffset: 13'
check "hover codepoint index"    'codepointIndex: 12'
check "hover display width"      'displayWidth: 5'
check "hover grapheme index"     'graphemeIndex: 12'
check "hover grapheme char"      'grapheme: 日'
check "hover range"              '"range":{"start":{"line":2,"character":5},"end":{"line":2,"character":6}}'
check "folding range"            '{"startLine":2,"endLine":4}'
check "selection range"          '{"range":{"start":{"line":3,"character":0},"end":{"line":3,"character":2}}}'
check "document symbol name"     '"name":"greet(): int"'
check "document symbol kind"     '"kind":12'
check "didChange hover result"   '"id":6,"result":{"contents"'
check "didChange grapheme e"     'grapheme: e'
check "shutdown null result"     '"id":7,"result":null'

if [ -s "${WORK}/err.txt" ]; then
  fail "stderr not empty"
fi

echo "[text-lsp] ${total} checks, ${failed} failed"
if [ "${failed}" -ne 0 ]; then
  exit 1
fi
echo "[text-lsp] OK"

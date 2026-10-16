#!/usr/bin/env sh
# Integration test for tools/lsp/diva_lang_lsp.diva (#104): a language-aware
# LSP server in pure Diva (sibling to diva_text_lsp #190).
#
# Builds the server with the pure-ELF native driver, feeds it a scripted
# JSON-RPC session over stdio (regular-file redirect -> a single read, so
# read_file("/dev/stdin") sees the whole buffer), and asserts that:
#   * publishDiagnostics flags every intentionally-broken fixture with the
#     exact expected message, and reports zero diagnostics for the valid
#     fixture and for every examples/*.diva file (false-positive sweep);
#   * documentSymbol lists the top-level declarations (and not nested ones)
#     with full declaration ranges;
#   * hover answers with keyword / stdlib-module documentation;
#   * completion offers keywords, modules, import paths and document names.
#
# Usage (repo root):
#   sh tools/lsp/diva_lang_lsp_test.sh
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
  echo "[lang-lsp] missing driver: ${DRIVER}" >&2
  exit 1
fi

WORK="$(mktemp -d "${TMPDIR:-/tmp}/diva-lang-lsp.XXXXXX")"
trap 'rm -rf "${WORK}"' EXIT

echo "[lang-lsp] DRIVER=${DRIVER}"

total=0
failed=0
fail() {
  failed=$((failed + 1))
  echo "[lang-lsp] FAIL $1" >&2
}

# ---- build the server -------------------------------------------------------
SRC="${ROOT_DIR}/tools/lsp/diva_lang_lsp.diva"
EXE="${WORK}/diva_lang_lsp"
if ! DI_STDLIB_DIR="${ROOT_DIR}/stdlib" DIVA_NO_EXTERNAL=1 \
     DI_RUNTIME_O="${ROOT_DIR}/bootstrap/runtime-linux-amd64.o" \
     timeout 60 "${DRIVER}" build "${SRC}" "${EXE}" >"${WORK}/build.log" 2>&1; then
  sed -n '1,40p' "${WORK}/build.log" >&2
  echo "[lang-lsp] FAIL build" >&2
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

# JSON-escape a file's contents (backslash, quote; lines joined with \n).
json_file() { # json_file <path>
  sed -e 's/\\/\\\\/g' -e 's/"/\\"/g' "$1" | awk 'NR>1{printf "\\n"} {printf "%s", $0}'
}

FIXTURES="${ROOT_DIR}/tools/lsp/fixtures"

frame '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{}}'
frame '{"jsonrpc":"2.0","method":"initialized","params":{}}'

# ---- broken fixtures: each must produce its exact diagnostic ---------------
BROKEN="${WORK}/broken.txt"
: > "${BROKEN}"
for name in broken_stray broken_unclosed broken_name broken_string broken_mismatch; do
  doc=$(json_file "${FIXTURES}/${name}.diva")
  printf '%s\n' "${name}" >> "${BROKEN}"
  frame '{"jsonrpc":"2.0","method":"textDocument/didOpen","params":{"textDocument":{"uri":"file:///'"${name}"'.diva","languageId":"diva","version":1,"text":"'"${doc}"'"}}}'
done

# ---- every example: zero diagnostics (false-positive sweep) ----------------
EXAMPLES="${WORK}/examples.txt"
ls "${ROOT_DIR}"/examples/*.diva | sed 's|.*/||' | sort > "${EXAMPLES}"
while IFS= read -r ex; do
  doc=$(json_file "${ROOT_DIR}/examples/${ex}")
  frame '{"jsonrpc":"2.0","method":"textDocument/didOpen","params":{"textDocument":{"uri":"file:///examples/'"${ex}"'","languageId":"diva","version":1,"text":"'"${doc}"'"}}}'
done < "${EXAMPLES}"

# ---- didChange: valid -> broken -> valid -----------------------------------
frame '{"jsonrpc":"2.0","method":"textDocument/didOpen","params":{"textDocument":{"uri":"file:///chg.diva","languageId":"diva","version":1,"text":"func ok(): void {\n}\n"}}}'
frame '{"jsonrpc":"2.0","method":"textDocument/didChange","params":{"textDocument":{"uri":"file:///chg.diva","version":2},"contentChanges":[{"text":"func broken(): void {\n}\n\n}\n"}]}}'
frame '{"jsonrpc":"2.0","method":"textDocument/didChange","params":{"textDocument":{"uri":"file:///chg.diva","version":3},"contentChanges":[{"text":"func ok(): void {\n}\n"}]}}'

# ---- valid fixture: opened LAST so it still occupies a store slot ----------
# (the store holds four documents; the 50 example didOpens above would evict
# it, and documentSymbol/hover/completion below all read this URI)
frame '{"jsonrpc":"2.0","method":"textDocument/didOpen","params":{"textDocument":{"uri":"file:///valid_symbols.diva","languageId":"diva","version":1,"text":"'"$(json_file "${FIXTURES}/valid_symbols.diva")"'"}}}'

# ---- documentSymbol ---------------------------------------------------------
frame '{"jsonrpc":"2.0","id":10,"method":"textDocument/documentSymbol","params":{"textDocument":{"uri":"file:///valid_symbols.diva"}}}'

# ---- hover ------------------------------------------------------------------
# valid_symbols.diva: line 1 = import "std/io.diva", line 3 = func alpha,
# line 9 = while inside count_to.
frame '{"jsonrpc":"2.0","id":11,"method":"textDocument/hover","params":{"textDocument":{"uri":"file:///valid_symbols.diva"},"position":{"line":9,"character":6}}}'
frame '{"jsonrpc":"2.0","id":12,"method":"textDocument/hover","params":{"textDocument":{"uri":"file:///valid_symbols.diva"},"position":{"line":1,"character":10}}}'
frame '{"jsonrpc":"2.0","id":13,"method":"textDocument/hover","params":{"textDocument":{"uri":"file:///valid_symbols.diva"},"position":{"line":3,"character":1}}}'
frame '{"jsonrpc":"2.0","id":14,"method":"textDocument/hover","params":{"textDocument":{"uri":"file:///valid_symbols.diva"},"position":{"line":3,"character":8}}}'

# ---- completion -------------------------------------------------------------
frame '{"jsonrpc":"2.0","id":20,"method":"textDocument/completion","params":{"textDocument":{"uri":"file:///valid_symbols.diva"}}}'

frame '{"jsonrpc":"2.0","id":30,"method":"shutdown","params":{}}'
frame '{"jsonrpc":"2.0","method":"exit","params":{}}'

# ---- run --------------------------------------------------------------------
if ! timeout 30 "${EXE}" < "${FRAMES}" >"${WORK}/out.txt" 2>"${WORK}/err.txt"; then
  _rc=$?
  echo "[lang-lsp] server exited ${_rc}" >&2
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

check_absent() { # check_absent <name> <needle>
  total=$((total + 1))
  if printf '%s' "${OUT}" | grep -qF -- "$2"; then
    fail "$1 (unexpected: $2)"
  fi
}

# initialize capabilities
check "initialize capabilities" '"id":1,"result":{"capabilities":{"textDocumentSync":1,"hoverProvider":true,"documentSymbolProvider":true,"completionProvider":{}},"serverInfo":{"name":"diva-lang-lsp"'

# broken fixtures: diagnostics published with the exact messages
check "stray bracket"        '"uri":"file:///broken_stray.diva","diagnostics":[{"range"'
check "stray message"        'stray `}` with no matching open bracket'
check "unclosed brace"       '"uri":"file:///broken_unclosed.diva","diagnostics":[{"range"'
check "unclosed message"     'unclosed `{`'
check "nameless func"        'expected a name after `func`'
check "nameless class"       'expected a name after `class`'
check "nameless struct"      'expected a name after `struct`'
check "nameless trait"       'expected a name after `trait`'
check "unterminated string"  '"uri":"file:///broken_string.diva","diagnostics":[{"range"'
check "string message"       'unterminated string'
check "mismatched bracket"   '"uri":"file:///broken_mismatch.diva","diagnostics":[{"range'
check "mismatched message"   'mismatched closing bracket: expected `(`, found `]`'

# valid fixture + examples: zero diagnostics (false-positive sweep)
check "valid fixture clean"  '"uri":"file:///valid_symbols.diva","diagnostics":[]'
while IFS= read -r ex; do
  check "example clean: ${ex}" '"uri":"file:///examples/'"${ex}"'","diagnostics":[]'
done < "${EXAMPLES}"

# didChange: broken content flagged, restored content clean
check "didChange diagnostics" '"uri":"file:///chg.diva","diagnostics":[{"range"'
check "didChange stray msg"   'stray `}` with no matching open bracket'
check "didChange restored"    '"uri":"file:///chg.diva","diagnostics":[]'

# documentSymbol: top-level declarations with full ranges, no nested methods
check "symbol alpha"      '"name":"alpha","kind":12,"location":{"uri":"file:///valid_symbols.diva","range":{"start":{"line":3,"character":0}'
check "symbol count_to"   '"name":"count_to","kind":12'
check "symbol Counter"    '"name":"Counter","kind":5'
check "symbol Point"      '"name":"Point","kind":23'
check "symbol Shape"      '"name":"Shape","kind":11'
check "symbol import"     '"name":"std/io.diva","kind":2'
check_absent "no nested bump" '"name":"bump"'
check_absent "no nested value" '"name":"value","kind":'

# hover
check "hover while"        '"id":11,"result":{"contents":{"kind":"markdown","value":"**`while`**'
check "hover while detail" 'Loop while the condition holds'
check "hover import path"  '"id":12,"result":{"contents":{"kind":"markdown","value":"**`std/io.diva`**'
check "hover import blurb" 'print_str, print_int, input_str'
check "hover keyword func" '"id":13,"result":{"contents":{"kind":"markdown","value":"**`func`**'
check "hover func detail"  'Declare a function'
check "hover unknown null" '"id":14,"result":null'

# completion
check "completion while"    '"label":"while","kind":14'
check "completion module"   '"label":"json","kind":9'
check "completion func"     '"label":"alpha","kind":3'
check "completion class"    '"label":"Counter","kind":7'
check "completion import"   '"label":"std/io.diva","kind":9'

# shutdown
check "shutdown null" '"id":30,"result":null'

if [ -s "${WORK}/err.txt" ]; then
  fail "stderr not empty"
fi

echo "[lang-lsp] total=${total} failed=${failed}"
if [ "${failed}" -ne 0 ]; then
  exit 1
fi
echo "[lang-lsp] OK"

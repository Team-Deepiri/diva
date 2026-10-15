#!/usr/bin/env sh
# Built-in NLP layer tests (#178-#184): span tokens, byte-level BPE,
# hashing embeddings + nearest neighbour, prompts/templates, tiny built-in
# model runtime, RAG with citations, and similarity.
#
# Usage (repo root):
#   sh tests/nlp.sh
# Optional: DIVA_PURE_DRIVER=/path/to/diva to pin a specific driver.
set -eu

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "${ROOT_DIR}"

if [ -n "${DIVA_PURE_DRIVER:-}" ] && [ -x "${DIVA_PURE_DRIVER}" ]; then
  DRIVER="${DIVA_PURE_DRIVER}"
elif [ -x "${ROOT_DIR}/build/diva-compiler-pure-elf" ]; then
  DRIVER="${ROOT_DIR}/build/diva-compiler-pure-elf"
else
  DRIVER="${ROOT_DIR}/build/diva-test"
fi
if [ ! -x "${DRIVER}" ]; then
  echo "[nlp] missing driver: ${DRIVER}" >&2
  exit 1
fi

WORK="$(mktemp -d "${TMPDIR:-/tmp}/diva-nlp.XXXXXX")"
trap 'rm -rf "${WORK}"' EXIT

echo "[nlp] DRIVER=${DRIVER}"

total=0
failed=0
fail() {
  failed=$((failed + 1))
  echo "[nlp] FAIL $1" >&2
}

# build_run <src> <exe> -> stdout on success
build_run() {
  if ! DI_STDLIB_DIR="${ROOT_DIR}/stdlib" DIVA_NO_EXTERNAL=1 \
       DI_RUNTIME_O="${ROOT_DIR}/bootstrap/runtime-linux-amd64.o" \
       timeout 60 "${DRIVER}" build "$1" "$2" >"${WORK}/build.log" 2>&1; then
    sed -n '1,40p' "${WORK}/build.log" >&2
    return 1
  fi
  timeout 10 "$2" 2>/dev/null
}

# check_case <name> <src> <expected>
check_case() {
  _name=$1
  _src=$2
  _want=$3
  total=$((total + 1))
  _exe="${WORK}/${_name}.exe"
  if ! _out=$(build_run "${_src}" "${_exe}"); then
    fail "${_name} (build)"
    return 0
  fi
  if [ "${_out}" != "${_want}" ]; then
    fail "${_name} (output)"
    printf '[nlp] expected:\n%s\n[nlp] actual:\n%s\n' "${_want}" "${_out}" >&2
    return 0
  fi
  echo "[nlp] OK   ${_name}"
}

check_case nlp "${ROOT_DIR}/tests/cases/text/nlp.diva" '0
0
1
4
Hi 0-2
, 2-3
café 4-9
! 9-10
1
25
bpe_rt_ok
2
0
2
0
25
<|system|>
you are helpful
<|user|>
hi
<|assistant|>
hello

Hello Ada, you have 7 messages. Literal: {{ok}}
unbound=[] injection={braces}
12
the cat sat on the cat
5
The sky is blue. [doc:1:0-16]
A cat is a small furry animal. [doc:2:0-30]
894
500
3
similar_yes
similar_no'

echo "[nlp] total=${total} failed=${failed}"
[ "${failed}" -eq 0 ]

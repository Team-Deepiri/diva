#!/usr/bin/env sh
# Regex engine stdlib tests (#172-#177).
#
# Builds and runs focused .diva programs against the pure-ELF native path and
# checks their stdout. Patterns exercise literals, dot, quantifiers (greedy and
# lazy), alternation, groups, backreferences, classes/shorthands, Unicode
# property classes, anchors, word boundaries, lookaround, replace/split, plus
# compile-error and size-limit diagnostics.
#
# Usage (repo root):
#   sh tests/text_regex.sh
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
  echo "[text-regex] missing driver: ${DRIVER}" >&2
  exit 1
fi

WORK="$(mktemp -d "${TMPDIR:-/tmp}/diva-text-regex.XXXXXX")"
trap 'rm -rf "${WORK}"' EXIT

echo "[text-regex] DRIVER=${DRIVER}"

total=0
failed=0
fail() {
  failed=$((failed + 1))
  echo "[text-regex] FAIL $1" >&2
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
    printf '[text-regex] expected:\n%s\n[text-regex] actual:\n%s\n' "${_want}" "${_out}" >&2
    return 0
  fi
  echo "[text-regex] OK   ${_name}"
}

check_case regex "${ROOT_DIR}/tests/cases/text/regex.diva" 'literal
4
9
hello
dot
2
5
aXc
star
0
2
ac
0
5
abbbc
plus
1
4
aaa
opt
0
5
color
0
6
colour
braces
0
3
aaa
0
2
aa
0
4
aaaa
lazy
0
3
<a>
alt
2
5
fox
group_backref
1
5
abab
0
3
4
8
shorthand
3
8
12345
2
6
_hi2
2
5
   
ranges
2
5
abc
2
5
abc
unicode_prop
3
8
éXYZ
2
4
12
anchors
true
false
2
4
ab
0
2
ab
word_boundary
2
5
cat
1
4
cat
lookahead
1
3
ab
1
3
ab
lookbehind
3
5
cd
3
5
cd
noncapture
2
6
abab
dotall
0
3
a
b
replace
a<[1]>b<[22]>c
x/bob y/alice
split
3
[a][b][c]
3
[][123][]
errors
0
syntax error
0
pattern too large'

echo "[text-regex] total=${total} failed=${failed}"
[ "${failed}" -eq 0 ]

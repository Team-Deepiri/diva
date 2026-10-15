#!/usr/bin/env sh
# `diva text` CLI tests (#189).
#
# The CLI lives inside the compiler driver itself, so this suite runs the
# compiler binary's `text` subcommands over generated fixtures and checks stdout.
#
# Usage (repo root):
#   sh tests/text_cli.sh
# Optional: DIVA_CLI=/path/to/diva to pin a specific compiler driver.
set -eu

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "${ROOT_DIR}"

if [ -n "${DIVA_CLI:-}" ] && [ -x "${DIVA_CLI}" ]; then
  CLI="${DIVA_CLI}"
elif [ -x "${ROOT_DIR}/build/diva-cli" ]; then
  CLI="${ROOT_DIR}/build/diva-cli"
elif [ -x "${ROOT_DIR}/build/diva-compiler-pure-elf" ]; then
  CLI="${ROOT_DIR}/build/diva-compiler-pure-elf"
else
  echo "[text-cli] missing compiler driver" >&2
  exit 1
fi

WORK="$(mktemp -d "${TMPDIR:-/tmp}/diva-text-cli.XXXXXX")"
trap 'rm -rf "${WORK}"' EXIT

echo "[text-cli] CLI=${CLI}"

total=0
failed=0
fail() {
  failed=$((failed + 1))
  echo "[text-cli] FAIL $1" >&2
}

# check <name> <expected> <args...>
check() {
  _name=$1
  _want=$2
  shift 2
  total=$((total + 1))
  if ! _out=$("${CLI}" text "$@" 2>/dev/null); then
    fail "${_name} (exit)"
    return 0
  fi
  if [ "${_out}" != "${_want}" ]; then
    fail "${_name} (output)"
    printf '[text-cli] expected:\n%s\n[text-cli] actual:\n%s\n' "${_want}" "${_out}" >&2
    return 0
  fi
  echo "[text-cli] OK   ${_name}"
}

# POSIX printf uses octal escapes: é=C3A9, 日=E697A5, 本=E69CAC.
printf 'Hello World\ncaf\303\251 \346\227\245\346\234\254\nsecond line here\n' > "${WORK}/sample.txt"

inspect_expected='bytes:      42
lines:      4
codepoints: 37
words:      7
width:      39
utf8:       valid'
check inspect "${inspect_expected}" inspect "${WORK}/sample.txt"
check count "42 4 37 7 39" count "${WORK}/sample.txt"
check width "39" width "${WORK}/sample.txt"

upper_expected='HELLO WORLD
CAFé 日本
SECOND LINE HERE'
check upper "${upper_expected}" upper "${WORK}/sample.txt"

lower_expected='hello world
café 日本
second line here'
check lower "${lower_expected}" lower "${WORK}/sample.txt"

words_expected='Hello
World
café
日本
second
line
here'
check words "${words_expected}" words "${WORK}/sample.txt"

check contains_yes "yes" contains café "${WORK}/sample.txt"
check contains_no "no" contains zzz "${WORK}/sample.txt"

lines_expected='1: Hello World
2: café 日本
3: second line here
4: '
check lines "${lines_expected}" lines "${WORK}/sample.txt"

# Invalid UTF-8 must be reported, not crash.
printf 'ok \377\376 bad' > "${WORK}/bad.txt"
total=$((total + 1))
bad_out=$("${CLI}" text inspect "${WORK}/bad.txt" 2>/dev/null | tail -1)
if [ "${bad_out}" != "utf8:       invalid" ]; then
  fail "bad_utf8 (output: ${bad_out})"
else
  echo "[text-cli] OK   bad_utf8"
fi

echo "[text-cli] total=${total} failed=${failed}"
[ "${failed}" -eq 0 ]

#!/usr/bin/env sh
# Phase 3 plain-text surface tests (#164-#171).
#
# Builds and runs focused .diva programs against the pure-ELF native path and
# checks their stdout. Stdin cases pipe a fixed byte string (built with printf,
# including DEL 0x7f for the readline backspace case); file I/O cases pass a
# scratch path in argv and run inside the test work dir.
#
# Usage (repo root):
#   sh tests/text_ops.sh
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
  echo "[text-ops] missing driver: ${DRIVER}" >&2
  exit 1
fi

WORK="$(mktemp -d "${TMPDIR:-/tmp}/diva-text-ops.XXXXXX")"
trap 'rm -rf "${WORK}"' EXIT

echo "[text-ops] DRIVER=${DRIVER}"

total=0
failed=0
fail() {
  failed=$((failed + 1))
  echo "[text-ops] FAIL $1" >&2
}

# build <src> <exe> -> 0 on success
build() {
  if ! DI_STDLIB_DIR="${ROOT_DIR}/stdlib" DIVA_NO_EXTERNAL=1 \
       DI_RUNTIME_O="${ROOT_DIR}/bootstrap/runtime-linux-amd64.o" \
       timeout 60 "${DRIVER}" build "$1" "$2" >"${WORK}/build.log" 2>&1; then
    sed -n '1,40p' "${WORK}/build.log" >&2
    return 1
  fi
  return 0
}

# check_case <name> <src> <expected>
check_case() {
  _name=$1
  _src=$2
  _want=$3
  total=$((total + 1))
  _exe="${WORK}/${_name}.exe"
  if ! build "${_src}" "${_exe}"; then
    fail "${_name} (build)"
    return 0
  fi
  if ! _out=$(timeout 10 "${_exe}" </dev/null 2>/dev/null); then
    fail "${_name} (run)"
    return 0
  fi
  if [ "${_out}" != "${_want}" ]; then
    fail "${_name} (output)"
    printf '[text-ops] expected:\n%s\n[text-ops] actual:\n%s\n' "${_want}" "${_out}" >&2
    return 0
  fi
  echo "[text-ops] OK   ${_name}"
}

# check_case_argv <name> <src> <expected> <arg>
check_case_argv() {
  _name=$1
  _src=$2
  _want=$3
  _arg=$4
  total=$((total + 1))
  _exe="${WORK}/${_name}.exe"
  if ! build "${_src}" "${_exe}"; then
    fail "${_name} (build)"
    return 0
  fi
  if ! _out=$(timeout 10 "${_exe}" "${_arg}" </dev/null 2>/dev/null); then
    fail "${_name} (run)"
    return 0
  fi
  if [ "${_out}" != "${_want}" ]; then
    fail "${_name} (output)"
    printf '[text-ops] expected:\n%s\n[text-ops] actual:\n%s\n' "${_want}" "${_out}" >&2
    return 0
  fi
  echo "[text-ops] OK   ${_name}"
}

# check_case_stdin <name> <src> <expected> <input_file>
check_case_stdin() {
  _name=$1
  _src=$2
  _want=$3
  _in=$4
  total=$((total + 1))
  _exe="${WORK}/${_name}.exe"
  if ! build "${_src}" "${_exe}"; then
    fail "${_name} (build)"
    return 0
  fi
  if ! _out=$(timeout 10 "${_exe}" <"${_in}" 2>/dev/null); then
    fail "${_name} (run)"
    return 0
  fi
  if [ "${_out}" != "${_want}" ]; then
    fail "${_name} (output)"
    printf '[text-ops] expected:\n%s\n[text-ops] actual:\n%s\n' "${_want}" "${_out}" >&2
    return 0
  fi
  echo "[text-ops] OK   ${_name}"
}

# --- #165 whole-file I/O round-trip --------------------------------------
check_case_argv io_roundtrip "${ROOT_DIR}/tests/cases/text/io_roundtrip.diva" '0
roundtrip_ok
17
3' "${WORK}/roundtrip.txt"

# --- #166/#167 lines, paragraphs, words ----------------------------------
check_case lines_paragraphs "${ROOT_DIR}/tests/cases/text/lines_paragraphs.diva" '4
4
crlf_ok
blank_ok
2
para_ok
6
word0_ok
word_ok
2
uni_word_ok
empty_ok'

# --- #166 sentences -------------------------------------------------------
check_case sentences "${ROOT_DIR}/tests/cases/text/sentences.diva" '4
s0_ok
s1_ok
s2_ok
s3_ok
1
s4_ok
0
0'

# --- #168 formatting ------------------------------------------------------
check_case formatting "${ROOT_DIR}/tests/cases/text/formatting.diva" 'join_ok
join_empty_ok
repeat_ok
repeat_zero_ok
padl_ok
padr_ok
pad_noop_ok
fmt_ok
fmt2_ok
fmt3_ok
fmt4_ok'

# --- #169 line editing ----------------------------------------------------
check_case line_edit "${ROOT_DIR}/tests/cases/text/line_edit.diva" 'ins_ok
del_ok
ins_end_ok
del_mid_ok
ins_empty_ok
del_only_ok
del_oob_ok'

# --- #169 diff ------------------------------------------------------------
check_case diff "${ROOT_DIR}/tests/cases/text/diff.diva" '5
0|a
2|b
1|x
0|c
1|d
3
2'

# --- #171 text builder ----------------------------------------------------
check_case builder "${ROOT_DIR}/tests/cases/text/builder.diva" '6
build_ok
utf8_ok
int_ok'

# --- #164/#170 stdin ------------------------------------------------------
printf 'first line\nsecond\n' >"${WORK}/stdin_lines.txt"
check_case_stdin read_line "${ROOT_DIR}/tests/cases/text/read_line.diva" 'first line|second|0' "${WORK}/stdin_lines.txt"

printf 'abc\177X\n' >"${WORK}/stdin_del.txt"
check_case_stdin readline_backspace "${ROOT_DIR}/tests/cases/text/readline_backspace.diva" 'P> abX
abX|' "${WORK}/stdin_del.txt"

echo "[text-ops] total=${total} failed=${failed}"
[ "${failed}" -eq 0 ]

#!/usr/bin/env sh
# Phase 2 Unicode stdlib tests (#154-#163).
#
# Builds and runs focused .diva programs against the pure-ELF native path and
# checks their stdout. Raw-byte (malformed UTF-8) cases are generated inline
# with printf so they can live in the source tree without binary fixtures.
#
# Usage (repo root):
#   sh tests/text_unicode.sh
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
  echo "[text-unicode] missing driver: ${DRIVER}" >&2
  exit 1
fi

WORK="$(mktemp -d "${TMPDIR:-/tmp}/diva-text-unicode.XXXXXX")"
trap 'rm -rf "${WORK}"' EXIT

echo "[text-unicode] DRIVER=${DRIVER}"

total=0
failed=0
fail() {
  failed=$((failed + 1))
  echo "[text-unicode] FAIL $1" >&2
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
    printf '[text-unicode] expected:\n%s\n[text-unicode] actual:\n%s\n' "${_want}" "${_out}" >&2
    return 0
  fi
  echo "[text-unicode] OK   ${_name}"
}

# --- #154 malformed UTF-8 must be rejected -------------------------------
{
  printf 'import "std/text.diva"\nimport "std/io.diva"\n'
  printf 'func chk(t: text, tag: str): int {\n'
  printf '  if utf8_validate(t) { print_str(tag) print_str(":VALID\\n") }\n'
  printf '  else { print_str(tag) print_str(":INVALID\\n") }\n'
  printf '  return 0\n}\n'
  printf 'func main(): int {\n'
  printf '  chk(text"%s", "overlong2")\n' "$(printf '\300\257')"
  printf '  chk(text"%s", "overlong3")\n' "$(printf '\340\200\257')"
  printf '  chk(text"%s", "overlong4")\n' "$(printf '\360\200\200\257')"
  printf '  chk(text"%s", "surrogate")\n' "$(printf '\355\240\200')"
  printf '  chk(text"%s", "toobig")\n' "$(printf '\364\220\200\200')"
  printf '  chk(text"%s", "truncated")\n' "$(printf '\303')"
  printf '  chk(text"%s", "lonecont")\n' "$(printf '\200')"
  printf '  chk(text"%s", "valid4")\n' "$(printf '\360\237\230\200')"
  printf '  chk(text"%s", "valid3")\n' "$(printf '\346\227\245')"
  printf '  return 0\n}\n'
} > "${WORK}/utf8_invalid.diva"

check_case utf8_invalid "${WORK}/utf8_invalid.diva" 'overlong2:INVALID
overlong3:INVALID
overlong4:INVALID
surrogate:INVALID
toobig:INVALID
truncated:INVALID
lonecont:INVALID
valid4:VALID
valid3:VALID'

check_case utf8_validate "${ROOT_DIR}/tests/cases/text/utf8_validate.diva" 'ascii_ok
latin_ok
cjk_ok
emoji_ok
range_ok
range_oob
2
26085
128512
oob_neg1
api_ok'

check_case encode_roundtrip "${ROOT_DIR}/tests/cases/text/encode_roundtrip.diva" '2
195
169
from_cp_eq
5
2
128512
cp_roundtrip
esc_ok
un_ok
u_ok
0
4
rt_valid'

check_case codepoint_iter "${ROOT_DIR}/tests/cases/text/codepoint_iter.diva" '4
3
7
233
26085
3
3
mid_neg1
4
oob_neg1
oob_byte_neg1'

check_case codegen_text_vreg_leak "${ROOT_DIR}/tests/cases/text/codegen_text_vreg_leak.diva" '1
6'

# --- Phase 2: Unicode property tables, case, normalization, width (#158-#163)
check_case ucd_props "${ROOT_DIR}/tests/cases/text/ucd_props.diva" 'ascii_letter
cjk_letter
upper_latin
lower_latin
arabic_digit
combining_mark
ideographic_space
digit_not_letter
230
5
6
15'

check_case case_map "${ROOT_DIR}/tests/cases/text/case_map.diva" 'upper_ss
lower_acc
fold_ss
case_eq
case_eq_acc
65
97
115
73
2'

check_case normalize "${ROOT_DIR}/tests/cases/text/normalize.diva" 'nfd_eq
nfc_eq
2
angstrom_nfc
2
hangul_roundtrip
nfd_idem
nfc_idem'

check_case display_width "${ROOT_DIR}/tests/cases/text/display_width.diva" '3
4
6
2
2
2
1
0
1
2'

check_case grapheme "${ROOT_DIR}/tests/cases/text/grapheme.diva" '3
3
1
1
1
1
1
3'

check_case collation "${ROOT_DIR}/tests/cases/text/collation.diva" 'lt
gt
eq
case_insensitive
mark_insensitive
1
2000098'

echo "[text-unicode] total=${total} failed=${failed}"
[ "${failed}" -eq 0 ]

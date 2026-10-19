#!/usr/bin/env sh
# Integration test for tools/fmt/diva_fmt.diva (#109): a canonical source
# formatter for Diva. Builds the formatter with the pure-ELF native driver and,
# over a corpus of real repo .diva files, asserts for each file:
#   (a) idempotency — format(format(x)) == format(x), and
#   (b) compile preservation — the formatted text still lexes/parses/type-checks
#       (run as `diva check` on a throwaway package holding the formatted file).
# Files that cannot be checked standalone (they need sibling modules not present
# in a temp package) are skipped and counted.
#
# Usage (repo root):
#   sh tools/fmt/diva_fmt_test.sh
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
  echo "[fmt] missing driver: ${DRIVER}" >&2
  exit 1
fi

WORK="$(mktemp -d "${TMPDIR:-/tmp}/diva-fmt.XXXXXX")"
trap 'rm -rf "${WORK}"' EXIT

echo "[fmt] DRIVER=${DRIVER}"

total=0
failed=0
skipped=0
fail() {
  failed=$((failed + 1))
  echo "[fmt] FAIL $1" >&2
}

# ---- build the formatter ----------------------------------------------------
FMT_SRC="${ROOT_DIR}/tools/fmt/diva_fmt.diva"
FMT="${WORK}/diva_fmt"
if ! DI_STDLIB_DIR="${ROOT_DIR}/stdlib" DIVA_NO_EXTERNAL=1 \
     DI_RUNTIME_O="${ROOT_DIR}/bootstrap/runtime-linux-amd64.o" \
     timeout 120 "${DRIVER}" build "${FMT_SRC}" "${FMT}" >"${WORK}/build.log" 2>&1; then
  sed -n '1,40p' "${WORK}/build.log" >&2
  echo "[fmt] FAIL build formatter" >&2
  exit 1
fi
echo "[fmt] built formatter"

# check_standalone <src-file> : lex+parse+sema a source as a throwaway package.
# Non-zero when the file cannot be checked standalone.
check_standalone() {
  _src=$1
  _pkg="${WORK}/pkg"
  rm -rf "${_pkg}"
  mkdir -p "${_pkg}/src"
  printf 'name = "fmtcheck"\nkind = "lib"\nentry = "src/lib.diva"\n' > "${_pkg}/package.diva"
  cp "${_src}" "${_pkg}/src/lib.diva"
  DI_STDLIB_DIR="${ROOT_DIR}/stdlib" timeout 60 "${DRIVER}" check "${_pkg}" >"${WORK}/check.log" 2>&1
}

# check_one <label> <path>
check_one() {
  _label=$1
  _path=$2
  total=$((total + 1))
  if ! check_standalone "${_path}"; then
    skipped=$((skipped + 1))
    echo "[fmt] skip ${_label} (not standalone-checkable)"
    return 0
  fi
  if ! "${FMT}" "${_path}" >"${WORK}/f1" 2>"${WORK}/fmt.err"; then
    sed -n '1,20p' "${WORK}/fmt.err" >&2
    fail "${_label} format"
    return 0
  fi
  if ! "${FMT}" "${WORK}/f1" >"${WORK}/f2" 2>/dev/null; then
    fail "${_label} reformat"
    return 0
  fi
  if ! cmp -s "${WORK}/f1" "${WORK}/f2"; then
    fail "${_label} not idempotent"
    return 0
  fi
  if ! check_standalone "${WORK}/f1"; then
    sed -n '1,20p' "${WORK}/check.log" >&2
    fail "${_label} formatted output does not compile"
    return 0
  fi
}

# ---- curated fixture (messy input -> canonical output) ----------------------
total=$((total + 1))
FIX_IN="${ROOT_DIR}/tools/fmt/fixtures/messy.diva"
FIX_WANT="${ROOT_DIR}/tools/fmt/fixtures/messy.expected.diva"
if ! "${FMT}" "${FIX_IN}" >"${WORK}/fx1" 2>"${WORK}/fx.err"; then
  sed -n '1,20p' "${WORK}/fx.err" >&2
  fail "fixture format"
else
  "${FMT}" "${WORK}/fx1" >"${WORK}/fx2" 2>/dev/null || true
  if ! cmp -s "${WORK}/fx1" "${WORK}/fx2"; then
    fail "fixture not idempotent"
  fi
  if ! cmp -s "${WORK}/fx1" "${FIX_WANT}"; then
    fail "fixture canonical output mismatch"
  fi
  if ! check_standalone "${WORK}/fx1"; then
    fail "fixture formatted output does not compile"
  fi
fi

# ---- real-repo corpus -------------------------------------------------------
for f in \
    examples/*.diva \
    stdlib/std/sort.diva \
    stdlib/std/kv.diva \
    tests/cases/kv/kv_basic.diva \
    tests/cases/kv/kv_stress.diva ; do
  check_one "${f}" "${f}"
done

echo "[fmt] total=${total} failed=${failed} skipped=${skipped}"
if [ "${failed}" -ne 0 ]; then
  exit 1
fi
echo "[fmt] OK"

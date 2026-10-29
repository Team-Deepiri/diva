#!/usr/bin/env bash
# #92 slices

set -u

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "${ROOT_DIR}"

WORK="$(mktemp -d "${TMPDIR:-/tmp}/diva-slices.XXXXXX")"
trap 'rm -rf "${WORK}"' EXIT

if [ -n "${DIVA_PURE_DRIVER:-}" ] && [ -x "${DIVA_PURE_DRIVER}" ]; then
  DRIVER="${DIVA_PURE_DRIVER}"
else
  DRIVER="${WORK}/driver"
  echo "[slices] building driver from bootstrap seed"
  if ! ROOT_DIR="${ROOT_DIR}" DI_STDLIB_DIR="${ROOT_DIR}/stdlib" DIVA_NO_EXTERNAL=1 \
       DI_RUNTIME_O="${ROOT_DIR}/bootstrap/runtime-linux-amd64.o" \
       timeout 900 "${ROOT_DIR}/bootstrap/diva-linux-amd64" build compiler "${DRIVER}" \
       >"${WORK}/driver-build.log" 2>&1; then
    sed -n '1,40p' "${WORK}/driver-build.log" >&2
    echo "[slices] driver build failed" >&2
    exit 1
  fi
fi

echo "[slices] DRIVER=${DRIVER}"

total=0
failed=0
fail() {
  failed=$((failed + 1))
  echo "[slices] FAIL $1" >&2
}

build() {
  if ! DI_STDLIB_DIR="${ROOT_DIR}/stdlib" DIVA_NO_EXTERNAL=1 \
       DI_RUNTIME_O="${ROOT_DIR}/bootstrap/runtime-linux-amd64.o" \
       timeout 60 "${DRIVER}" build "$1" "$2" >"${WORK}/build.log" 2>&1; then
    sed -n '1,40p' "${WORK}/build.log" >&2
    return 1
  fi
  return 0
}

check_case() {
  name=$1
  src=$2
  want=$3
  total=$((total + 1))
  exe="${WORK}/${name}.exe"
  if ! build "${src}" "${exe}"; then
    fail "${name} (build)"
    return 0
  fi
  out=$(timeout 60 "${exe}" </dev/null 2>&1) || true
  if [ "$out" != "$want" ]; then
    fail "${name} (output)"
    printf '[slices] expected:\n%s\n[slices] actual:\n%s\n' "$want" "$out" >&2
    return 0
  fi
  echo "[slices] OK ${name}"
}

check_case array_literal tests/cases/slices/array_literal.diva $'4\n10\n30\n100'
check_case slice_expr tests/cases/slices/slice_expr.diva $'3\n2\n9\n2'
check_case slice_index_store tests/cases/slices/slice_index_store.diva $'1\n99\n3'
check_case len_assign_slice tests/cases/slices/len_assign_slice.diva $'42\n2'
check_case empty_slice tests/cases/slices/empty_slice.diva $'0\n0'
check_case str_elements tests/cases/slices/str_elements.diva $'3\nbb'
check_case bool_elements tests/cases/slices/bool_elements.diva $'1\n0'
check_case nested_slice tests/cases/slices/nested_slice.diva $'2\n2\n3'
check_case full_slice tests/cases/slices/full_slice.diva $'3\n20'
check_case empty_subslice tests/cases/slices/empty_subslice.diva $'0'
check_case pass_slice tests/cases/slices/pass_slice.diva $'7\n42'

check_trap() {
  name=$1
  src=$2
  total=$((total + 1))
  exe="${WORK}/${name}.exe"
  if ! build "${src}" "${exe}"; then
    fail "${name} (build)"
    return 0
  fi
  timeout 60 "${exe}" </dev/null >/dev/null 2>&1
  rc=$?
  if [ "${rc}" != 1 ]; then
    fail "${name} (expected trap rc=1 got=${rc})"
    return 0
  fi
  echo "[slices] OK ${name}"
}

cat > "${WORK}/bad_idx.diva" <<'DIV'
func main(): int {
    var xs: [int] = [1, 2, 3]
    var x = xs[5]
    return x
}
DIV
check_trap oob_index "${WORK}/bad_idx.diva"

cat > "${WORK}/bad_neg.diva" <<'DIV'
func main(): int {
    var xs: [int] = [1, 2, 3]
    var i = 0 - 1
    xs[i] = 5
    return 0
}
DIV
check_trap oob_neg "${WORK}/bad_neg.diva"

cat > "${WORK}/bad_slice.diva" <<'DIV'
func main(): int {
    var xs: [int] = [1, 2, 3]
    var s: [int] = xs[0:5]
    return 0
}
DIV
check_trap oob_slice "${WORK}/bad_slice.diva"

cat > "${WORK}/bad_slice_rev.diva" <<'DIV'
func main(): int {
    var xs: [int] = [1, 2, 3]
    var s: [int] = xs[3:2]
    return 0
}
DIV
check_trap oob_slice_rev "${WORK}/bad_slice_rev.diva"

cat > "${WORK}/bad_slice_neg.diva" <<'DIV'
func main(): int {
    var xs: [int] = [1, 2, 3]
    var s: [int] = xs[-1:2]
    return 0
}
DIV
check_trap oob_slice_neg "${WORK}/bad_slice_neg.diva"

echo "[slices] $total passed, $failed failed"
if [ "$failed" -ne 0 ]; then
  exit 1
fi
exit 0

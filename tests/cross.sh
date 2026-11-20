#!/usr/bin/env sh
set -eu

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
WORK="$(mktemp -d "${TMPDIR:-/tmp}/diva-cross.XXXXXX")"
trap 'rm -rf "${WORK}"' EXIT
SRC="${ROOT_DIR}/examples/hello.diva"

if [ -n "${DIVA_PURE_DRIVER:-}" ] && [ -x "${DIVA_PURE_DRIVER}" ]; then
  DRIVER="${DIVA_PURE_DRIVER}"
elif [ -x "${ROOT_DIR}/build/diva-cross" ]; then
  DRIVER="${ROOT_DIR}/build/diva-cross"
else
  DRIVER="${WORK}/driver"
  echo "[cross] building driver from bootstrap seed"
  if ! ROOT_DIR="${ROOT_DIR}" DI_STDLIB_DIR="${ROOT_DIR}/stdlib" DIVA_NO_EXTERNAL=1 \
       DI_RUNTIME_O="${ROOT_DIR}/bootstrap/runtime-linux-amd64.o" \
       timeout 1200 "${ROOT_DIR}/bootstrap/diva-linux-amd64" build compiler "${DRIVER}" \
       >"${WORK}/driver-build.log" 2>&1; then
    sed -n '1,80p' "${WORK}/driver-build.log" >&2
    echo "[cross] driver build failed" >&2
    exit 1
  fi
fi

echo "[cross] DRIVER=${DRIVER}"

total=0
failed=0

fail() {
  failed=$((failed + 1))
  echo "[cross] FAIL $1" >&2
}

pass() {
  echo "[cross] OK   $1"
}

driver() {
  DI_STDLIB_DIR="${ROOT_DIR}/stdlib" DIVA_NO_EXTERNAL=1 \
  DI_RUNTIME_O="${ROOT_DIR}/bootstrap/runtime-linux-amd64.o" \
  timeout 120 "${DRIVER}" "$@"
}

expect_current() {
  total=$((total + 1))
  out="${WORK}/current.out"
  if ! driver target current >"${out}" 2>&1; then
    fail "target current (command failed)"
    sed -n '1,40p' "${out}" >&2
    return 0
  fi
  actual=$(strip_di_logs "${out}")
  if [ "${actual}" != "x86_64-linux-gnu" ]; then
    fail "target current (got '${actual}', want 'x86_64-linux-gnu')"
    return 0
  fi
  pass "target current"
}

expect_list() {
  total=$((total + 1))
  out="${WORK}/list.out"
  if ! driver target list >"${out}" 2>&1; then
    fail "target list (command failed)"
    sed -n '1,40p' "${out}" >&2
    return 0
  fi
  for needle in \
    "x86_64-linux-gnu  supported (native)" \
    "aarch64-linux-gnu  declared, not implemented" \
    "aarch64-none-elf  declared, not implemented" \
    "x86_64-apple-darwin  declared, not implemented"
  do
    if ! grep -F -- "${needle}" "${out}" >/dev/null; then
      fail "target list (missing '${needle}')"
      sed -n '1,80p' "${out}" >&2
      return 0
    fi
  done
  pass "target list"
}

expect_build_accepted() {
  triple=$1
  name=$2
  positional_flag=$3
  total=$((total + 1))
  exe="${WORK}/${name}.exe"
  log="${WORK}/${name}.log"
  if [ "${positional_flag}" = "before" ]; then
    if ! driver build --target "${triple}" "${SRC}" "${exe}" >"${log}" 2>&1; then
      fail "build --target ${triple}"
      sed -n '1,60p' "${log}" >&2
      return 0
    fi
  else
    if ! driver build "${SRC}" --target "${triple}" "${exe}" >"${log}" 2>&1; then
      fail "build ${SRC} --target ${triple}"
      sed -n '1,60p' "${log}" >&2
      return 0
    fi
  fi
  got=$(timeout 60 "${exe}" </dev/null 2>/dev/null) || {
    fail "build --target ${triple} (run)"
    return 0
  }
  if [ "${got}" != "10" ]; then
    fail "build --target ${triple} (got '${got}', want '10')"
    return 0
  fi
  pass "build --target ${triple}"
}

expect_ir_opt_accepted() {
  cmd=$1
  triple=$2
  total=$((total + 1))
  log="${WORK}/${cmd}-${triple}.log"
  if ! driver "${cmd}" --target "${triple}" "${SRC}" >"${log}" 2>&1; then
    fail "${cmd} --target ${triple}"
    sed -n '1,60p' "${log}" >&2
    return 0
  fi
  pass "${cmd} --target ${triple}"
}

expect_rejected() {
  cmd=$1
  triple=$2
  needle=$3
  total=$((total + 1))
  log="${WORK}/${cmd}-reject-$(echo "${triple}" | tr -c 'A-Za-z0-9' '_').log"
  exe="${WORK}/${cmd}-reject-$(echo "${triple}" | tr -c 'A-Za-z0-9' '_').exe"
  set +e
  if [ "${cmd}" = "build" ]; then
    driver build --target "${triple}" "${SRC}" "${exe}" >"${log}" 2>&1
  else
    driver "${cmd}" --target "${triple}" "${SRC}" >"${log}" 2>&1
  fi
  rc=$?
  set -e
  if [ "${rc}" -eq 0 ]; then
    fail "${cmd} --target ${triple} (expected non-zero exit)"
    return 0
  fi
  if ! grep -F -- "${needle}" "${log}" >/dev/null; then
    fail "${cmd} --target ${triple} (missing '${needle}')"
    sed -n '1,60p' "${log}" >&2
    return 0
  fi
  if [ "${cmd}" = "build" ] && [ -e "${exe}" ]; then
    fail "${cmd} --target ${triple} (unexpected executable emitted)"
    return 0
  fi
  pass "${cmd} --target ${triple} rejected"
}

expect_missing_value() {
  total=$((total + 1))
  log="${WORK}/missing-value.log"
  set +e
  driver build --target >"${log}" 2>&1
  rc=$?
  set -e
  if [ "${rc}" -eq 0 ]; then
    fail "build --target (expected non-zero exit)"
    return 0
  fi
  if ! grep -F -- "error: --target requires a triple" "${log}" >/dev/null; then
    fail "build --target (missing diagnostic)"
    sed -n '1,40p' "${log}" >&2
    return 0
  fi
  pass "build --target missing value"
}

strip_di_logs() {
  awk '
    index($0, "[di] ") == 1 { next }
    index($0, "[diva] ") == 1 { next }
    index($0, "[native] ") == 1 { next }
    { print }
  ' "$1"
}

expect_current
expect_list

expect_build_accepted x86_64-linux-gnu native-native before
expect_build_accepted x86_64-linux native-alias before
expect_build_accepted native native-alias2 after
expect_ir_opt_accepted ir x86_64-linux-gnu
expect_ir_opt_accepted opt native

for cmd in build ir opt; do
  for triple in aarch64-linux-gnu aarch64-none-elf x86_64-apple-darwin; do
    expect_rejected "${cmd}" "${triple}" \
      "error: target '${triple}' is declared but not implemented (only x86_64-linux-gnu is supported)"
  done
  for triple in x86_64--gnu x86_64 foo-linux-gnu x86_64-linux-bogus; do
    expect_rejected "${cmd}" "${triple}" "error: malformed target '${triple}'"
  done
done
expect_missing_value

echo "[cross] ${total} checks, ${failed} failed"
if [ "${failed}" -ne 0 ]; then
  exit 1
fi
echo "all target tests passed"

#!/usr/bin/env sh
set -eu

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
TEST_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/diva-tests.XXXXXX")
HOME_DIR="${TEST_ROOT}/home"
BIN_DIR="${HOME_DIR}/.local/bin"

cleanup() {
    rm -rf "${TEST_ROOT}"
}

trap cleanup EXIT INT TERM

mkdir -p "${HOME_DIR}"

log() {
    printf '[test] %s\n' "$1"
}

fail() {
    printf '[test:error] %s\n' "$1" >&2
    exit 1
}

strip_di_logs() {
    awk '
      index($0, "[di] ") == 1 { next }
      index($0, "[di:error] ") == 1 { next }
      index($0, "[native] ") == 1 { next }
      index($0, "/usr/bin/ld:") == 1 { next }
      index($0, "collect2:") == 1 { next }
      index($0, "undefined reference") > 0 { next }
      index($0, "(.text+") == 1 { next }
      index($0, "link failed (requires cc") == 1 { next }
      index($0, "loader: ") == 1 { next }
      index($0, "sh: ") == 1 { next }
      { print }
    ' "$1"
}

assert_output_equals() {
    file_path=$1
    expected=$2
    output_file="${TEST_ROOT}/command.out"

    if ! diva run "${file_path}" >"${output_file}" 2>&1; then
        sed -n '1,120p' "${output_file}" >&2
        fail "command failed: diva run ${file_path}"
    fi

    actual=$(strip_di_logs "${output_file}")
    if [ "${actual}" != "${expected}" ]; then
        printf '[test:error] unexpected runtime output for %s\n' "${file_path}" >&2
        printf '[test:error] expected:\n%s\n' "${expected}" >&2
        printf '[test:error] actual:\n%s\n' "${actual}" >&2
        exit 1
    fi
}

assert_contains() {
    file_path=$1
    needle=$2
    output_file="${TEST_ROOT}/command.out"

    if ! diva build "${file_path}" --ast >"${output_file}" 2>&1; then
        sed -n '1,120p' "${output_file}" >&2
        fail "command failed: diva build ${file_path} --ast"
    fi

    if ! grep -F "${needle}" "${output_file}" >/dev/null; then
        printf '[test:error] expected to find "%s" in AST output for %s\n' "${needle}" "${file_path}" >&2
        sed -n '1,120p' "${output_file}" >&2
        exit 1
    fi
}

assert_error_contains() {
    file_path=$1
    needle=$2
    output_file="${TEST_ROOT}/command.out"

    if diva build "${file_path}" >"${output_file}" 2>&1; then
        sed -n '1,120p' "${output_file}" >&2
        fail "expected failure for ${file_path}"
    fi

    if ! grep -F "${needle}" "${output_file}" >/dev/null; then
        printf '[test:error] expected to find "%s" in failure output for %s\n' "${needle}" "${file_path}" >&2
        sed -n '1,120p' "${output_file}" >&2
        exit 1
    fi
}

assert_ir_contains() {
    file_path=$1
    needle=$2
    output_file="${TEST_ROOT}/command.out"

    if ! diva emit-ir "${file_path}" >"${output_file}" 2>&1; then
        sed -n '1,120p' "${output_file}" >&2
        fail "command failed: diva emit-ir ${file_path}"
    fi

    actual=$(strip_di_logs "${output_file}")
    printf '%s\n' "${actual}" >"${output_file}.stripped"
    if grep -F "${needle}" "${output_file}.stripped" >/dev/null; then
        return 0
    fi

    printf '[test:error] expected to find "%s" in emit-ir output for %s\n' "${needle}" "${file_path}" >&2
    sed -n '1,160p' "${output_file}.stripped" >&2
    exit 1
}

log "installing diva into temporary home"
HOME="${HOME_DIR}" sh "${ROOT_DIR}/scripts/install.sh" >"${TEST_ROOT}/install.out" 2>&1 || {
    sed -n '1,120p' "${TEST_ROOT}/install.out" >&2
    fail "install script failed"
}

HOME="${HOME_DIR}"
export HOME
PATH="${BIN_DIR}:${PATH}"
export PATH
DIVA_BOOTSTRAP="${ROOT_DIR}/bootstrap/diva-linux-amd64"
export DIVA_BOOTSTRAP
DI_BOOTSTRAP="${ROOT_DIR}/bootstrap/diva-linux-amd64"
export DI_BOOTSTRAP
DI_STDLIB_DIR="${HOME_DIR}/.local/share/diva/stdlib"
export DI_STDLIB_DIR
DI_RUNTIME_O="${HOME_DIR}/.local/share/diva/runtime/runtime.o"
export DI_RUNTIME_O

log "checking compiler stub packages (mir, backend, frontend)"
for _pkg in mir backend frontend; do
    if ! diva check "${ROOT_DIR}/compiler/${_pkg}" >"${TEST_ROOT}/check-${_pkg}.out" 2>&1; then
        sed -n '1,80p' "${TEST_ROOT}/check-${_pkg}.out" >&2
        fail "diva check compiler/${_pkg} failed"
    fi
done

run_all_tests() {
    _stage=$1
    log "running integration tests (${_stage})"
assert_output_equals "${ROOT_DIR}/examples/hello.diva" "10"
assert_output_equals "${ROOT_DIR}/examples/host_argv.diva" "1"
assert_output_equals "${ROOT_DIR}/examples/vec_demo.diva" "2
20
10
hello diva"
assert_output_equals "${ROOT_DIR}/examples/branching.diva" "running diva
20
1"
assert_output_equals "${ROOT_DIR}/examples/loop.diva" "10"
assert_output_equals "${ROOT_DIR}/examples/shadow.diva" "99
5"
assert_output_equals "${ROOT_DIR}/examples/structs.diva" "18
7"
assert_output_equals "${ROOT_DIR}/examples/struct_mutation.diva" "10"
assert_output_equals "${ROOT_DIR}/examples/arrays.diva" "9"
assert_output_equals "${ROOT_DIR}/examples/array_mutation.diva" "16"
assert_output_equals "${ROOT_DIR}/examples/imports/main.diva" "42"
assert_output_equals "${ROOT_DIR}/examples/generics_traits.diva" "7"
assert_output_equals "${ROOT_DIR}/examples/stdlib_demo.diva" "12
10
10
5
1
1"
assert_output_equals "${ROOT_DIR}/examples/systems_hosted.diva" "systems io from diva0x14"
assert_output_equals "${ROOT_DIR}/examples/packages/app_with_dep" "42"
assert_output_equals "${ROOT_DIR}/examples/utils_demo.diva" "util-1
6
true
true
0x4
1
1"

log "checking Diva lexer (diva lex)"
if ! diva lex "${ROOT_DIR}/examples/hello.diva" >"${TEST_ROOT}/lex.out" 2>&1; then
    sed -n '1,40p' "${TEST_ROOT}/lex.out" >&2
    fail "diva lex failed"
fi
if ! grep -q "KW_LET" "${TEST_ROOT}/lex.out"; then
    sed -n '1,40p' "${TEST_ROOT}/lex.out" >&2
    fail "diva lex output missing KW_LET"
fi

log "checking AST smoke output"
assert_contains "${ROOT_DIR}/examples/hello.diva" "Program"
assert_contains "${ROOT_DIR}/examples/hello.diva" "Var(x: int)"
assert_contains "${ROOT_DIR}/examples/hello.diva" "Ident(print_int)"

log "checking Diva IR smoke output (emit-ir)"
assert_ir_contains "${ROOT_DIR}/examples/loop.diva" "br.cond"
assert_ir_contains "${ROOT_DIR}/examples/arrays.diva" "store"
assert_ir_contains "${ROOT_DIR}/examples/array_mutation.diva" "store"

log "checking semantic failure cases"
assert_error_contains "${ROOT_DIR}/tests/cases/fail/duplicate_decl.diva" "duplicate declaration of 'x' in the same scope"
assert_error_contains "${ROOT_DIR}/tests/cases/fail/unknown_ident.diva" "unknown identifier 'missing'"
assert_error_contains "${ROOT_DIR}/tests/cases/fail/reserved_name.diva" "uses a reserved backend identifier"
assert_error_contains "${ROOT_DIR}/tests/cases/fail/duplicate_import_main.diva" "duplicate top-level declaration 'clash'"
assert_error_contains "${ROOT_DIR}/tests/cases/fail/package_mismatch_main.diva" "package mismatch:"
assert_error_contains "${ROOT_DIR}/tests/cases/fail/missing_trait_method.diva" "does not implement required method 'measure'"
assert_error_contains "${ROOT_DIR}/tests/cases/fail/unknown_package_dep" "unknown package dependency in import 'pkg/missing_lib'"

log "checking generated project workflow"
rm -rf "${TEST_ROOT}/generated-app"
if ! diva new "${TEST_ROOT}/generated-app" >"${TEST_ROOT}/new.out" 2>&1; then
    sed -n '1,120p' "${TEST_ROOT}/new.out" >&2
    fail "diva new failed"
fi

if ! [ -f "${TEST_ROOT}/generated-app/.gitignore" ]; then
    fail "generated project missing expected files"
fi

if ! [ -f "${TEST_ROOT}/generated-app/package.diva" ] || ! [ -f "${TEST_ROOT}/generated-app/src/main.diva" ]; then
    fail "generated app package missing manifest or src entry"
fi

if ! (
    cd "${TEST_ROOT}/generated-app" &&
    diva run . >"${TEST_ROOT}/generated.out" 2>&1
); then
    sed -n '1,120p' "${TEST_ROOT}/generated.out" >&2
    fail "generated project failed to run"
fi

generated_output=$(strip_di_logs "${TEST_ROOT}/generated.out")
if [ "${generated_output}" != "hello from diva10" ]; then
    printf '[test:error] unexpected generated project output\n' >&2
    printf '[test:error] actual:\n%s\n' "${generated_output}" >&2
    exit 1
fi

if ! (
    cd "${TEST_ROOT}/generated-app" &&
    diva check . >"${TEST_ROOT}/generated-check.out" 2>&1
); then
    sed -n '1,120p' "${TEST_ROOT}/generated-check.out" >&2
    fail "generated app package failed diva check"
fi

log "checking generated library workflow"
rm -rf "${TEST_ROOT}/generated-lib"
if ! diva new "${TEST_ROOT}/generated-lib" --lib >"${TEST_ROOT}/new-lib.out" 2>&1; then
    sed -n '1,120p' "${TEST_ROOT}/new-lib.out" >&2
    fail "diva new --lib failed"
fi

if ! [ -f "${TEST_ROOT}/generated-lib/package.diva" ] || ! [ -f "${TEST_ROOT}/generated-lib/src/lib.diva" ]; then
    fail "generated library package missing manifest or src entry"
fi

if ! (
    cd "${TEST_ROOT}/generated-lib" &&
    diva check . >"${TEST_ROOT}/generated-lib-check.out" 2>&1
); then
    sed -n '1,120p' "${TEST_ROOT}/generated-lib-check.out" >&2
    fail "generated library package failed diva check"
fi

if ! (
    cd "${TEST_ROOT}/generated-lib" &&
    diva emit-ir . >"${TEST_ROOT}/generated-lib-ir.out" 2>&1
); then
    sed -n '1,120p' "${TEST_ROOT}/generated-lib-ir.out" >&2
    fail "generated library package failed diva emit-ir"
fi

log "checking generated kernel workflow"
rm -rf "${TEST_ROOT}/generated-kernel"
if ! diva new "${TEST_ROOT}/generated-kernel" --kernel >"${TEST_ROOT}/new-kernel.out" 2>&1; then
    sed -n '1,120p' "${TEST_ROOT}/new-kernel.out" >&2
    fail "diva new --kernel failed"
fi

if ! [ -f "${TEST_ROOT}/generated-kernel/package.diva" ] || ! [ -f "${TEST_ROOT}/generated-kernel/src/boot.diva" ]; then
    fail "generated kernel package missing manifest or boot entry"
fi

if ! (
    cd "${TEST_ROOT}/generated-kernel" &&
    diva check . >"${TEST_ROOT}/generated-kernel-check.out" 2>&1
); then
    sed -n '1,120p' "${TEST_ROOT}/generated-kernel-check.out" >&2
    fail "generated kernel package failed diva check"
fi

if ! (
    cd "${TEST_ROOT}/generated-kernel" &&
    diva build . >"${TEST_ROOT}/generated-kernel-build.out" 2>&1
); then
    sed -n '1,120p' "${TEST_ROOT}/generated-kernel-build.out" >&2
    fail "generated kernel package failed diva build"
fi

log "checking kernel package workflow"
if ! diva check "${ROOT_DIR}/examples/kernel_demo" >"${TEST_ROOT}/kernel-check.out" 2>&1; then
    sed -n '1,120p' "${TEST_ROOT}/kernel-check.out" >&2
    fail "kernel package failed diva check"
fi

if ! diva emit-ir "${ROOT_DIR}/examples/kernel_demo" >"${TEST_ROOT}/kernel-ir.out" 2>&1; then
    sed -n '1,120p' "${TEST_ROOT}/kernel-ir.out" >&2
    fail "kernel package failed diva emit-ir"
fi

if ! diva build "${ROOT_DIR}/examples/kernel_demo" >"${TEST_ROOT}/kernel-build.out" 2>&1; then
    sed -n '1,120p' "${TEST_ROOT}/kernel-build.out" >&2
    fail "kernel package failed diva build"
fi

    log "all integration checks passed (${_stage})"
}

run_all_tests seed

log "checking self-host bootstrap (Diva compiler package forwards to seed)"
export DIVA_BOOTSTRAP="${ROOT_DIR}/bootstrap/diva-linux-amd64"
export DI_BOOTSTRAP="${ROOT_DIR}/bootstrap/diva-linux-amd64"
RUNTIME_O="${HOME_DIR}/.local/share/diva/runtime/runtime.o"
if ! [ -f "${RUNTIME_O}" ]; then
    fail "expected runtime object at ${RUNTIME_O}"
fi
BUILD_OUT="${TEST_ROOT}/compiler-selfhost-build.out"
if ! DI_STDLIB_DIR="${ROOT_DIR}/stdlib" DI_RUNTIME_O="${RUNTIME_O}" \
    "${ROOT_DIR}/bootstrap/diva-linux-amd64" build "${ROOT_DIR}/compiler" >"${BUILD_OUT}" 2>&1
then
    sed -n '1,120p' "${BUILD_OUT}" >&2
    fail "failed to build compiler/ (self-host driver) with seed"
fi
SELFHOST_EXE=$(sed -n 's/^\[native\] built executable at //p' "${BUILD_OUT}" | tail -n 1)
if [ -z "${SELFHOST_EXE}" ]; then
  SELFHOST_EXE=$(sed -n 's/^\[di\] built native executable at //p' "${BUILD_OUT}" | tail -n 1)
fi
if [ -z "${SELFHOST_EXE}" ] || ! [ -x "${SELFHOST_EXE}" ]; then
    printf '[test:error] could not resolve self-host executable from build output\n' >&2
    sed -n '1,80p' "${BUILD_OUT}" >&2
    exit 1
fi
cp "${SELFHOST_EXE}" "${BIN_DIR}/diva"
chmod +x "${BIN_DIR}/diva"
ln -sf diva "${BIN_DIR}/di" 2>/dev/null || true

run_all_tests selfhost

log "checking self-host convergence (stage3: compiler rebuilt with stage2 diva)"
BUILD3_OUT="${TEST_ROOT}/compiler-stage3-build.out"
if ! DI_STDLIB_DIR="${ROOT_DIR}/stdlib" DI_RUNTIME_O="${RUNTIME_O}" \
    "${BIN_DIR}/diva" build "${ROOT_DIR}/compiler" >"${BUILD3_OUT}" 2>&1
then
    sed -n '1,120p' "${BUILD3_OUT}" >&2
    fail "failed to build compiler/ with stage2 diva (stage3)"
fi
STAGE3_EXE=$(sed -n 's/^\[native\] built executable at //p' "${BUILD3_OUT}" | tail -n 1)
if [ -z "${STAGE3_EXE}" ]; then
  STAGE3_EXE=$(sed -n 's/^\[di\] built native executable at //p' "${BUILD3_OUT}" | tail -n 1)
fi
if [ -z "${STAGE3_EXE}" ] || ! [ -x "${STAGE3_EXE}" ]; then
    printf '[test:error] could not resolve stage3 executable from build output\n' >&2
    sed -n '1,80p' "${BUILD3_OUT}" >&2
    exit 1
fi
cp "${STAGE3_EXE}" "${BIN_DIR}/diva"
chmod +x "${BIN_DIR}/diva"
ln -sf diva "${BIN_DIR}/di" 2>/dev/null || true

run_all_tests selfhost_stage3

log "verifying NO_CLANG=1 install contract (scripts/verify-no-clang.sh)"
if ! NO_CLANG=1 sh "${ROOT_DIR}/scripts/verify-no-clang.sh" >"${TEST_ROOT}/no-clang-verify.out" 2>&1; then
    sed -n '1,120p' "${TEST_ROOT}/no-clang-verify.out" >&2
    fail "NO_CLANG verify failed"
fi

log "verifying no tracked C/C++ sources (scripts/verify-no-c-sources.sh)"
if ! sh "${ROOT_DIR}/scripts/verify-no-c-sources.sh" >"${TEST_ROOT}/no-c-sources-verify.out" 2>&1; then
    sed -n '1,80p' "${TEST_ROOT}/no-c-sources-verify.out" >&2
    fail "no-C-sources verify failed"
fi

log "all tests passed"

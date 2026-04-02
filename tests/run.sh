#!/usr/bin/env sh
set -eu

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
TEST_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/di-tests.XXXXXX")
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
    awk 'index($0, "[di] ") != 1 && index($0, "[di:error] ") != 1 { print }' "$1"
}

assert_output_equals() {
    file_path=$1
    expected=$2
    output_file="${TEST_ROOT}/command.out"

    if ! di run "${file_path}" >"${output_file}" 2>&1; then
        sed -n '1,120p' "${output_file}" >&2
        fail "command failed: di run ${file_path}"
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

    if ! di build "${file_path}" --ast >"${output_file}" 2>&1; then
        sed -n '1,120p' "${output_file}" >&2
        fail "command failed: di build ${file_path} --ast"
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

    if di build "${file_path}" >"${output_file}" 2>&1; then
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
    ir_path=

    if ! di emit-ir "${file_path}" >"${output_file}" 2>&1; then
        sed -n '1,120p' "${output_file}" >&2
        fail "command failed: di emit-ir ${file_path}"
    fi

    ir_path=$(sed -n 's/^\[di\] wrote LLVM IR to //p' "${output_file}" | tail -n 1)
    if [ -z "${ir_path}" ] || ! [ -f "${ir_path}" ]; then
        fail "expected LLVM IR output at ${ir_path}"
    fi

    if ! grep -F "${needle}" "${ir_path}" >/dev/null; then
        printf '[test:error] expected to find "%s" in IR for %s\n' "${needle}" "${file_path}" >&2
        sed -n '1,160p' "${ir_path}" >&2
        exit 1
    fi
}

log "installing di into temporary home"
HOME="${HOME_DIR}" sh "${ROOT_DIR}/scripts/install.sh" >"${TEST_ROOT}/install.out" 2>&1 || {
    sed -n '1,120p' "${TEST_ROOT}/install.out" >&2
    fail "install script failed"
}

HOME="${HOME_DIR}"
export HOME
PATH="${BIN_DIR}:${PATH}"
export PATH

log "checking compiler stub packages (mir, backend, frontend)"
for _pkg in mir backend frontend; do
    if ! di check "${ROOT_DIR}/compiler/${_pkg}" >"${TEST_ROOT}/check-${_pkg}.out" 2>&1; then
        sed -n '1,80p' "${TEST_ROOT}/check-${_pkg}.out" >&2
        fail "di check compiler/${_pkg} failed"
    fi
done

run_all_tests() {
    _stage=$1
    log "running integration tests (${_stage})"
assert_output_equals "${ROOT_DIR}/examples/hello.di" "10"
assert_output_equals "${ROOT_DIR}/examples/host_argv.di" "1"
assert_output_equals "${ROOT_DIR}/examples/vec_demo.di" "2
20
8
hello di"
assert_output_equals "${ROOT_DIR}/examples/branching.di" "running di
20
1"
assert_output_equals "${ROOT_DIR}/examples/loop.di" "10"
assert_output_equals "${ROOT_DIR}/examples/shadow.di" "99
5"
assert_output_equals "${ROOT_DIR}/examples/structs.di" "18
7"
assert_output_equals "${ROOT_DIR}/examples/struct_mutation.di" "10"
assert_output_equals "${ROOT_DIR}/examples/arrays.di" "9"
assert_output_equals "${ROOT_DIR}/examples/array_mutation.di" "16"
assert_output_equals "${ROOT_DIR}/examples/imports/main.di" "42"
assert_output_equals "${ROOT_DIR}/examples/generics_traits.di" "7"
assert_output_equals "${ROOT_DIR}/examples/stdlib_demo.di" "12
10
10
5
1
1"
assert_output_equals "${ROOT_DIR}/examples/systems_hosted.di" "systems io from di0x12"
assert_output_equals "${ROOT_DIR}/examples/packages/app_with_dep" "42"
assert_output_equals "${ROOT_DIR}/examples/utils_demo.di" "util-1
6
true
true
0x4
1
1"

log "checking AST smoke output"
assert_contains "${ROOT_DIR}/examples/hello.di" "Program"
assert_contains "${ROOT_DIR}/examples/hello.di" "Var(x: int)"
assert_contains "${ROOT_DIR}/examples/hello.di" "Ident(print_int)"

log "checking LLVM IR smoke output"
assert_ir_contains "${ROOT_DIR}/examples/loop.di" "br label %whilecond"
assert_ir_contains "${ROOT_DIR}/examples/arrays.di" "getelementptr inbounds [4 x i32]"
assert_ir_contains "${ROOT_DIR}/examples/array_mutation.di" "store i32"

log "checking semantic failure cases"
assert_error_contains "${ROOT_DIR}/tests/cases/fail/duplicate_decl.di" "duplicate declaration of 'x' in the same scope"
assert_error_contains "${ROOT_DIR}/tests/cases/fail/unknown_ident.di" "unknown identifier 'missing'"
assert_error_contains "${ROOT_DIR}/tests/cases/fail/reserved_name.di" "uses a reserved backend identifier"
assert_error_contains "${ROOT_DIR}/tests/cases/fail/duplicate_import_main.di" "duplicate top-level declaration 'clash'"
assert_error_contains "${ROOT_DIR}/tests/cases/fail/package_mismatch_main.di" "package mismatch:"
assert_error_contains "${ROOT_DIR}/tests/cases/fail/missing_trait_method.di" "does not implement required method 'measure'"
assert_error_contains "${ROOT_DIR}/tests/cases/fail/unknown_package_dep" "unknown package dependency in import 'pkg/missing_lib'"

log "checking generated project workflow"
rm -rf "${TEST_ROOT}/generated-app"
if ! di new "${TEST_ROOT}/generated-app" >"${TEST_ROOT}/new.out" 2>&1; then
    sed -n '1,120p' "${TEST_ROOT}/new.out" >&2
    fail "di new failed"
fi

if ! [ -f "${TEST_ROOT}/generated-app/.gitignore" ]; then
    fail "generated project missing expected files"
fi

if ! [ -f "${TEST_ROOT}/generated-app/di.mod" ] || ! [ -f "${TEST_ROOT}/generated-app/src/main.di" ]; then
    fail "generated app package missing manifest or src entry"
fi

if ! (
    cd "${TEST_ROOT}/generated-app" &&
    di run . >"${TEST_ROOT}/generated.out" 2>&1
); then
    sed -n '1,120p' "${TEST_ROOT}/generated.out" >&2
    fail "generated project failed to run"
fi

generated_output=$(strip_di_logs "${TEST_ROOT}/generated.out")
if [ "${generated_output}" != "hello from di10" ]; then
    printf '[test:error] unexpected generated project output\n' >&2
    printf '[test:error] actual:\n%s\n' "${generated_output}" >&2
    exit 1
fi

if ! (
    cd "${TEST_ROOT}/generated-app" &&
    di check . >"${TEST_ROOT}/generated-check.out" 2>&1
); then
    sed -n '1,120p' "${TEST_ROOT}/generated-check.out" >&2
    fail "generated app package failed di check"
fi

log "checking generated library workflow"
rm -rf "${TEST_ROOT}/generated-lib"
if ! di new "${TEST_ROOT}/generated-lib" --lib >"${TEST_ROOT}/new-lib.out" 2>&1; then
    sed -n '1,120p' "${TEST_ROOT}/new-lib.out" >&2
    fail "di new --lib failed"
fi

if ! [ -f "${TEST_ROOT}/generated-lib/di.mod" ] || ! [ -f "${TEST_ROOT}/generated-lib/src/lib.di" ]; then
    fail "generated library package missing manifest or src entry"
fi

if ! (
    cd "${TEST_ROOT}/generated-lib" &&
    di check . >"${TEST_ROOT}/generated-lib-check.out" 2>&1
); then
    sed -n '1,120p' "${TEST_ROOT}/generated-lib-check.out" >&2
    fail "generated library package failed di check"
fi

if ! (
    cd "${TEST_ROOT}/generated-lib" &&
    di emit-ir . >"${TEST_ROOT}/generated-lib-ir.out" 2>&1
); then
    sed -n '1,120p' "${TEST_ROOT}/generated-lib-ir.out" >&2
    fail "generated library package failed di emit-ir"
fi

log "checking generated kernel workflow"
rm -rf "${TEST_ROOT}/generated-kernel"
if ! di new "${TEST_ROOT}/generated-kernel" --kernel >"${TEST_ROOT}/new-kernel.out" 2>&1; then
    sed -n '1,120p' "${TEST_ROOT}/new-kernel.out" >&2
    fail "di new --kernel failed"
fi

if ! [ -f "${TEST_ROOT}/generated-kernel/di.mod" ] || ! [ -f "${TEST_ROOT}/generated-kernel/src/boot.di" ]; then
    fail "generated kernel package missing manifest or boot entry"
fi

if ! (
    cd "${TEST_ROOT}/generated-kernel" &&
    di check . >"${TEST_ROOT}/generated-kernel-check.out" 2>&1
); then
    sed -n '1,120p' "${TEST_ROOT}/generated-kernel-check.out" >&2
    fail "generated kernel package failed di check"
fi

if ! (
    cd "${TEST_ROOT}/generated-kernel" &&
    di build . >"${TEST_ROOT}/generated-kernel-build.out" 2>&1
); then
    sed -n '1,120p' "${TEST_ROOT}/generated-kernel-build.out" >&2
    fail "generated kernel package failed di build"
fi

log "checking kernel package workflow"
if ! di check "${ROOT_DIR}/examples/kernel_demo" >"${TEST_ROOT}/kernel-check.out" 2>&1; then
    sed -n '1,120p' "${TEST_ROOT}/kernel-check.out" >&2
    fail "kernel package failed di check"
fi

if ! di emit-ir "${ROOT_DIR}/examples/kernel_demo" >"${TEST_ROOT}/kernel-ir.out" 2>&1; then
    sed -n '1,120p' "${TEST_ROOT}/kernel-ir.out" >&2
    fail "kernel package failed di emit-ir"
fi

if ! di build "${ROOT_DIR}/examples/kernel_demo" >"${TEST_ROOT}/kernel-build.out" 2>&1; then
    sed -n '1,120p' "${TEST_ROOT}/kernel-build.out" >&2
    fail "kernel package failed di build"
fi

    log "all integration checks passed (${_stage})"
}

run_all_tests seed

log "checking self-host bootstrap (Di compiler package forwards to seed via DI_BOOTSTRAP)"
export DI_BOOTSTRAP="${ROOT_DIR}/bootstrap/di-linux-amd64"
RUNTIME_O="${HOME_DIR}/.local/share/di/runtime/runtime.o"
if ! [ -f "${RUNTIME_O}" ]; then
    fail "expected runtime object at ${RUNTIME_O}"
fi
BUILD_OUT="${TEST_ROOT}/compiler-selfhost-build.out"
if ! DI_STDLIB_DIR="${ROOT_DIR}/stdlib" DI_RUNTIME_O="${RUNTIME_O}" \
    "${ROOT_DIR}/bootstrap/di-linux-amd64" build "${ROOT_DIR}/compiler" >"${BUILD_OUT}" 2>&1
then
    sed -n '1,120p' "${BUILD_OUT}" >&2
    fail "failed to build compiler/ (self-host driver) with seed di"
fi
SELFHOST_EXE=$(sed -n 's/^\[di\] built native executable at //p' "${BUILD_OUT}" | tail -n 1)
if [ -z "${SELFHOST_EXE}" ] || ! [ -x "${SELFHOST_EXE}" ]; then
    printf '[test:error] could not resolve self-host executable from build output\n' >&2
    sed -n '1,80p' "${BUILD_OUT}" >&2
    exit 1
fi
cp "${SELFHOST_EXE}" "${BIN_DIR}/di"
chmod +x "${BIN_DIR}/di"

run_all_tests selfhost

log "checking self-host convergence (stage3: compiler rebuilt with stage2 di)"
BUILD3_OUT="${TEST_ROOT}/compiler-stage3-build.out"
if ! DI_STDLIB_DIR="${ROOT_DIR}/stdlib" DI_RUNTIME_O="${RUNTIME_O}" \
    "${BIN_DIR}/di" build "${ROOT_DIR}/compiler" >"${BUILD3_OUT}" 2>&1
then
    sed -n '1,120p' "${BUILD3_OUT}" >&2
    fail "failed to build compiler/ with stage2 di (stage3)"
fi
STAGE3_EXE=$(sed -n 's/^\[di\] built native executable at //p' "${BUILD3_OUT}" | tail -n 1)
if [ -z "${STAGE3_EXE}" ] || ! [ -x "${STAGE3_EXE}" ]; then
    printf '[test:error] could not resolve stage3 executable from build output\n' >&2
    sed -n '1,80p' "${BUILD3_OUT}" >&2
    exit 1
fi
cp "${STAGE3_EXE}" "${BIN_DIR}/di"
chmod +x "${BIN_DIR}/di"

run_all_tests selfhost_stage3

log "verifying NO_CLANG=1 install contract (scripts/verify-no-clang.sh)"
if ! NO_CLANG=1 sh "${ROOT_DIR}/scripts/verify-no-clang.sh" >"${TEST_ROOT}/no-clang-verify.out" 2>&1; then
    sed -n '1,120p' "${TEST_ROOT}/no-clang-verify.out" >&2
    fail "NO_CLANG verify failed"
fi

log "all tests passed"

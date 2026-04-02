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

PATH="${BIN_DIR}:${PATH}"
export HOME PATH

log "running example integration tests"
assert_output_equals "${ROOT_DIR}/examples/hello.di" "10"
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

log "checking generated project workflow"
rm -rf "${TEST_ROOT}/generated-app"
if ! di new "${TEST_ROOT}/generated-app" >"${TEST_ROOT}/new.out" 2>&1; then
    sed -n '1,120p' "${TEST_ROOT}/new.out" >&2
    fail "di new failed"
fi

if ! [ -f "${TEST_ROOT}/generated-app/main.di" ] || ! [ -f "${TEST_ROOT}/generated-app/.gitignore" ]; then
    fail "generated project missing expected files"
fi

if ! (
    cd "${TEST_ROOT}/generated-app" &&
    di run main.di >"${TEST_ROOT}/generated.out" 2>&1
); then
    sed -n '1,120p' "${TEST_ROOT}/generated.out" >&2
    fail "generated project failed to run"
fi

generated_output=$(strip_di_logs "${TEST_ROOT}/generated.out")
if [ "${generated_output}" != "hello from di
10" ]; then
    printf '[test:error] unexpected generated project output\n' >&2
    printf '[test:error] actual:\n%s\n' "${generated_output}" >&2
    exit 1
fi

log "all tests passed"

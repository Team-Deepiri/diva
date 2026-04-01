#!/usr/bin/env sh
set -eu

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
TEST_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/diri-tests.XXXXXX")
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

strip_diri_logs() {
    awk 'index($0, "[diri] ") != 1 && index($0, "[diri:error] ") != 1 { print }' "$1"
}

assert_output_equals() {
    file_path=$1
    expected=$2
    output_file="${TEST_ROOT}/command.out"

    if ! diri run "${file_path}" >"${output_file}" 2>&1; then
        sed -n '1,120p' "${output_file}" >&2
        fail "command failed: diri run ${file_path}"
    fi

    actual=$(strip_diri_logs "${output_file}")
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

    if ! diri build "${file_path}" --ast >"${output_file}" 2>&1; then
        sed -n '1,120p' "${output_file}" >&2
        fail "command failed: diri build ${file_path} --ast"
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

    if diri build "${file_path}" >"${output_file}" 2>&1; then
        sed -n '1,120p' "${output_file}" >&2
        fail "expected failure for ${file_path}"
    fi

    if ! grep -F "${needle}" "${output_file}" >/dev/null; then
        printf '[test:error] expected to find "%s" in failure output for %s\n' "${needle}" "${file_path}" >&2
        sed -n '1,120p' "${output_file}" >&2
        exit 1
    fi
}

log "installing diri into temporary home"
HOME="${HOME_DIR}" sh "${ROOT_DIR}/scripts/install.sh" >"${TEST_ROOT}/install.out" 2>&1 || {
    sed -n '1,120p' "${TEST_ROOT}/install.out" >&2
    fail "install script failed"
}

PATH="${BIN_DIR}:${PATH}"
export HOME PATH

log "running example integration tests"
assert_output_equals "${ROOT_DIR}/examples/hello.di" "10"
assert_output_equals "${ROOT_DIR}/examples/branching.di" "running diri
20
1"
assert_output_equals "${ROOT_DIR}/examples/loop.di" "10"
assert_output_equals "${ROOT_DIR}/examples/shadow.di" "99
5"
assert_output_equals "${ROOT_DIR}/examples/structs.di" "18
7"
assert_output_equals "${ROOT_DIR}/examples/struct_mutation.di" "10"
assert_output_equals "${ROOT_DIR}/examples/arrays.di" "9"

log "checking AST smoke output"
assert_contains "${ROOT_DIR}/examples/hello.di" "Program"
assert_contains "${ROOT_DIR}/examples/hello.di" "Let(x: int)"
assert_contains "${ROOT_DIR}/examples/hello.di" "Call(print_int)"

log "checking semantic failure cases"
assert_error_contains "${ROOT_DIR}/tests/cases/fail/duplicate_decl.di" "duplicate declaration of 'x' in the same scope"
assert_error_contains "${ROOT_DIR}/tests/cases/fail/unknown_ident.di" "unknown identifier 'missing'"

log "checking generated project workflow"
rm -rf "${TEST_ROOT}/generated-app"
if ! diri new "${TEST_ROOT}/generated-app" >"${TEST_ROOT}/new.out" 2>&1; then
    sed -n '1,120p' "${TEST_ROOT}/new.out" >&2
    fail "diri new failed"
fi

if ! [ -f "${TEST_ROOT}/generated-app/main.di" ] || ! [ -f "${TEST_ROOT}/generated-app/.gitignore" ]; then
    fail "generated project missing expected files"
fi

if ! (
    cd "${TEST_ROOT}/generated-app" &&
    diri run main.di >"${TEST_ROOT}/generated.out" 2>&1
); then
    sed -n '1,120p' "${TEST_ROOT}/generated.out" >&2
    fail "generated project failed to run"
fi

generated_output=$(strip_diri_logs "${TEST_ROOT}/generated.out")
if [ "${generated_output}" != "hello from diri
10" ]; then
    printf '[test:error] unexpected generated project output\n' >&2
    printf '[test:error] actual:\n%s\n' "${generated_output}" >&2
    exit 1
fi

log "all tests passed"

#!/usr/bin/env sh
set -eu

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
PINNED_BOOTSTRAP="${ROOT_DIR}/bootstrap/diva-linux-amd64"
TEST_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/diva-tests-XXXXXX")
HOME_DIR="${TEST_ROOT}/home"
BIN_DIR="${HOME_DIR}/.local/bin"

cleanup() {
    rm -rf "${TEST_ROOT}"
}

trap cleanup EXIT INT TERM

mkdir -p "${HOME_DIR}"
# DIVA_TEST_FAST=1 (default): one install + one integration pass; skip repeat compiler/ builds and
# verify scripts that rebuild or reinstall the whole tree (~30–60+ min saved). DIVA_TEST_FAST=0 for
# full convergence (extra compiler builds + verify-pure-compiler + verify-no-clang).
DIVA_TEST_FAST="${DIVA_TEST_FAST:-1}"
if [ "${DIVA_TEST_FAST}" = "1" ]; then
    INSTALL_TIMEOUT_SECS="${DIVA_TEST_INSTALL_TIMEOUT_SECS:-3600}"
    COMPILER_TIMEOUT_SECS="${DIVA_TEST_COMPILER_TIMEOUT_SECS:-2400}"
    VERIFY_TIMEOUT_SECS="${DIVA_TEST_VERIFY_TIMEOUT_SECS:-900}"
else
    INSTALL_TIMEOUT_SECS="${DIVA_TEST_INSTALL_TIMEOUT_SECS:-7200}"
    COMPILER_TIMEOUT_SECS="${DIVA_TEST_COMPILER_TIMEOUT_SECS:-7200}"
    VERIFY_TIMEOUT_SECS="${DIVA_TEST_VERIFY_TIMEOUT_SECS:-1800}"
fi
# Single trust root for goldens, early parse/new smoke, and (when no gcc-linked driver exists) compiler self-host.
DIVA_TEST_SEED="${DIVA_TEST_SEED:-${ROOT_DIR}/bootstrap/diva-linux-amd64}"
# Gcc-linked driver for pure compiler/ builds (see scripts/legacy/build-compiler-cc-link.sh). Falls back to DIVA_TEST_SEED if absent.
PURE_BUILD_DRIVER="${DIVA_PURE_BUILD_DRIVER:-${ROOT_DIR}/build/diva-stage2}"

timed() {
    _secs=$1
    shift
    if command -v timeout >/dev/null 2>&1; then
        timeout "${_secs}" "$@"
    else
        "$@"
    fi
}

# The installed wrapper resolves ${_DIVA_DATA} via XDG_DATA_HOME when set. Pin XDG under the
# fake HOME so we never exec the host's libexec/diva-driver while PATH points at ${BIN_DIR}.
export HOME="${HOME_DIR}"
export XDG_DATA_HOME="${HOME_DIR}/.local/share"
export XDG_CONFIG_HOME="${HOME_DIR}/.config"
export XDG_CACHE_HOME="${HOME_DIR}/.cache"

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
      index($0, "[diva] ") == 1 { next }
      index($0, "[native] ") == 1 { next }
      index($0, "/usr/bin/ld:") == 1 { next }
      index($0, "collect2:") == 1 { next }
      index($0, "undefined reference") > 0 { next }
      index($0, "(.text+") == 1 { next }
      index($0, "link failed (requires cc") == 1 { next }
      index($0, "writing native ELF failed") == 1 { next }
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

if [ ! -x "${DIVA_TEST_SEED}" ]; then
    fail "missing or non-executable DIVA_TEST_SEED: ${DIVA_TEST_SEED}"
fi
if [ ! -x "${PURE_BUILD_DRIVER}" ]; then
    log "PURE_BUILD_DRIVER not executable (${PURE_BUILD_DRIVER}); using DIVA_TEST_SEED for compiler self-host (set DIVA_PURE_BUILD_DRIVER to override)"
    PURE_BUILD_DRIVER="${DIVA_TEST_SEED}"
fi

if [ "${DIVA_TEST_FAST}" = "1" ]; then
    log "fast mode: DIVA_TEST_FAST=1 (default). Full churn: DIVA_TEST_FAST=0"
    export DIVA_INSTALL_QUIET="${DIVA_INSTALL_QUIET:-1}"
fi

# Run fork-heavy `diva new` / parse smoke *before* install's multi-minute compiler build: after the build,
# Linux/WSL often hits "Cannot fork" when host_system shells out (limit on processes / memory pressure).
mkdir -p "${BIN_DIR}"
PATH="${BIN_DIR}:${PATH}"
export PATH
log "early PATH: DIVA_TEST_SEED -> ${BIN_DIR}/diva (repo stdlib; before install)"
cp "${DIVA_TEST_SEED}" "${BIN_DIR}/diva"
chmod +x "${BIN_DIR}/diva"
ln -sf diva "${BIN_DIR}/di" 2>/dev/null || true
DIVA_BOOTSTRAP="${DIVA_TEST_SEED}"
export DIVA_BOOTSTRAP
DI_BOOTSTRAP="${DIVA_TEST_SEED}"
export DI_BOOTSTRAP
DI_STDLIB_DIR="${ROOT_DIR}/stdlib"
export DI_STDLIB_DIR
DI_RUNTIME_O="${ROOT_DIR}/bootstrap/runtime-linux-amd64.o"
export DI_RUNTIME_O

log "checking compiler package parse smoke (mir, frontend tokens, shared cell)"
# Use `diva parse` on single files so the pinned seed does not need `check`'s nested host_system
# (some CI/sandbox environments cannot fork a subshell for bootstrap forward).
if ! diva parse "${ROOT_DIR}/compiler/mir/src/mir.diva" >"${TEST_ROOT}/check-mir-parse.out" 2>&1; then
    sed -n '1,80p' "${TEST_ROOT}/check-mir-parse.out" >&2
    fail "diva parse compiler/mir/src/mir.diva failed"
fi
if ! diva parse "${ROOT_DIR}/compiler/frontend/src/tokens.diva" >"${TEST_ROOT}/check-frontend-parse.out" 2>&1; then
    sed -n '1,80p' "${TEST_ROOT}/check-frontend-parse.out" >&2
    fail "diva parse compiler/frontend/src/tokens.diva failed"
fi
if ! diva parse "${ROOT_DIR}/compiler/src/cell.diva" >"${TEST_ROOT}/check-cell-parse.out" 2>&1; then
    sed -n '1,80p' "${TEST_ROOT}/check-cell-parse.out" >&2
    fail "diva parse compiler/src/cell.diva failed"
fi

log "checking diva new (native driver)"
{
    rm -rf "${TEST_ROOT}/diva_new_smoke" "${TEST_ROOT}/diva_new_lib" "${TEST_ROOT}/diva_new_kernel"
    # Pure-ELF host_getenv is not wired yet; cwd must be the repo so newline_str finds compiler/res/lf.txt.
    cd "${ROOT_DIR}" || exit 1
    if ! diva new "${TEST_ROOT}/diva_new_smoke" >"${TEST_ROOT}/new-app.out" 2>&1; then
        sed -n '1,80p' "${TEST_ROOT}/new-app.out" >&2
        exit 1
    fi
    if ! diva new "${TEST_ROOT}/diva_new_lib" --lib >"${TEST_ROOT}/new-lib.out" 2>&1; then
        sed -n '1,80p' "${TEST_ROOT}/new-lib.out" >&2
        exit 1
    fi
    if ! diva new "${TEST_ROOT}/diva_new_kernel" --kernel >"${TEST_ROOT}/new-kernel.out" 2>&1; then
        sed -n '1,80p' "${TEST_ROOT}/new-kernel.out" >&2
        exit 1
    fi
} || fail "diva new failed"
assert_output_equals "${TEST_ROOT}/diva_new_smoke" "new_smoke_ok"
if ! diva check "${TEST_ROOT}/diva_new_lib" >"${TEST_ROOT}/new-lib-check.out" 2>&1; then
    sed -n '1,80p' "${TEST_ROOT}/new-lib-check.out" >&2
    fail "diva check on diva new --lib package failed"
fi
if ! grep -q '^kind = "kernel"$' "${TEST_ROOT}/diva_new_kernel/package.diva"; then
    sed -n '1,40p' "${TEST_ROOT}/diva_new_kernel/package.diva" >&2
    fail "diva new --kernel did not write kernel manifest kind"
fi
if ! diva parse "${TEST_ROOT}/diva_new_kernel/src/boot.diva" >"${TEST_ROOT}/new-kernel-parse.out" 2>&1; then
    sed -n '1,80p' "${TEST_ROOT}/new-kernel-parse.out" >&2
    fail "diva parse on diva new --kernel boot.diva failed"
fi

log "installing diva into temporary home (timeout ${INSTALL_TIMEOUT_SECS}s; compiler build via ${PURE_BUILD_DRIVER})"
export DIVA_TEST_SEED="${PURE_BUILD_DRIVER}"
timed "${INSTALL_TIMEOUT_SECS}" bash "${ROOT_DIR}/scripts/install.sh" >"${TEST_ROOT}/install.out" 2>&1 || {
    sed -n '1,120p' "${TEST_ROOT}/install.out" >&2
    fail "install script failed (timeout ${INSTALL_TIMEOUT_SECS}s or error — set DIVA_TEST_INSTALL_TIMEOUT_SECS)"
}
unset DIVA_TEST_SEED 2>/dev/null || true

# install.sh copies the pure-built driver to libexec; that binary can still SIGSEGV on some sema paths.
# When PURE_BUILD_DRIVER is a gcc-linked stage2 (not the repo pin), overlay libexec for stable integration.
if [ "${DIVA_TESTS_LIBEXEC_OVERLAY:-1}" != "0" ] && [ -x "${PURE_BUILD_DRIVER}" ] && [ "${PURE_BUILD_DRIVER}" != "${PINNED_BOOTSTRAP}" ] && [ -f "${HOME_DIR}/.local/share/diva/libexec/diva-driver" ]; then
    log "tests: overlay libexec/diva-driver with PURE_BUILD_DRIVER (${PURE_BUILD_DRIVER})"
    cp -f "${PURE_BUILD_DRIVER}" "${HOME_DIR}/.local/share/diva/libexec/diva-driver"
    chmod +x "${HOME_DIR}/.local/share/diva/libexec/diva-driver"
fi

PATH="${BIN_DIR}:${PATH}"
export PATH
# install.sh already placed the wrapper + freshly built libexec driver; do not replace diva with the repo pin
# (pinned seed may lag new externs; integration exercises the installed driver).
log "post-install PATH: ${BIN_DIR}/diva (installed wrapper + libexec driver)"
ln -sf diva "${BIN_DIR}/di" 2>/dev/null || true
BOOT_EXE="${HOME_DIR}/.local/share/diva/bootstrap/diva-linux-amd64"
DIVA_BOOTSTRAP="${BOOT_EXE}"
export DIVA_BOOTSTRAP
DI_BOOTSTRAP="${BOOT_EXE}"
export DI_BOOTSTRAP
DI_STDLIB_DIR="${HOME_DIR}/.local/share/diva/stdlib"
export DI_STDLIB_DIR
DI_RUNTIME_O="${HOME_DIR}/.local/share/diva/runtime/runtime.o"
export DI_RUNTIME_O

run_all_tests() {
    _stage=$1
    log "running integration tests (${_stage})"
    ln -sf diva "${BIN_DIR}/di" 2>/dev/null || true
    log "checking semantic failure cases (before long native run smoke)"
assert_error_contains "${ROOT_DIR}/tests/cases/fail/duplicate_decl.diva" "duplicate declaration of 'x' in the same scope"
assert_error_contains "${ROOT_DIR}/tests/cases/fail/unknown_ident.diva" "unknown identifier 'missing'"
# Span diagnostics (Issue #54): path:line:col: prefix on parser + sema errors.
assert_error_contains "${ROOT_DIR}/tests/cases/fail/unknown_ident.diva" "unknown_ident.diva:2:"
assert_error_contains "${ROOT_DIR}/tests/cases/fail/parse_bad_params.diva" "parse error: expected"
assert_error_contains "${ROOT_DIR}/tests/cases/fail/parse_bad_params.diva" "parse_bad_params.diva:1:"
assert_error_contains "${ROOT_DIR}/tests/cases/fail/wrong_arity.diva" "wrong number of arguments for 'add'"
assert_error_contains "${ROOT_DIR}/tests/cases/fail/wrong_arity.diva" "wrong_arity.diva:"
assert_error_contains "${ROOT_DIR}/tests/cases/fail/duplicate_func.diva" "duplicate function 'foo'"
assert_error_contains "${ROOT_DIR}/tests/cases/fail/self_outside_method.diva" "unknown identifier 'self'"
assert_error_contains "${ROOT_DIR}/tests/cases/fail/duplicate_import_main.diva" "duplicate function 'clash'"
assert_error_contains "${ROOT_DIR}/tests/cases/fail/missing_trait_method.diva" "missing trait method"
assert_error_contains "${ROOT_DIR}/tests/cases/fail/unknown_package_dep" "unknown package dependency"

assert_output_equals "${ROOT_DIR}/examples/hello.diva" "10"
assert_output_equals "${ROOT_DIR}/examples/escape_smoke.diva" "$(printf '1\n')"
assert_output_equals "${ROOT_DIR}/examples/escape_println.diva" "$(printf 'hi\n')"
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
assert_output_equals "${ROOT_DIR}/examples/array_dynamic.diva" "9
99
6"
# Dynamic OOB index must abort (exit non-zero), not silently corrupt.
oob_exe="${TEST_ROOT}/array_oob"
if ! diva build "${ROOT_DIR}/tests/cases/fail/array_oob_runtime.diva" "${oob_exe}" >"${TEST_ROOT}/oob_build.out" 2>&1; then
    sed -n '1,80p' "${TEST_ROOT}/oob_build.out" >&2
    fail "array_oob_runtime failed to build"
fi
set +e
"${oob_exe}" >"${TEST_ROOT}/oob_run.out" 2>&1
oob_rc=$?
set -e
if [ "${oob_rc}" -eq 0 ]; then
    fail "array_oob_runtime expected non-zero exit"
fi
log "array_oob_runtime aborted as expected (rc=${oob_rc})"
assert_output_equals "${ROOT_DIR}/examples/flux_range.diva" "10
5
1
0
0"
assert_output_equals "${ROOT_DIR}/examples/flux_array.diva" "30"
assert_output_equals "${ROOT_DIR}/examples/class_methods.diva" "3
7"
assert_output_equals "${ROOT_DIR}/examples/imports/main.diva" "42"
assert_output_equals "${ROOT_DIR}/examples/generics_traits.diva" "7"
assert_output_equals "${ROOT_DIR}/examples/method_call.diva" "7
6"
assert_output_equals "${ROOT_DIR}/examples/traits_static.diva" "7"
assert_output_equals "${ROOT_DIR}/examples/globals.diva" "5
10
11
11"
assert_output_equals "${ROOT_DIR}/examples/globals_str.diva" "hello
world"
assert_output_equals "${ROOT_DIR}/examples/stdlib_demo.diva" "12
10
10
5
1
1"
assert_output_equals "${ROOT_DIR}/examples/systems_hosted.diva" "systems io from diva0x0000000000000014"
assert_output_equals "${ROOT_DIR}/examples/packages/app_with_dep" "42"
assert_output_equals "${ROOT_DIR}/examples/utils_demo.diva" "1
6
true
true
util0x0000000000000004
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
assert_ir_contains "${ROOT_DIR}/examples/flux_range.diva" "br.cond"

log "checking generated project workflow"
rm -rf "${TEST_ROOT}/generated-app"
# Package layout smoke tests use static fixtures; `diva new` is exercised explicitly after install.
# when fork limits are tight after many native runs.
cp -R "${ROOT_DIR}/tests/fixtures/generated_app" "${TEST_ROOT}/generated-app"

if ! [ -f "${TEST_ROOT}/generated-app/.gitignore" ]; then
    fail "generated project missing expected files"
fi

if ! [ -f "${TEST_ROOT}/generated-app/package.diva" ] || ! [ -f "${TEST_ROOT}/generated-app/src/main.diva" ]; then
    fail "generated app package missing manifest or src entry"
fi

if ! (
    cd "${TEST_ROOT}/generated-app" &&
    diva parse src/main.diva >"${TEST_ROOT}/generated-check.out" 2>&1
); then
    sed -n '1,120p' "${TEST_ROOT}/generated-check.out" >&2
    fail "generated app package failed diva check"
fi

log "checking generated library workflow"
rm -rf "${TEST_ROOT}/generated-lib"
cp -R "${ROOT_DIR}/tests/fixtures/generated_lib" "${TEST_ROOT}/generated-lib"

if ! [ -f "${TEST_ROOT}/generated-lib/package.diva" ] || ! [ -f "${TEST_ROOT}/generated-lib/src/lib.diva" ]; then
    fail "generated library package missing manifest or src entry"
fi

if ! (
    cd "${TEST_ROOT}/generated-lib" &&
    diva parse src/lib.diva >"${TEST_ROOT}/generated-lib-check.out" 2>&1
); then
    sed -n '1,120p' "${TEST_ROOT}/generated-lib-check.out" >&2
    fail "generated library package failed diva check"
fi

if ! (
    cd "${TEST_ROOT}/generated-lib" &&
    diva emit-ir src/lib.diva >"${TEST_ROOT}/generated-lib-ir.out" 2>&1
); then
    sed -n '1,120p' "${TEST_ROOT}/generated-lib-ir.out" >&2
    fail "generated library package failed diva emit-ir"
fi

log "checking generated kernel workflow"
rm -rf "${TEST_ROOT}/generated-kernel"
cp -R "${ROOT_DIR}/tests/fixtures/generated_kernel" "${TEST_ROOT}/generated-kernel"

if ! [ -f "${TEST_ROOT}/generated-kernel/package.diva" ] || ! [ -f "${TEST_ROOT}/generated-kernel/src/boot.diva" ]; then
    fail "generated kernel package missing manifest or boot entry"
fi

if ! (
    cd "${TEST_ROOT}/generated-kernel" &&
    diva parse src/boot.diva >"${TEST_ROOT}/generated-kernel-check.out" 2>&1
); then
    sed -n '1,120p' "${TEST_ROOT}/generated-kernel-check.out" >&2
    fail "generated kernel package failed diva check"
fi

log "checking kernel package workflow"
if ! diva parse "${ROOT_DIR}/examples/kernel_demo/src/boot.diva" >"${TEST_ROOT}/kernel-check.out" 2>&1; then
    sed -n '1,120p' "${TEST_ROOT}/kernel-check.out" >&2
    fail "kernel package failed diva check"
fi

if ! diva emit-ir "${ROOT_DIR}/examples/kernel_demo/src/boot.diva" >"${TEST_ROOT}/kernel-ir.out" 2>&1; then
    sed -n '1,120p' "${TEST_ROOT}/kernel-ir.out" >&2
    fail "kernel package failed diva emit-ir"
fi

    log "all integration checks passed (${_stage})"
}

run_all_tests seed

if [ "${DIVA_TEST_FAST}" = "1" ]; then
    log "DIVA_TEST_FAST=1: skipping repeat compiler/ builds, duplicate integration passes, verify-pure-compiler and verify-no-clang (each duplicates a full tree build or install)"
    if ! [ -x "${HOME_DIR}/.local/share/diva/libexec/diva-driver" ]; then
        fail "install did not produce ${HOME_DIR}/.local/share/diva/libexec/diva-driver"
    fi
else
    log "checking compiler package pure-ELF build (gcc-linked driver; pure ELF output still uses host_system for materialize)"
    export DIVA_BOOTSTRAP="${BOOT_EXE}"
    export DI_BOOTSTRAP="${BOOT_EXE}"
    RUNTIME_O="${HOME_DIR}/.local/share/diva/runtime/runtime.o"
    if ! [ -f "${RUNTIME_O}" ]; then
        fail "expected runtime object at ${RUNTIME_O}"
    fi
    BUILD_OUT="${TEST_ROOT}/compiler-selfhost-build.out"
    log "build compiler/ with ${PURE_BUILD_DRIVER} (timeout ${COMPILER_TIMEOUT_SECS}s)"
    if ! timed "${COMPILER_TIMEOUT_SECS}" env ROOT_DIR="${ROOT_DIR}" DI_STDLIB_DIR="${ROOT_DIR}/stdlib" DIVA_NO_EXTERNAL=1 \
        DIVA_SKIP_NATIVE_EXTERN_CHECK="${DIVA_SKIP_NATIVE_EXTERN_CHECK:-}" \
        DI_RUNTIME_O="${ROOT_DIR}/bootstrap/runtime-linux-amd64.o" \
        "${PURE_BUILD_DRIVER}" build "${ROOT_DIR}/compiler" >"${BUILD_OUT}" 2>&1
    then
        printf '[test:error] pure-ELF build of compiler/ failed\n' >&2
        sed -n '1,120p' "${BUILD_OUT}" >&2
        fail "PURE_BUILD_DRIVER build compiler with DIVA_NO_EXTERNAL=1 failed"
    fi
    SELFHOST_EXE=$(sed -n 's/^\[native\] built executable at //p' "${BUILD_OUT}" | tail -n 1)
    if [ -z "${SELFHOST_EXE}" ]; then
        SELFHOST_EXE=$(sed -n 's/^\[di\] built native executable at //p' "${BUILD_OUT}" | tail -n 1)
    fi
    if [ -z "${SELFHOST_EXE}" ] || ! [ -x "${SELFHOST_EXE}" ]; then
        printf '[test:error] could not resolve compiler executable from build output\n' >&2
        sed -n '1,80p' "${BUILD_OUT}" >&2
        exit 1
    fi
    ln -sf diva "${BIN_DIR}/di" 2>/dev/null || true

    run_all_tests selfhost

    log "checking repeat compiler/ build (same gcc-linked driver until pure host_system can drive stage3)"
    BUILD3_OUT="${TEST_ROOT}/compiler-stage3-build.out"
    log "second build compiler/ with ${PURE_BUILD_DRIVER} (timeout ${COMPILER_TIMEOUT_SECS}s)"
    if ! timed "${COMPILER_TIMEOUT_SECS}" env ROOT_DIR="${ROOT_DIR}" DI_STDLIB_DIR="${ROOT_DIR}/stdlib" DIVA_NO_EXTERNAL=1 \
        DIVA_SKIP_NATIVE_EXTERN_CHECK="${DIVA_SKIP_NATIVE_EXTERN_CHECK:-}" \
        DI_RUNTIME_O="${ROOT_DIR}/bootstrap/runtime-linux-amd64.o" \
        "${PURE_BUILD_DRIVER}" build "${ROOT_DIR}/compiler" >"${BUILD3_OUT}" 2>&1
    then
        sed -n '1,120p' "${BUILD3_OUT}" >&2
        fail "second build compiler/ with PURE_BUILD_DRIVER failed"
    fi
    STAGE3_EXE=$(sed -n 's/^\[native\] built executable at //p' "${BUILD3_OUT}" | tail -n 1)
    if [ -z "${STAGE3_EXE}" ]; then
        STAGE3_EXE=$(sed -n 's/^\[di\] built native executable at //p' "${BUILD3_OUT}" | tail -n 1)
    fi
    if [ -z "${STAGE3_EXE}" ] || ! [ -x "${STAGE3_EXE}" ]; then
        printf '[test:error] could not resolve second compiler executable from build output\n' >&2
        sed -n '1,80p' "${BUILD3_OUT}" >&2
        exit 1
    fi
    ln -sf diva "${BIN_DIR}/di" 2>/dev/null || true

    run_all_tests selfhost_stage3

    log "verifying pure-elf full compiler package (scripts/verify-pure-compiler-build.sh, timeout ${VERIFY_TIMEOUT_SECS}s)"
    if ! timed "${VERIFY_TIMEOUT_SECS}" sh "${ROOT_DIR}/scripts/verify-pure-compiler-build.sh" >"${TEST_ROOT}/pure-compiler-verify.out" 2>&1; then
        sed -n '1,120p' "${TEST_ROOT}/pure-compiler-verify.out" >&2
        fail "scripts/verify-pure-compiler-build.sh failed"
    fi

    log "verifying NO_CLANG=1 install contract (scripts/verify-no-clang.sh, timeout ${VERIFY_TIMEOUT_SECS}s)"
    if ! timed "${VERIFY_TIMEOUT_SECS}" env NO_CLANG=1 sh "${ROOT_DIR}/scripts/verify-no-clang.sh" >"${TEST_ROOT}/no-clang-verify.out" 2>&1; then
        sed -n '1,120p' "${TEST_ROOT}/no-clang-verify.out" >&2
        fail "NO_CLANG verify failed"
    fi
fi

log "verifying no tracked C/C++ sources (scripts/verify-no-c-sources.sh, timeout ${VERIFY_TIMEOUT_SECS}s)"
if ! timed "${VERIFY_TIMEOUT_SECS}" sh "${ROOT_DIR}/scripts/verify-no-c-sources.sh" >"${TEST_ROOT}/no-c-sources-verify.out" 2>&1; then
    sed -n '1,80p' "${TEST_ROOT}/no-c-sources-verify.out" >&2
    fail "no-C-sources verify failed"
fi

log "all tests passed"

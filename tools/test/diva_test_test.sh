#!/usr/bin/env sh
# Integration test for the Diva test runner (tools/test/diva_test.diva, #137).
#
# Builds the runner, drives it against generated fixtures (passing, failing,
# nested, `test_*`-named, and a non-test file) plus the checked-in example
# tests, and asserts discovery, --list, --filter, summary counts and exit codes.
#
# Prints `[diva-test] total=N failed=M` and exits nonzero if any check failed.
# Run from anywhere: sh tools/test/diva_test_test.sh
set -u

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd) || exit 1
cd "$ROOT_DIR" || exit 1

DRIVER="${DIVA_TEST_DRIVER:-$ROOT_DIR/build/diva-compiler-pure-elf}"

export DI_STDLIB_DIR="$ROOT_DIR/stdlib"
export DIVA_NO_EXTERNAL=1
export DI_RUNTIME_O="$ROOT_DIR/bootstrap/runtime-linux-amd64.o"

WORK=$(mktemp -d "${TMPDIR:-/tmp}/diva-test-it-XXXXXX") || exit 1
cleanup() { rm -rf "$WORK"; }
trap cleanup EXIT INT TERM

TOTAL=0
FAILED=0

ok()  { TOTAL=$((TOTAL + 1)); printf '[diva-test] ok   %s\n' "$1"; }
bad() { TOTAL=$((TOTAL + 1)); FAILED=$((FAILED + 1)); printf '[diva-test] FAIL %s\n' "$1"; }

assert_exit() { # <desc> <expected> <actual>
    if [ "$2" = "$3" ]; then ok "$1"; else bad "$1 (expected exit $2, got $3)"; fi
}
assert_eq() { # <desc> <expected> <actual>
    if [ "$2" = "$3" ]; then ok "$1"; else bad "$1 (expected [$2], got [$3])"; fi
}
assert_contains() { # <desc> <haystack> <needle>
    case "$2" in
        *"$3"*) ok "$1" ;;
        *) bad "$1 (missing [$3])" ;;
    esac
}
assert_not_contains() { # <desc> <haystack> <needle>
    case "$2" in
        *"$3"*) bad "$1 (unexpectedly present [$3])" ;;
        *) ok "$1" ;;
    esac
}
count_lines() { printf '%s\n' "$1" | grep -c .; }

# ---------------------------------------------------------------------------
# Build the runner.
# ---------------------------------------------------------------------------
RUNNER="$WORK/diva_test"
if "$DRIVER" build "$ROOT_DIR/tools/test/diva_test.diva" "$RUNNER" >"$WORK/runner-build.log" 2>&1; then
    ok "build test runner"
else
    bad "build test runner"
    sed -n '1,120p' "$WORK/runner-build.log" >&2
fi

if [ ! -x "$RUNNER" ]; then
    printf '\n[diva-test] total=%s failed=%s\n' "$TOTAL" "$FAILED"
    exit 1
fi

# ---------------------------------------------------------------------------
# Fixtures.
# ---------------------------------------------------------------------------
FIX="$WORK/fixtures"
mkdir -p "$FIX/sub"

cat > "$FIX/alpha_test.diva" <<'DIVA'
import "std/io.diva"
import "std/testing.diva"

func main(): int {
    test_begin("two plus two")
    assert_eq_int(2 + 2, 4, "2+2 should be 4")
    test_ok()
    return test_summary()
}
DIVA

cat > "$FIX/gamma_test.diva" <<'DIVA'
import "std/io.diva"
import "std/testing.diva"

func main(): int {
    test_begin("intentional failure")
    assert_eq_int(1, 2, "one is not two")
    test_ok()
    return test_summary()
}
DIVA

cat > "$FIX/test_prefix_ok.diva" <<'DIVA'
import "std/io.diva"
import "std/testing.diva"

func main(): int {
    test_begin("test_ prefix naming")
    assert_eq_str("diva", "diva", "equal")
    test_ok()
    return test_summary()
}
DIVA

cat > "$FIX/sub/nested_test.diva" <<'DIVA'
import "std/io.diva"
import "std/testing.diva"

func main(): int {
    test_begin("nested discovery")
    assert_true(1, "always true")
    test_ok()
    return test_summary()
}
DIVA

# Deliberately not valid Diva and matching neither discovery pattern: if the
# runner ever tried to build it, the run would fail, so its absence from
# --list and from the summary is meaningful.
printf 'this file is not diva and must not be discovered\n' > "$FIX/helper.diva"

# A valid test with a non-matching name, passed explicitly as a file argument.
cat > "$WORK/direct.diva" <<'DIVA'
import "std/io.diva"
import "std/testing.diva"

func main(): int {
    test_begin("explicit file argument")
    assert_eq_int(6 * 7, 42, "6*7")
    test_ok()
    return test_summary()
}
DIVA

# ---------------------------------------------------------------------------
# Discovery: --list.
# ---------------------------------------------------------------------------
list_out=$("$RUNNER" --list "$FIX" 2>"$WORK/list.err")
rc=$?
assert_exit "--list exits 0" 0 "$rc"
assert_eq "--list finds 4 files (both patterns, recursive)" 4 "$(count_lines "$list_out")"
assert_contains "--list includes alpha_test.diva" "$list_out" "alpha_test.diva"
assert_contains "--list includes gamma_test.diva" "$list_out" "gamma_test.diva"
assert_contains "--list includes test_prefix_ok.diva (*_test and test_*)" "$list_out" "test_prefix_ok.diva"
assert_contains "--list recurses into sub/nested_test.diva" "$list_out" "sub/nested_test.diva"
assert_not_contains "--list ignores non-test helper.diva" "$list_out" "helper.diva"

filter_out=$("$RUNNER" --list --filter sub "$FIX" 2>/dev/null)
rc=$?
assert_exit "--list --filter exits 0" 0 "$rc"
assert_eq "--filter narrows discovery to 1 file" 1 "$(count_lines "$filter_out")"
assert_contains "--filter selects sub/nested_test.diva" "$filter_out" "nested_test.diva"

# ---------------------------------------------------------------------------
# Running: one failing file makes the run nonzero.
# ---------------------------------------------------------------------------
run_all=$("$RUNNER" "$FIX" 2>"$WORK/run-all.err")
rc=$?
assert_exit "run with a failing test exits nonzero" 1 "$rc"
assert_contains "run-all reports OK for alpha_test.diva" "$run_all" "OK $FIX/alpha_test.diva"
assert_contains "run-all reports FAIL for gamma_test.diva" "$run_all" "FAIL $FIX/gamma_test.diva"
assert_contains "run-all summary counts" "$run_all" "3 passed, 1 failed, 4 files"

# ---------------------------------------------------------------------------
# Running: only passing files exits 0.
# ---------------------------------------------------------------------------
run_pass=$("$RUNNER" \
    "$FIX/alpha_test.diva" "$FIX/test_prefix_ok.diva" "$FIX/sub/nested_test.diva" 2>/dev/null)
rc=$?
assert_exit "all-passing run exits 0" 0 "$rc"
assert_contains "all-passing summary counts" "$run_pass" "3 passed, 0 failed, 3 files"

# ---------------------------------------------------------------------------
# Explicit file argument with a non-matching name still runs.
# ---------------------------------------------------------------------------
direct_out=$("$RUNNER" "$WORK/direct.diva" 2>/dev/null)
rc=$?
assert_exit "explicit file argument runs (non-matching name)" 0 "$rc"
assert_contains "explicit file summary" "$direct_out" "1 passed, 0 failed, 1 files"

# ---------------------------------------------------------------------------
# --driver flag and the checked-in examples.
# ---------------------------------------------------------------------------
driver_out=$("$RUNNER" --driver "$DRIVER" "$FIX/alpha_test.diva" 2>/dev/null)
rc=$?
assert_exit "--driver flag accepted" 0 "$rc"
assert_contains "--driver run summary" "$driver_out" "1 passed, 0 failed, 1 files"

examples_out=$("$RUNNER" "$ROOT_DIR/tools/test/examples" 2>"$WORK/examples.err")
rc=$?
assert_exit "example tests exit 0" 0 "$rc"
assert_contains "example tests summary" "$examples_out" "3 passed, 0 failed, 3 files"

# ---------------------------------------------------------------------------
# Missing path is a usage error.
# ---------------------------------------------------------------------------
"$RUNNER" "$WORK/does-not-exist.diva" >/dev/null 2>&1
assert_exit "missing path exits 2" 2 "$?"

# ---------------------------------------------------------------------------
# A discovered file that fails to build is reported as FAIL (build exit).
# ---------------------------------------------------------------------------
mkdir -p "$WORK/broken"
printf 'this is not valid diva at all\n' > "$WORK/broken/broken_test.diva"
broken_out=$("$RUNNER" "$WORK/broken" 2>"$WORK/broken.err")
rc=$?
assert_exit "build failure exits nonzero" 1 "$rc"
assert_contains "build failure reported as FAIL" "$broken_out" "FAIL $WORK/broken/broken_test.diva"
assert_contains "build failure summary counts" "$broken_out" "0 passed, 1 failed, 1 files"

# ---------------------------------------------------------------------------
# Result.
# ---------------------------------------------------------------------------
printf '\n[diva-test] total=%s failed=%s\n' "$TOTAL" "$FAILED"
if [ "$FAILED" -gt 0 ]; then
    exit 1
fi
exit 0

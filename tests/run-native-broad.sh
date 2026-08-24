#!/usr/bin/env sh
# Broad native single-file + package gate: builds and runs every examples/*.diva,
# checks goldens for the documented subset, builds+runs the imports/ and packages/
# multi-file demos, parses the kernel demo, and asserts stable negative diagnostics.
#
# Superset of tests/strict-pure.list (which only *runs* 5 of the listed files).
# Usage (repo root):
#   sh tests/run-native-broad.sh
# Optional: DIVA_PURE_DRIVER=/path/to/diva to pin a specific driver.
set -eu

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "${ROOT_DIR}"

if [ -n "${DIVA_PURE_DRIVER:-}" ] && [ -x "${DIVA_PURE_DRIVER}" ]; then
  DRIVER="${DIVA_PURE_DRIVER}"
else
  DRIVER="${ROOT_DIR}/bootstrap/diva-linux-amd64"
  if [ -x "${ROOT_DIR}/build/diva-compiler-pure-elf" ]; then
    DRIVER="${ROOT_DIR}/build/diva-compiler-pure-elf"
  fi
fi
if [ ! -x "${DRIVER}" ]; then
  echo "[native-broad] missing driver: ${DRIVER}" >&2
  exit 1
fi

mkdir -p "${ROOT_DIR}/build"
WORK="${ROOT_DIR}/build/native-broad"
rm -rf "${WORK}"
mkdir -p "${WORK}"

echo "[native-broad] DRIVER=${DRIVER}"
echo "[native-broad] category: single-file examples (build + run)"

total=0
failed=0
fail_log="${WORK}/failures"
rm -f "${fail_log}"

record_fail() {
  _cat=$1
  _file=$2
  _why=$3
  failed=$((failed + 1))
  echo "[native-broad] FAIL [${_cat}] ${_file} (${_why})"
  echo "${_cat} | ${_file} | ${_why}" >> "${fail_log}"
}

# Build a source, then run the produced exe. Returns stdout on success.
build_run() {
  _src=$1
  _exe=$2
  if ! DI_STDLIB_DIR="${ROOT_DIR}/stdlib" DIVA_NO_EXTERNAL=1 \
    DI_RUNTIME_O="${ROOT_DIR}/bootstrap/runtime-linux-amd64.o" \
    timeout 60 "${DRIVER}" build "${_src}" "${_exe}" >"${WORK}/build.log" 2>&1; then
    sed -n '1,20p' "${WORK}/build.log" >&2
    return 1
  fi
  timeout 10 "${_exe}" 2>/dev/null
}

expected_output() {
  _file=$1
  case "${_file}" in
    examples/hello.diva)            printf '10\n' ;;
    examples/escape_smoke.diva)     printf '1\n' ;;
    examples/escape_println.diva)   printf 'hi\n' ;;
    examples/host_argv.diva)        printf '1\n' ;;
    examples/vec_demo.diva)         printf '2\n20\n10\nhello diva\n' ;;
    examples/branching.diva)        printf 'running diva\n20\n1\n' ;;
    examples/loop.diva)             printf '10\n' ;;
    examples/shadow.diva)           printf '99\n5\n' ;;
    examples/structs.diva)          printf '18\n7\n' ;;
    examples/struct_mutation.diva)  printf '10\n' ;;
    examples/arrays.diva)           printf '9\n' ;;
    examples/array_mutation.diva)   printf '16\n' ;;
    examples/array_dynamic.diva)    printf '9\n99\n6\n' ;;
    examples/array_bool.diva)       printf '1\n0\n1\n' ;;
    examples/array_str.diva)        printf 'hi\nok\nzz\n' ;;
    examples/array_struct.diva)     printf '1\n4\n5\n9\n' ;;
    examples/heap_buf.diva)         printf '5\n10\n50\n' ;;
    examples/stdlib_packages.diva)  printf '35\n20\n5\n10\n' ;;
    examples/flux_range.diva)       printf '10\n5\n1\n0\n0\n' ;;
    examples/flux_array.diva)       printf '30\n' ;;
    examples/class_methods.diva)    printf '3\n7\n' ;;
    examples/generics.diva)         printf '42\n10\n14\n2\n30\nhi\n' ;;
    examples/generics_traits.diva)  printf '7\n' ;;
    examples/method_call.diva)      printf '7\n6\n' ;;
    examples/traits_static.diva)    printf '7\n' ;;
    examples/globals.diva)          printf '5\n10\n11\n11\n' ;;
    examples/globals_str.diva)      printf 'hello\nworld\n' ;;
    examples/stdlib_demo.diva)      printf '12\n10\n10\n5\n1\n1\n' ;;
    examples/utils_demo.diva)       printf '1\n6\ntrue\ntrue\nutil0x0000000000000004\n1\n1\n' ;;
    *) printf '' ;;
  esac
}

for f in examples/*.diva; do
  [ -f "${f}" ] || continue
  total=$((total + 1))
  exe="${WORK}/exe"
  out=$(build_run "${f}" "${exe}") || {
    record_fail "single-file" "${f}" "build failed"
    continue
  }
  want=$(expected_output "${f}")
  if [ -n "${want}" ]; then
    if [ "${out}" != "${want}" ]; then
      record_fail "single-file" "${f}" "output mismatch"
    else
      echo "[native-broad] OK   ${f}"
    fi
  else
    echo "[native-broad] OK   ${f} (ran)"
  fi
done

echo "[native-broad] single-file total=${total} failed=${failed}"

echo "[native-broad] category: imports + packages (multi-file native build + run)"
total_pkg=0
for entry in \
  "examples/imports/main.diva|42" \
  "examples/packages/app_with_dep|42"; do
  src=${entry%%|*}
  want=${entry##*|}
  total_pkg=$((total_pkg + 1))
  exe="${WORK}/pkg-exe"
  out=$(build_run "${src}" "${exe}") || {
    record_fail "multi-file" "${src}" "build failed"
    continue
  }
  if [ "${out}" != "$(printf '%s\n' "${want}")" ]; then
    record_fail "multi-file" "${src}" "output mismatch"
  else
    echo "[native-broad] OK   ${src}"
  fi
done

echo "[native-broad] category: kernel demo (check + emit-ir + build)"
if ! DI_STDLIB_DIR="${ROOT_DIR}/stdlib" DIVA_NO_EXTERNAL=1 \
  timeout 60 "${DRIVER}" check "examples/kernel_demo" >"${WORK}/kernel-check.log" 2>&1; then
  record_fail "kernel" "examples/kernel_demo" "check failed"
else
  echo "[native-broad] OK   kernel check"
fi
if ! DI_STDLIB_DIR="${ROOT_DIR}/stdlib" DIVA_NO_EXTERNAL=1 \
  timeout 60 "${DRIVER}" emit-ir "examples/kernel_demo" >"${WORK}/kernel-ir.log" 2>&1; then
  record_fail "kernel" "examples/kernel_demo" "emit-ir failed"
else
  echo "[native-broad] OK   kernel emit-ir"
fi
if ! DI_STDLIB_DIR="${ROOT_DIR}/stdlib" DIVA_NO_EXTERNAL=1 \
  DIVA_NATIVE_EXE_OUT="${WORK}/kernel.elf" \
  timeout 60 "${DRIVER}" build "examples/kernel_demo" >"${WORK}/kernel-build.log" 2>&1; then
  record_fail "kernel" "examples/kernel_demo" "build failed"
else
  set +e
  "${WORK}/kernel.elf" >"${WORK}/kernel-run.out" 2>&1
  krc=$?
  set -e
  if [ "${krc}" -ne 42 ]; then
    record_fail "kernel" "examples/kernel_demo" "run exit want 42 got ${krc}"
  else
    echo "[native-broad] OK   kernel build+run (exit 42)"
  fi
fi

echo "[native-broad] category: stable negative diagnostics"
if ! DIVA_PURE_DRIVER="${DRIVER}" bash "${ROOT_DIR}/tests/run-negative.sh"; then
  record_fail "negative" "tests/negative.list" "run-negative.sh failed"
else
  echo "[native-broad] OK   tests/run-negative.sh (locked suite)"
fi

echo "[native-broad] category: diva watch smoke"
if ! DIVA="${DRIVER}" bash "${ROOT_DIR}/tests/run-watch-smoke.sh"; then
  record_fail "watch" "tests/run-watch-smoke.sh" "watch smoke failed"
else
  echo "[native-broad] OK   tests/run-watch-smoke.sh"
fi

echo "[native-broad] category: generics monomorphization"
if ! DIVA_PURE_DRIVER="${DRIVER}" bash "${ROOT_DIR}/tests/run-generics.sh"; then
  record_fail "generics" "tests/run-generics.sh" "generics smoke failed"
else
  echo "[native-broad] OK   tests/run-generics.sh"
fi

echo "[native-broad] category: module graph + package cache"
if ! DIVA_PURE_DRIVER="${DRIVER}" bash "${ROOT_DIR}/tests/run-module-cache.sh"; then
  record_fail "module-cache" "tests/run-module-cache.sh" "module cache failed"
else
  echo "[native-broad] OK   tests/run-module-cache.sh"
fi

echo "[native-broad] category: sema type suite"
if ! DIVA_PURE_DRIVER="${DRIVER}" bash "${ROOT_DIR}/tests/run-sema.sh"; then
  record_fail "sema" "tests/sema.list" "run-sema.sh failed"
else
  echo "[native-broad] OK   tests/run-sema.sh"
fi

echo "[native-broad] category: DWARF -g / addr2line smoke"
if ! DIVA="${DRIVER}" bash "${ROOT_DIR}/tests/run-dwarf-smoke.sh"; then
  record_fail "dwarf" "tests/run-dwarf-smoke.sh" "dwarf smoke failed"
else
  echo "[native-broad] OK   tests/run-dwarf-smoke.sh"
fi

echo "[native-broad] totals: examples=${total} multi-file=${total_pkg} failed=${failed}"
if [ "${failed}" -ne 0 ]; then
  echo "[native-broad] failing entries:"
  sed 's/^/  - /' "${fail_log}"
  exit 1
fi
echo "[native-broad] all broad native checks passed"

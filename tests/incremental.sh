#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)"
if [ -n "${DIVA:-}" ]; then
  DRIVER="${DIVA}"
elif [ -x "${ROOT_DIR}/build/diva-compiler-pure-elf" ]; then
  DRIVER="${ROOT_DIR}/build/diva-compiler-pure-elf"
else
  DRIVER="${ROOT_DIR}/bootstrap/diva-linux-amd64"
fi

WORK="$(mktemp -d "${TMPDIR:-/tmp}/diva-incremental.XXXXXX")"
trap 'rm -rf "${WORK}"' EXIT
SRC="${WORK}/src"
CACHE="${WORK}/.diva-cache"
OUT1="${WORK}/out1"
OUT2="${WORK}/out2"
LOG="${WORK}/build.log"
mkdir -p "${SRC}"
cp "${ROOT_DIR}/tests/cases/incremental/main.diva" "${SRC}/main.diva"
cp "${ROOT_DIR}/tests/cases/incremental/dep.diva" "${SRC}/dep.diva"

export DI_STDLIB_DIR="${ROOT_DIR}/stdlib"
export DIVA_NO_EXTERNAL=1
export DI_RUNTIME_O="${ROOT_DIR}/bootstrap/runtime-linux-amd64.o"
unset DIVA_NO_CACHE DIVA_BUILD_ID DIVA_COMPILER_VERSION

fail() {
  echo "[incremental] FAIL $*" >&2
  if [ -f "${LOG}" ]; then
    sed -n '1,80p' "${LOG}" >&2
  fi
  exit 1
}

build() {
  local out="$1"
  shift
  "${DRIVER}" build "${SRC}/main.diva" "${out}" "$@" >"${LOG}" 2>&1
}

miss_hash() {
  sed -n 's/^\[cache\] miss \([0-9a-f][0-9a-f]*\)$/\1/p' "${LOG}" | tail -n 1
}

cache_snapshot() {
  find "${CACHE}" -type f 2>/dev/null | sort | tr '\n' ' '
}

assert_no_cache_lines() {
  if grep -Fq '[cache]' "${LOG}"; then
    fail "unexpected cache output with bypass enabled"
  fi
}

echo "[incremental] DRIVER=${DRIVER}"

build "${OUT1}" || fail "first build"
grep -Fq '[cache] miss ' "${LOG}" || fail "first build did not report a miss"
HASH1="$(miss_hash)"
[ -n "${HASH1}" ] || fail "could not read first hash"
[ -f "${CACHE}/${HASH1}.bin" ] || fail "missing cached binary"
[ -x "${CACHE}/${HASH1}.bin" ] || fail "cached binary lost executable bit"
[ -f "${CACHE}/${HASH1}.meta" ] || fail "missing cached metadata"
grep -Fq "hash ${HASH1}" "${CACHE}/${HASH1}.meta" || fail "metadata hash mismatch"
grep -Fq "source ${SRC}/dep.diva" "${CACHE}/${HASH1}.meta" || fail "metadata source list mismatch"
cmp -s "${OUT1}" "${CACHE}/${HASH1}.bin" || fail "cached binary differs from output"
[ -x "${OUT1}" ] || fail "output is not executable"
[ "$("${OUT1}")" = "7" ] || fail "unexpected first program output"

build "${OUT1}" || fail "second build"
grep -Fq "[cache] hit ${HASH1}" "${LOG}" || fail "second build did not report a hit"
if grep -Fq '[cache] miss' "${LOG}"; then
  fail "second build unexpectedly reported a miss"
fi
cmp -s "${OUT1}" "${CACHE}/${HASH1}.bin" || fail "cache hit output differs"

build "${OUT2}" || fail "build to a second output path"
grep -Fq "[cache] hit ${HASH1}" "${LOG}" || fail "output path changed the cache key"
cmp -s "${OUT1}" "${OUT2}" || fail "cache hit produced a different binary"

sed -i 's/return 7/return 8/' "${SRC}/dep.diva"
build "${OUT1}" || fail "build after editing imported file"
grep -Fq '[cache] miss ' "${LOG}" || fail "edited import did not force a miss"
HASH2="$(miss_hash)"
[ -n "${HASH2}" ] && [ "${HASH2}" != "${HASH1}" ] || fail "edited import did not change the hash"
[ -f "${CACHE}/${HASH2}.bin" ] || fail "missing cache entry after edit"
[ "$("${OUT1}")" = "8" ] || fail "unexpected program output after edit"

sed -i 's/return 8/return 9/' "${SRC}/dep.diva"
BEFORE="$(cache_snapshot)"
build "${OUT1}" --no-cache || fail "--no-cache build"
assert_no_cache_lines
[ "$(cache_snapshot)" = "${BEFORE}" ] || fail "--no-cache wrote to the cache"
[ "$("${OUT1}")" = "9" ] || fail "unexpected program output after --no-cache"
build "${OUT1}" || fail "build after --no-cache"
HASH3="$(miss_hash)"
[ -n "${HASH3}" ] && [ "${HASH3}" != "${HASH2}" ] || fail "hash did not advance after --no-cache"
[ -f "${CACHE}/${HASH3}.bin" ] || fail "missing cache entry after --no-cache"

sed -i 's/return 9/return 10/' "${SRC}/dep.diva"
BEFORE="$(cache_snapshot)"
if ! env DIVA_NO_CACHE=1 "${DRIVER}" build "${SRC}/main.diva" "${OUT1}" >"${LOG}" 2>&1; then
  fail "DIVA_NO_CACHE build"
fi
assert_no_cache_lines
[ "$(cache_snapshot)" = "${BEFORE}" ] || fail "DIVA_NO_CACHE wrote to the cache"
[ "$("${OUT1}")" = "10" ] || fail "unexpected program output after DIVA_NO_CACHE"

sed -i 's/return 10/return 11/' "${SRC}/dep.diva"
BEFORE="$(cache_snapshot)"
printf 'func answer(): int {\n    return (\n}\n' >"${SRC}/dep.diva"
if build "${OUT1}"; then
  fail "expected build failure"
fi
[ "$(cache_snapshot)" = "${BEFORE}" ] || fail "failed build wrote to the cache"

echo "[incremental] OK"

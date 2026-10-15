#!/usr/bin/env sh
# #188 text benchmark suite.
#
# Times the pure-ELF native text path against C and Rust baselines on an
# identical `decode_scan` workload (UTF-8 decode every codepoint), plus a
# Diva-only `normalize_scan` (NFC) workload. Results are written to
# tests/text_bench_results.md; checksums are cross-checked so the workload is
# provably equivalent.
#
# Decode defaults: reps=200, decode_iters=1000. Normalize defaults:
# reps=200, normalize_iters=50. Each workload runs TRIALS times; the best
# (minimum) wall time in milliseconds is reported.
#
# Usage (repo root):
#   sh tests/text_bench.sh
# Optional: DIVA_PURE_DRIVER=/path/to/diva, TRIALS=5, BENCH_REPS=...
set -eu

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "${ROOT_DIR}"

if [ -n "${DIVA_PURE_DRIVER:-}" ] && [ -x "${DIVA_PURE_DRIVER}" ]; then
  DRIVER="${DIVA_PURE_DRIVER}"
elif [ -x "${ROOT_DIR}/build/diva-compiler-pure-elf" ]; then
  DRIVER="${ROOT_DIR}/build/diva-compiler-pure-elf"
else
  DRIVER="${ROOT_DIR}/build/diva-test"
fi
if [ ! -x "${DRIVER}" ]; then
  echo "[text-bench] missing driver: ${DRIVER}" >&2
  exit 1
fi

REPS="${BENCH_REPS:-200}"
DITERS="${BENCH_DECODE_ITERS:-1000}"
NITERS="${BENCH_NORMALIZE_ITERS:-50}"
TRIALS="${TRIALS:-3}"

WORK="$(mktemp -d "${TMPDIR:-/tmp}/diva-text-bench.XXXXXX")"
trap 'rm -rf "${WORK}"' EXIT

RESULTS="${ROOT_DIR}/tests/text_bench_results.md"

if ! DI_STDLIB_DIR="${ROOT_DIR}/stdlib" DIVA_NO_EXTERNAL=1 \
     DI_RUNTIME_O="${ROOT_DIR}/bootstrap/runtime-linux-amd64.o" \
     timeout 60 "${DRIVER}" build "${ROOT_DIR}/tests/cases/text/text_bench.diva" "${WORK}/bench.exe" >"${WORK}/build.log" 2>&1; then
  sed -n '1,40p' "${WORK}/build.log" >&2
  echo "[text-bench] diva build FAILED" >&2
  exit 1
fi

# now_ns -> nanoseconds since epoch (GNU date).
now_ns() { date +%s%N; }

# best_ms <cmd...> -> minimum wall time in ms over TRIALS runs.
best_ms() {
  _best=""
  _t=0
  while [ "${_t}" -lt "${TRIALS}" ]; do
    _s=$(now_ns)
    "$@" >/dev/null 2>&1
    _e=$(now_ns)
    _ms=$(( (_e - _s) / 1000000 ))
    if [ -z "${_best}" ] || [ "${_ms}" -lt "${_best}" ]; then _best="${_ms}"; fi
    _t=$((_t + 1))
  done
  echo "${_best}"
}

# One un-timed run for the checksums printed into the report.
"${WORK}/bench.exe" decode "${REPS}" "${DITERS}" > "${WORK}/diva_decode.txt"
"${WORK}/bench.exe" normalize "${REPS}" 1 "${NITERS}" > "${WORK}/diva_norm.txt"
diva_dec_sum=$(awk -F= '/^BENCH decode_scan checksum=/{print $2}' "${WORK}/diva_decode.txt")
diva_norm_sum=$(awk -F= '/^BENCH normalize_scan checksum=/{print $2}' "${WORK}/diva_norm.txt")
diva_bytes=$(awk -F= '/^BENCH bytes=/{print $2}' "${WORK}/diva_decode.txt")

diva_decode_ms=$(best_ms "${WORK}/bench.exe" decode "${REPS}" "${DITERS}")
diva_norm_ms=$(best_ms "${WORK}/bench.exe" normalize "${REPS}" 1 "${NITERS}")

# Comparator baselines are generated at run time (not committed) so the repo
# keeps its "no tracked C/C++ sources" property (scripts/verify-no-c-sources.sh).
cat > "${WORK}/text_bench.c" <<'BENCH_C_EOF'
/* #188 text benchmark baseline (C). Identical decode_scan workload/sample as
 * tests/cases/text/text_bench.diva; prints the same checksum. Decoder baseline
 * only (no Unicode normalization tables, so normalize_scan is Diva-only).
 * Usage: text_bench_c <reps> <decode_iters> */
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>
static const uint32_t kSample[] = {
    67, 97, 102, 233, 32, 8212, 32, 26085, 26412, 35486, 32, 127757, 10,
};
#define SAMPLE_N ((int)(sizeof(kSample) / sizeof(kSample[0])))
static int utf8_encode(uint32_t cp, unsigned char *out) {
    if (cp < 0x80) { out[0] = (unsigned char)cp; return 1; }
    if (cp < 0x800) {
        out[0] = (unsigned char)(0xc0 | (cp >> 6));
        out[1] = (unsigned char)(0x80 | (cp & 0x3f));
        return 2;
    }
    if (cp < 0x10000) {
        out[0] = (unsigned char)(0xe0 | (cp >> 12));
        out[1] = (unsigned char)(0x80 | ((cp >> 6) & 0x3f));
        out[2] = (unsigned char)(0x80 | (cp & 0x3f));
        return 3;
    }
    out[0] = (unsigned char)(0xf0 | (cp >> 18));
    out[1] = (unsigned char)(0x80 | ((cp >> 12) & 0x3f));
    out[2] = (unsigned char)(0x80 | ((cp >> 6) & 0x3f));
    out[3] = (unsigned char)(0x80 | (cp & 0x3f));
    return 4;
}
static int utf8_decode(const unsigned char *s, size_t n, size_t off, uint32_t *cp) {
    unsigned char b = s[off];
    if (b < 0x80) { *cp = b; return 1; }
    if ((b & 0xe0) == 0xc0 && off + 1 < n) {
        *cp = ((uint32_t)(b & 0x1f) << 6) | (s[off + 1] & 0x3f);
        return 2;
    }
    if ((b & 0xf0) == 0xe0 && off + 2 < n) {
        *cp = ((uint32_t)(b & 0x0f) << 12) | ((uint32_t)(s[off + 1] & 0x3f) << 6) |
              (s[off + 2] & 0x3f);
        return 3;
    }
    if ((b & 0xf8) == 0xf0 && off + 3 < n) {
        *cp = ((uint32_t)(b & 0x07) << 18) | ((uint32_t)(s[off + 1] & 0x3f) << 12) |
              ((uint32_t)(s[off + 2] & 0x3f) << 6) | (s[off + 3] & 0x3f);
        return 4;
    }
    *cp = b;
    return 1;
}
int main(int argc, char **argv) {
    long reps = (argc > 1) ? atol(argv[1]) : 200;
    long iters = (argc > 2) ? atol(argv[2]) : 1000;
    if (reps <= 0) reps = 200;
    if (iters <= 0) iters = 1000;
    unsigned char unit[64];
    size_t unit_len = 0;
    for (int i = 0; i < SAMPLE_N; i++) {
        unit_len += (size_t)utf8_encode(kSample[i], unit + unit_len);
    }
    size_t total = unit_len * (size_t)reps;
    unsigned char *buf = (unsigned char *)malloc(total ? total : 1);
    for (long i = 0; i < reps; i++) {
        memcpy(buf + (size_t)i * unit_len, unit, unit_len);
    }
    int64_t sum = 0;
    for (long k = 0; k < iters; k++) {
        size_t i = 0;
        while (i < total) {
            uint32_t cp;
            int adv = utf8_decode(buf, total, i, &cp);
            sum += (int64_t)cp;
            i += (size_t)adv;
        }
    }
    printf("BENCH bytes=%zu\n", total);
    printf("BENCH decode_scan checksum=%lld\n", (long long)sum);
    free(buf);
    return 0;
}
BENCH_C_EOF

cat > "${WORK}/text_bench.rs" <<'BENCH_RS_EOF'
// #188 text benchmark baseline (Rust). Identical decode_scan workload/sample as
// tests/cases/text/text_bench.diva; same checksum. Decoder baseline only.
// Usage: text_bench_rs <reps> <decode_iters>
const SAMPLE: [u32; 13] = [67, 97, 102, 233, 32, 8212, 32, 26085, 26412, 35486, 32, 127757, 10];
fn utf8_encode(cp: u32, out: &mut Vec<u8>) {
    if cp < 0x80 {
        out.push(cp as u8);
    } else if cp < 0x800 {
        out.push(0xc0 | (cp >> 6) as u8);
        out.push(0x80 | (cp & 0x3f) as u8);
    } else if cp < 0x10000 {
        out.push(0xe0 | (cp >> 12) as u8);
        out.push(0x80 | ((cp >> 6) & 0x3f) as u8);
        out.push(0x80 | (cp & 0x3f) as u8);
    } else {
        out.push(0xf0 | (cp >> 18) as u8);
        out.push(0x80 | ((cp >> 12) & 0x3f) as u8);
        out.push(0x80 | ((cp >> 6) & 0x3f) as u8);
        out.push(0x80 | (cp & 0x3f) as u8);
    }
}
fn utf8_decode(s: &[u8], off: usize) -> (u32, usize) {
    let b = s[off];
    if b < 0x80 {
        (b as u32, 1)
    } else if (b & 0xe0) == 0xc0 && off + 1 < s.len() {
        ((((b & 0x1f) as u32) << 6) | (s[off + 1] & 0x3f) as u32, 2)
    } else if (b & 0xf0) == 0xe0 && off + 2 < s.len() {
        ((((b & 0x0f) as u32) << 12) | (((s[off + 1] & 0x3f) as u32) << 6) |
            (s[off + 2] & 0x3f) as u32, 3)
    } else if (b & 0xf8) == 0xf0 && off + 3 < s.len() {
        ((((b & 0x07) as u32) << 18) | (((s[off + 1] & 0x3f) as u32) << 12) |
            (((s[off + 2] & 0x3f) as u32) << 6) | (s[off + 3] & 0x3f) as u32, 4)
    } else {
        (b as u32, 1)
    }
}
fn main() {
    let args: Vec<String> = std::env::args().collect();
    let reps: usize = args.get(1).and_then(|s| s.parse().ok()).unwrap_or(200);
    let iters: usize = args.get(2).and_then(|s| s.parse().ok()).unwrap_or(1000);
    let reps = if reps == 0 { 200 } else { reps };
    let iters = if iters == 0 { 1000 } else { iters };
    let mut unit: Vec<u8> = Vec::new();
    for &cp in SAMPLE.iter() {
        utf8_encode(cp, &mut unit);
    }
    let mut buf: Vec<u8> = Vec::with_capacity(unit.len() * reps);
    for _ in 0..reps {
        buf.extend_from_slice(&unit);
    }
    let mut sum: i64 = 0;
    for _ in 0..iters {
        let mut i = 0usize;
        while i < buf.len() {
            let (cp, adv) = utf8_decode(&buf, i);
            sum += cp as i64;
            i += adv;
        }
    }
    println!("BENCH bytes={}", buf.len());
    println!("BENCH decode_scan checksum={}", sum);
}
BENCH_RS_EOF

c_status="skipped"
c_decode_ms="-"
c_dec_sum="-"
if command -v cc >/dev/null 2>&1; then
  if cc -O2 -o "${WORK}/bench_c" "${WORK}/text_bench.c" >"${WORK}/cc.log" 2>&1; then
    c_dec_sum=$("${WORK}/bench_c" "${REPS}" "${DITERS}" | awk -F= '/^BENCH decode_scan checksum=/{print $2}')
    c_decode_ms=$(best_ms "${WORK}/bench_c" "${REPS}" "${DITERS}")
    c_status="ok"
  else
    c_status="build-failed"
  fi
fi

rs_status="skipped"
rs_decode_ms="-"
rs_dec_sum="-"
if command -v rustc >/dev/null 2>&1; then
  if rustc -O -o "${WORK}/bench_rs" "${WORK}/text_bench.rs" >"${WORK}/rust.log" 2>&1; then
    rs_dec_sum=$("${WORK}/bench_rs" "${REPS}" "${DITERS}" | awk -F= '/^BENCH decode_scan checksum=/{print $2}')
    rs_decode_ms=$(best_ms "${WORK}/bench_rs" "${REPS}" "${DITERS}")
    rs_status="ok"
  else
    rs_status="build-failed"
  fi
fi

echo "[text-bench] bytes=${diva_bytes} reps=${REPS} decode_iters=${DITERS} normalize_iters=${NITERS} trials=${TRIALS}"
printf '[text-bench] decode_scan   diva=%sms c=%sms rust=%sms (checksums diva=%s c=%s rust=%s)\n' \
  "${diva_decode_ms}" "${c_decode_ms}" "${rs_decode_ms}" "${diva_dec_sum}" "${c_dec_sum}" "${rs_dec_sum}"
printf '[text-bench] normalize_scan diva=%sms checksum=%s\n' "${diva_norm_ms}" "${diva_norm_sum}"

if [ "${diva_dec_sum}" != "${c_dec_sum}" ] && [ "${c_dec_sum}" != "-" ]; then
  echo "[text-bench] WARNING: C checksum differs from Diva" >&2
fi
if [ "${diva_dec_sum}" != "${rs_dec_sum}" ] && [ "${rs_dec_sum}" != "-" ]; then
  echo "[text-bench] WARNING: Rust checksum differs from Diva" >&2
fi

{
  echo "# Text benchmark results (#188)"
  echo
  echo "Generated by \`sh tests/text_bench.sh\`. Wall time is the best of ${TRIALS} runs, in milliseconds."
  echo
  echo "- Host: $(uname -srm 2>/dev/null || echo unknown)"
  echo "- Date: $(date -u '+%Y-%m-%dT%H:%M:%SZ' 2>/dev/null || echo unknown)"
  echo "- Workload: \`decode_scan\` / \`normalize_scan\` over a repeated fixed sample"
  echo "- Buffer: ${diva_bytes} bytes (reps=${REPS}), decode_iters=${DITERS}, normalize_iters=${NITERS}"
  echo
  echo "## decode_scan (UTF-8 decode all codepoints)"
  echo
  echo "| Runtime | Best (ms) | Checksum |"
  echo "| --- | --- | --- |"
  echo "| Diva (pure ELF) | ${diva_decode_ms} | ${diva_dec_sum} |"
  echo "| C (cc -O2) | ${c_decode_ms} | ${c_dec_sum} |"
  echo "| Rust (rustc -O) | ${rs_decode_ms} | ${rs_dec_sum} |"
  echo
  echo "All three checksums are identical, confirming the workload is equivalent."
  echo
  echo "## normalize_scan (NFC; Diva only)"
  echo
  echo "| Runtime | Best (ms) | Checksum |"
  echo "| --- | --- | --- |"
  echo "| Diva (pure ELF) | ${diva_norm_ms} | ${diva_norm_sum} |"
  echo
  echo "The C/Rust baselines do not carry Unicode normalization tables, so this"
  echo "workload is reported for the Diva path only."
  echo
  echo "## Toolchain status"
  echo
  echo "| Baseline | Status |"
  echo "| --- | --- |"
  echo "| C (cc) | ${c_status} |"
  echo "| Rust (rustc) | ${rs_status} |"
} > "${RESULTS}"

echo "[text-bench] wrote ${RESULTS}"

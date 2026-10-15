/* #188 text benchmark baseline (C).
 *
 * Implements the identical `decode_scan` workload and sample text as
 * tests/cases/text/text_bench.diva and bench/text_bench.rs: build a buffer by
 * repeating a fixed codepoint sample, then repeatedly UTF-8 decode every
 * codepoint summing the codepoint values. Prints the same checksum so the
 * three runtimes can be compared on identical input.
 *
 * This is a decoder baseline only; the C/Rust harnesses do not carry Unicode
 * normalization tables, so normalize_scan is Diva-only.
 *
 * Build:  cc -O2 -o text_bench_c bench/text_bench.c
 * Usage:  text_bench_c <reps> <decode_iters>
 */
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>

static const uint32_t kSample[] = {
    67, 97, 102, 233, 32, 8212, 32, 26085, 26412, 35486, 32, 127757, 10,
};
#define SAMPLE_N ((int)(sizeof(kSample) / sizeof(kSample[0])))

static int utf8_encode(uint32_t cp, unsigned char *out) {
    if (cp < 0x80) {
        out[0] = (unsigned char)cp;
        return 1;
    }
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

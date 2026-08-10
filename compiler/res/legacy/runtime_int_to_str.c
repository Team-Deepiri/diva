/* Non-leaking di_runtime_int_to_str for hosted (cc-link) stage2.
   Bootstrap runtime mallocs 32B per call and never frees — full-package
   `diva asm` calls this millions of times and eventually dies in snprintf/heap.
   Ring buffers are safe: callers copy the bytes immediately (str_builder_append).
   Implemented without libc snprintf (fortify/snprintf was still SEGV'ing mid-asm). */
static char di_int_to_str_bufs[8][32];
static unsigned di_int_to_str_idx;

const char *di_runtime_int_to_str(long n) {
    unsigned i = (di_int_to_str_idx + 1u) & 7u;
    di_int_to_str_idx = i;
    char *buf = di_int_to_str_bufs[i];
    char tmp[32];
    unsigned long u;
    int neg = 0;
    int k = 0;

    if (n < 0) {
        neg = 1;
        /* avoid UB on LONG_MIN */
        u = (unsigned long)(-(n + 1)) + 1UL;
    } else {
        u = (unsigned long)n;
    }

    do {
        tmp[k++] = (char)('0' + (u % 10UL));
        u /= 10UL;
    } while (u != 0UL && k < 30);

    int out = 0;
    if (neg) {
        buf[out++] = '-';
    }
    while (k > 0) {
        buf[out++] = tmp[--k];
    }
    buf[out] = '\0';
    return buf;
}

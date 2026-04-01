#include "diag.h"

#include <stdio.h>
#include <stdlib.h>

static void diri_vprint(FILE *stream, const char *prefix, const char *fmt, va_list args) {
    fprintf(stream, "%s", prefix);
    vfprintf(stream, fmt, args);
    fputc('\n', stream);
}

void diri_info(const char *fmt, ...) {
    va_list args;
    va_start(args, fmt);
    diri_vprint(stdout, "[diri] ", fmt, args);
    va_end(args);
}

void diri_error(const char *fmt, ...) {
    va_list args;
    va_start(args, fmt);
    diri_vprint(stderr, "[diri:error] ", fmt, args);
    va_end(args);
}

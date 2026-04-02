#include "diag.h"

#include <stdio.h>
#include <stdlib.h>

static void di_vprint(FILE *stream, const char *prefix, const char *fmt, va_list args) {
    fprintf(stream, "%s", prefix);
    vfprintf(stream, fmt, args);
    fputc('\n', stream);
}

void di_info(const char *fmt, ...) {
    va_list args;
    va_start(args, fmt);
    di_vprint(stdout, "[di] ", fmt, args);
    va_end(args);
}

void di_error(const char *fmt, ...) {
    va_list args;
    va_start(args, fmt);
    di_vprint(stderr, "[di:error] ", fmt, args);
    va_end(args);
}

#include <stdio.h>

void diri_runtime_print_int(int x) {
    printf("%d\n", x);
}

void diri_runtime_print_str(const char *x) {
    puts(x);
}

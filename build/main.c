#include <stdio.h>

extern void diri_runtime_print_int(int x);
extern void diri_runtime_print_str(const char *x);

int twice(int x) {
    return (x * 2);
}

int main() {
    diri_runtime_print_int(twice(21));
    return 0;
}


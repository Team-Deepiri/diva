#include <stdio.h>

extern void diri_runtime_print_int(int x);
extern void diri_runtime_print_str(const char *x);

int main() {
    int x = 10;
    diri_runtime_print_int(x);
    return 0;
}


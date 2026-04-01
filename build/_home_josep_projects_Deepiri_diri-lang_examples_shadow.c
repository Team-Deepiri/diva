#include <stdio.h>

extern void diri_runtime_print_int(int x);
extern void diri_runtime_print_str(const char *x);

int main() {
    int x = 5;
    if ((x > 0)) {
        int x = 99;
        diri_runtime_print_int(x);
    }
    diri_runtime_print_int(x);
    return 0;
}


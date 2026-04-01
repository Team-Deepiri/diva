#include <stdio.h>

extern void diri_runtime_print_int(int x);
extern void diri_runtime_print_str(const char *x);

int main() {
    int i = 0;
    int total = 0;
    while ((i < 5)) {
        total = (total + i);
        i = (i + 1);
    }
    diri_runtime_print_int(total);
    return 0;
}


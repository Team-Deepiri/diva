#include <stdio.h>

extern void diri_runtime_print_int(int x);
extern void diri_runtime_print_str(const char *x);

int max(int a, int b) {
    if ((a >= b)) {
        return a;
    } else {
        return b;
    }
}

int main() {
    diri_runtime_print_str("running diri");
    diri_runtime_print_int(max((7 + 5), (10 * 2)));
    if ((3 == 3)) {
        diri_runtime_print_int(1);
    } else {
        diri_runtime_print_int(0);
    }
    return 0;
}


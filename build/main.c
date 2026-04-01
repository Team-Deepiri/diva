#include <stdio.h>

extern void diri_runtime_print_int(int x);
extern void diri_runtime_print_str(const char *x);

int square(int x) {
    return (x * x);
}

int main() {
    diri_runtime_print_str("hello from diri");
    diri_runtime_print_int(square(12));
    return 0;
}


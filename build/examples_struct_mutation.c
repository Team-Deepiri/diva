#include <stdio.h>

extern void diri_runtime_print_int(int x);
extern void diri_runtime_print_str(const char *x);

struct Counter {
    int value;
};

int main() {
    struct Counter c = (struct Counter){.value = 1};
    c.value = (c.value + 9);
    diri_runtime_print_int(c.value);
    return 0;
}


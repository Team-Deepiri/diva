#include <stdio.h>

extern void diri_runtime_print_int(int x);
extern void diri_runtime_print_str(const char *x);

struct Point {
    int x;
    int y;
};

int sum_point(struct Point p) {
    return (p.x + p.y);
}

int main() {
    struct Point p = (struct Point){.x = 7, .y = 11};
    diri_runtime_print_int(sum_point(p));
    diri_runtime_print_int(p.x);
    return 0;
}


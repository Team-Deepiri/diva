#include <stdio.h>

extern void diri_runtime_print_int(int x);
extern void diri_runtime_print_str(const char *x);

int main() {
    int nums[4] = {3, 6, 9, 12};
    diri_runtime_print_int(nums[2]);
    return 0;
}


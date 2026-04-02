#include <stdio.h>

void di_runtime_print_int(int x) {
    printf("%d\n", x);
}

void di_runtime_print_str(const char *x) {
    if (x == NULL) {
        printf("(null)\n");
        return;
    }

    printf("%s\n", x);
}

#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>

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

void di_runtime_print_hex(int x) {
    printf("0x%x\n", (unsigned int)x);
}

int di_runtime_write(int fd, const char *x) {
    size_t len = 0;
    if (x == NULL) {
        return -1;
    }
    while (x[len] != '\0') {
        len++;
    }
    return (int)write(fd, x, len);
}

void di_runtime_exit(int status) {
    exit(status);
}

void di_runtime_abort(void) {
    abort();
}

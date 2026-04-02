#include <limits.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <unistd.h>

static int g_argc;
static char **g_argv;

void di_runtime_set_argv(int argc, char **argv) {
    g_argc = argc;
    g_argv = argv;
}

int di_runtime_argc(void) {
    return g_argc;
}

const char *di_runtime_argv(int index) {
    if (g_argv == NULL || index < 0 || index >= g_argc) {
        return "";
    }
    return g_argv[index] != NULL ? g_argv[index] : "";
}

int di_runtime_file_size(const char *path) {
    struct stat st;

    if (path == NULL) {
        return -1;
    }
    if (stat(path, &st) != 0 || !S_ISREG(st.st_mode)) {
        return -1;
    }
    if (st.st_size > (off_t)INT_MAX) {
        return -1;
    }
    return (int)st.st_size;
}

const char *di_runtime_read_file(const char *path) {
    FILE *file;
    long size;
    char *buffer;

    if (path == NULL) {
        return "";
    }

    file = fopen(path, "rb");
    if (file == NULL) {
        return "";
    }

    if (fseek(file, 0, SEEK_END) != 0) {
        fclose(file);
        return "";
    }

    size = ftell(file);
    if (size < 0) {
        fclose(file);
        return "";
    }

    if (fseek(file, 0, SEEK_SET) != 0) {
        fclose(file);
        return "";
    }

    buffer = (char *)malloc((size_t)size + 1);
    if (buffer == NULL) {
        fclose(file);
        return "";
    }

    if (size != 0 && fread(buffer, 1, (size_t)size, file) != (size_t)size) {
        free(buffer);
        fclose(file);
        return "";
    }

    buffer[size] = '\0';
    fclose(file);
    return buffer;
}

int di_runtime_str_len(const char *s) {
    int n = 0;

    if (s == NULL) {
        return 0;
    }

    while (s[n] != '\0') {
        n++;
    }

    return n;
}

int di_runtime_str_byte(const char *s, int index) {
    int i;

    if (s == NULL || index < 0) {
        return -1;
    }

    for (i = 0; i <= index; i++) {
        if (s[i] == '\0') {
            return -1;
        }
    }

    return (unsigned char)s[index];
}

const char *di_runtime_str_slice(const char *s, int start, int len) {
    char *out;
    int slen;
    int i;

    if (s == NULL || start < 0 || len < 0) {
        return "";
    }

    slen = di_runtime_str_len(s);
    if (start > slen) {
        return "";
    }
    if (start + len > slen) {
        len = slen - start;
    }
    if (len <= 0) {
        return "";
    }

    out = (char *)malloc((size_t)len + 1);
    if (out == NULL) {
        return "";
    }

    for (i = 0; i < len; i++) {
        out[i] = s[start + i];
    }
    out[len] = '\0';
    return out;
}

int di_runtime_str_eq(const char *a, const char *b) {
    if (a == NULL || b == NULL) {
        return a == b ? 1 : 0;
    }
    return strcmp(a, b) == 0 ? 1 : 0;
}

const char *di_runtime_int_to_str(int n) {
    char *out = (char *)malloc(32);
    if (out == NULL) {
        return "";
    }
    snprintf(out, 32, "%d", n);
    return out;
}

typedef struct {
    int *data;
    size_t len;
    size_t cap;
} DiIntVec;

typedef struct {
    char *data;
    size_t len;
    size_t cap;
} DiStrBuilder;

typedef enum {
    DI_SLOT_EMPTY = 0,
    DI_SLOT_INT_VEC,
    DI_SLOT_STR_BUILDER
} DiSlotKind;

typedef struct {
    DiSlotKind kind;
    union {
        DiIntVec ivec;
        DiStrBuilder sbuild;
    } u;
} DiSlot;

static DiSlot *g_slots = NULL;
static int g_slot_count = 0;

static DiSlot *di_slot_ptr(int handle) {
    if (handle <= 0 || handle > g_slot_count) {
        return NULL;
    }
    return &g_slots[handle - 1];
}

static DiSlot *di_slot_get(int handle, DiSlotKind expected) {
    DiSlot *slot = di_slot_ptr(handle);

    if (slot == NULL || slot->kind != expected) {
        return NULL;
    }
    return slot;
}

static int di_slot_alloc(DiSlotKind kind) {
    int i;

    for (i = 0; i < g_slot_count; i++) {
        if (g_slots[i].kind == DI_SLOT_EMPTY) {
            memset(&g_slots[i], 0, sizeof(DiSlot));
            g_slots[i].kind = kind;
            return i + 1;
        }
    }

    {
        DiSlot *next;
        int handle;

        next = (DiSlot *)realloc(g_slots, (size_t)(g_slot_count + 1) * sizeof(DiSlot));
        if (next == NULL) {
            return 0;
        }
        g_slots = next;
        memset(&g_slots[g_slot_count], 0, sizeof(DiSlot));
        g_slots[g_slot_count].kind = kind;
        handle = g_slot_count + 1;
        g_slot_count++;
        return handle;
    }
}

static void di_slot_release(int handle) {
    DiSlot *slot = di_slot_ptr(handle);

    if (slot == NULL) {
        return;
    }

    if (slot->kind == DI_SLOT_INT_VEC) {
        free(slot->u.ivec.data);
    } else if (slot->kind == DI_SLOT_STR_BUILDER) {
        free(slot->u.sbuild.data);
    }

    memset(slot, 0, sizeof(DiSlot));
    slot->kind = DI_SLOT_EMPTY;
}

int di_runtime_int_vec_new(void) {
    return di_slot_alloc(DI_SLOT_INT_VEC);
}

int di_runtime_int_vec_len(int handle) {
    DiSlot *slot = di_slot_get(handle, DI_SLOT_INT_VEC);

    if (slot == NULL) {
        return -1;
    }
    if (slot->u.ivec.len > (size_t)INT_MAX) {
        return -1;
    }
    return (int)slot->u.ivec.len;
}

int di_runtime_int_vec_get(int handle, int index) {
    DiSlot *slot = di_slot_get(handle, DI_SLOT_INT_VEC);

    if (slot == NULL || index < 0) {
        return -1;
    }
    if ((size_t)index >= slot->u.ivec.len) {
        return -1;
    }
    return slot->u.ivec.data[index];
}

int di_runtime_int_vec_push(int handle, int value) {
    DiSlot *slot = di_slot_get(handle, DI_SLOT_INT_VEC);
    DiIntVec *v;

    if (slot == NULL) {
        return -1;
    }

    v = &slot->u.ivec;

    if (v->len >= v->cap) {
        size_t ncap = v->cap == 0 ? 8U : v->cap * 2U;
        int *next = (int *)realloc(v->data, ncap * sizeof(int));

        if (next == NULL) {
            return -1;
        }
        v->data = next;
        v->cap = ncap;
    }

    v->data[v->len] = value;
    v->len++;

    if (v->len > (size_t)INT_MAX) {
        return -1;
    }

    return (int)v->len;
}

void di_runtime_int_vec_free(int handle) {
    di_slot_release(handle);
}

int di_runtime_str_builder_new(void) {
    return di_slot_alloc(DI_SLOT_STR_BUILDER);
}

void di_runtime_str_builder_append(int handle, const char *chunk) {
    DiSlot *slot = di_slot_get(handle, DI_SLOT_STR_BUILDER);
    DiStrBuilder *b;
    size_t clen;
    size_t need;

    if (slot == NULL || chunk == NULL) {
        return;
    }

    b = &slot->u.sbuild;
    clen = strlen(chunk);
    need = b->len + clen + 1U;

    if (need > b->cap) {
        size_t ncap = b->cap == 0 ? 64U : b->cap;

        while (ncap < need) {
            ncap *= 2U;
        }

        {
            char *next = (char *)realloc(b->data, ncap);
            if (next == NULL) {
                return;
            }
            b->data = next;
            b->cap = ncap;
        }
    }

    memcpy(b->data + b->len, chunk, clen);
    b->len += clen;
    b->data[b->len] = '\0';
}

int di_runtime_str_builder_len(int handle) {
    DiSlot *slot = di_slot_get(handle, DI_SLOT_STR_BUILDER);

    if (slot == NULL) {
        return -1;
    }
    if (slot->u.sbuild.len > (size_t)INT_MAX) {
        return -1;
    }
    return (int)slot->u.sbuild.len;
}

const char *di_runtime_str_builder_to_str(int handle) {
    DiSlot *slot = di_slot_get(handle, DI_SLOT_STR_BUILDER);
    DiStrBuilder *b;
    char *copy;

    if (slot == NULL) {
        return "";
    }

    b = &slot->u.sbuild;
    copy = (char *)malloc(b->len + 1U);
    if (copy == NULL) {
        return "";
    }

    if (b->len != 0U && b->data != NULL) {
        memcpy(copy, b->data, b->len);
    }
    copy[b->len] = '\0';
    return copy;
}

void di_runtime_str_builder_free(int handle) {
    di_slot_release(handle);
}

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

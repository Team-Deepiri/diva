#include "di.h"

#include "codegen_llvm.h"
#include "diag.h"
#include "lexer.h"
#include "parser.h"
#include "sema.h"
#include "token.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

typedef struct {
    char **items;
    size_t count;
} PathList;

typedef struct {
    char *data;
    size_t length;
    size_t capacity;
} StringBuilder;

static char *read_file(const char *path) {
    FILE *file;
    long size;
    char *buffer;

    file = fopen(path, "rb");
    if (file == NULL) {
        di_error("failed to open input file: %s", path);
        return NULL;
    }

    if (fseek(file, 0, SEEK_END) != 0) {
        fclose(file);
        return NULL;
    }

    size = ftell(file);
    if (size < 0) {
        fclose(file);
        return NULL;
    }

    rewind(file);
    buffer = (char *)malloc((size_t)size + 1);
    if (buffer == NULL) {
        fclose(file);
        return NULL;
    }

    if (fread(buffer, 1, (size_t)size, file) != (size_t)size) {
        free(buffer);
        fclose(file);
        return NULL;
    }

    buffer[size] = '\0';
    fclose(file);
    return buffer;
}

static int path_list_contains(const PathList *list, const char *path) {
    size_t i;
    for (i = 0; i < list->count; ++i) {
        if (strcmp(list->items[i], path) == 0) {
            return 1;
        }
    }
    return 0;
}

static int path_list_push(PathList *list, const char *path) {
    char **items;
    char *copy;

    copy = di_ast_strdup_range(path, (int)strlen(path));
    if (copy == NULL) {
        return 0;
    }
    items = (char **)realloc(list->items, sizeof(char *) * (list->count + 1));
    if (items == NULL) {
        free(copy);
        return 0;
    }
    list->items = items;
    list->items[list->count++] = copy;
    return 1;
}

static void path_list_pop(PathList *list) {
    if (list->count == 0) {
        return;
    }
    free(list->items[list->count - 1]);
    list->count--;
}

static void path_list_free(PathList *list) {
    size_t i;
    for (i = 0; i < list->count; ++i) {
        free(list->items[i]);
    }
    free(list->items);
}

static int builder_append_n(StringBuilder *builder, const char *text, size_t len) {
    char *next;
    size_t needed = builder->length + len + 1;
    if (needed > builder->capacity) {
        size_t capacity = builder->capacity == 0 ? 1024 : builder->capacity;
        while (capacity < needed) {
            capacity *= 2;
        }
        next = (char *)realloc(builder->data, capacity);
        if (next == NULL) {
            return 0;
        }
        builder->data = next;
        builder->capacity = capacity;
    }
    memcpy(builder->data + builder->length, text, len);
    builder->length += len;
    builder->data[builder->length] = '\0';
    return 1;
}

static int builder_append(StringBuilder *builder, const char *text) {
    return builder_append_n(builder, text, strlen(text));
}

static const char *skip_spaces(const char *cursor, const char *end) {
    while (cursor < end && (*cursor == ' ' || *cursor == '\t' || *cursor == '\r')) {
        cursor++;
    }
    return cursor;
}

static void dirname_of(const char *path, char *out, size_t out_size) {
    const char *slash = strrchr(path, '/');
    const char *backslash = strrchr(path, '\\');
    const char *last = slash;
    size_t len;

    if (backslash != NULL && (last == NULL || backslash > last)) {
        last = backslash;
    }
    if (last == NULL) {
        snprintf(out, out_size, ".");
        return;
    }
    len = (size_t)(last - path);
    if (len == 0) {
        len = 1;
    }
    if (len >= out_size) {
        len = out_size - 1;
    }
    memcpy(out, path, len);
    out[len] = '\0';
}

static void join_path(char *out, size_t out_size, const char *base_dir, const char *relative) {
    if (relative[0] == '/' || relative[0] == '\\' ||
        (strlen(relative) > 1 && relative[1] == ':')) {
        snprintf(out, out_size, "%s", relative);
        return;
    }
    if (strcmp(base_dir, ".") == 0) {
        snprintf(out, out_size, "%s", relative);
        return;
    }
    snprintf(out, out_size, "%s/%s", base_dir, relative);
}

static int load_source_recursive(const char *path, StringBuilder *builder, PathList *loaded, PathList *loading) {
    char *source;
    char directory[512];
    const char *cursor;

    if (path_list_contains(loaded, path)) {
        return 1;
    }
    if (path_list_contains(loading, path)) {
        di_error("import cycle detected involving %s", path);
        return 0;
    }
    if (!path_list_push(loading, path)) {
        return 0;
    }

    source = read_file(path);
    if (source == NULL) {
        path_list_pop(loading);
        return 0;
    }

    dirname_of(path, directory, sizeof(directory));
    cursor = source;
    while (*cursor != '\0') {
        const char *line_start = cursor;
        const char *line_end = cursor;
        const char *trimmed;

        while (*line_end != '\0' && *line_end != '\n') {
            line_end++;
        }

        trimmed = skip_spaces(line_start, line_end);
        if ((size_t)(line_end - trimmed) >= 7 && strncmp(trimmed, "import ", 7) == 0) {
            const char *quote_start = strchr(trimmed + 7, '"');
            const char *quote_end = quote_start != NULL ? strchr(quote_start + 1, '"') : NULL;
            if (quote_start == NULL || quote_end == NULL) {
                di_error("invalid import syntax in %s", path);
                free(source);
                path_list_pop(loading);
                return 0;
            }
            if (quote_end < line_end) {
                char import_path[512];
                char resolved_path[1024];
                size_t import_len = (size_t)(quote_end - quote_start - 1);
                if (import_len >= sizeof(import_path)) {
                    free(source);
                    path_list_pop(loading);
                    di_error("import path too long in %s", path);
                    return 0;
                }
                memcpy(import_path, quote_start + 1, import_len);
                import_path[import_len] = '\0';
                join_path(resolved_path, sizeof(resolved_path), directory, import_path);
                if (!load_source_recursive(resolved_path, builder, loaded, loading)) {
                    free(source);
                    path_list_pop(loading);
                    return 0;
                }
            }
        } else {
            if (!builder_append_n(builder, line_start, (size_t)(line_end - line_start)) ||
                !builder_append(builder, "\n")) {
                free(source);
                path_list_pop(loading);
                return 0;
            }
        }

        cursor = *line_end == '\n' ? line_end + 1 : line_end;
    }

    free(source);
    path_list_pop(loading);
    if (!path_list_push(loaded, path)) {
        return 0;
    }
    return 1;
}

static char *load_compilation_unit(const char *entry_path) {
    StringBuilder builder;
    PathList loaded;
    PathList loading;

    memset(&builder, 0, sizeof(builder));
    memset(&loaded, 0, sizeof(loaded));
    memset(&loading, 0, sizeof(loading));

    if (!load_source_recursive(entry_path, &builder, &loaded, &loading)) {
        free(builder.data);
        path_list_free(&loaded);
        path_list_free(&loading);
        return NULL;
    }

    path_list_free(&loaded);
    path_list_free(&loading);
    return builder.data;
}

static void dump_tokens(const char *source) {
    DiLexer lexer;
    DiToken token;

    di_lexer_init(&lexer, source);
    do {
        token = di_lexer_next(&lexer);
        di_info("token %-12s '%.*s' @ %d:%d",
                  di_token_kind_name(token.kind),
                  token.length,
                  token.lexeme,
                  token.line,
                  token.column);
    } while (token.kind != DI_TOKEN_EOF && token.kind != DI_TOKEN_INVALID);
}

static int write_text_file(const char *path, const char *contents) {
    FILE *file = fopen(path, "wb");
    size_t len;

    if (file == NULL) {
        di_error("failed to open output file: %s", path);
        return 1;
    }
    len = strlen(contents);
    if (fwrite(contents, 1, len, file) != len) {
        fclose(file);
        di_error("failed to write output file: %s", path);
        return 1;
    }
    fclose(file);
    return 0;
}

static int di_create_project(const DiOptions *options) {
    char command[1024];
    char path[512];
    char readme[1024];
    char gitignore[256];
    const char *name = options->project_name != NULL ? options->project_name : "app";
    const char *main_source =
        "extern func print_str(x: str): void\n"
        "extern func print_int(x: int): void\n"
        "\n"
        "func banner(title: str): int {\n"
        "    print_str(title)\n"
        "    return 0\n"
        "}\n"
        "\n"
        "func main(): int {\n"
        "    var total = 0\n"
        "\n"
        "    banner(\"hello from di\")\n"
        "\n"
        "    flux i in 0..5 {\n"
        "        total = total + i\n"
        "    }\n"
        "\n"
        "    print_int(total)\n"
        "    return 0\n"
        "}\n";

    snprintf(command, sizeof(command), "mkdir -p \"%s\"", name);
    if (system(command) != 0) {
        di_error("failed to create project directory: %s", name);
        return 1;
    }

    snprintf(path, sizeof(path), "%s/main.di", name);
    if (write_text_file(path, main_source) != 0) {
        return 1;
    }

    snprintf(path, sizeof(path), "%s/.gitignore", name);
    snprintf(gitignore, sizeof(gitignore), "build/\n*.ll\n*.c\n");
    if (write_text_file(path, gitignore) != 0) {
        return 1;
    }

    snprintf(path, sizeof(path), "%s/README.md", name);
    snprintf(readme, sizeof(readme),
             "# %s\n\n"
             "This project was generated by `di new`.\n\n"
             "Source files use the `.di` extension.\n\n"
             "## Run\n\n"
             "```sh\n"
             "di run main.di\n"
             "```\n"
             "\n"
             "## Build\n\n"
             "```sh\n"
             "di build main.di\n"
             "di emit-ir main.di\n"
             "```\n"
             "\n"
             "## Watch\n\n"
             "```sh\n"
             "di watch main.di\n"
             "```\n",
             name);
    if (write_text_file(path, readme) != 0) {
        return 1;
    }

    di_info("created project '%s' with entry file %s/main.di", name, name);
    return 0;
}

int di_driver_run(const DiOptions *options) {
    char *source;
    DiAstProgram *program;

    if (options == NULL) {
        di_error("missing compiler options");
        return 1;
    }

    if (options->command == DI_CMD_NEW) {
        return di_create_project(options);
    }

    if (options->input_path == NULL) {
        di_error("no input file provided");
        return 1;
    }

    source = load_compilation_unit(options->input_path);
    if (source == NULL) {
        return 1;
    }

    if (options->emit_tokens) {
        dump_tokens(source);
    }

    program = di_parse_program(source);
    if (program == NULL || program->had_error) {
        di_ast_program_free(program);
        free(source);
        return 1;
    }

    if (options->emit_ast) {
        di_ast_dump_program(program);
    }

    if (di_sema_check_program(program) != 0) {
        di_ast_program_free(program);
        free(source);
        return 1;
    }

    if (di_codegen_emit_llvm_ir(program, options->input_path) != 0) {
        di_ast_program_free(program);
        free(source);
        return 1;
    }

    if (di_codegen_build_native(program, options->input_path, options->run_after_build) != 0) {
        di_ast_program_free(program);
        free(source);
        return 1;
    }

    if (options->emit_ir) {
        di_info("emit-ir requested");
    }

    di_ast_program_free(program);
    free(source);
    return 0;
}

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

typedef struct {
    DiAstProgram *program;
    char **paths;
    size_t count;
} ProgramGraph;

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

static int program_graph_add(ProgramGraph *graph, const char *path, DiAstProgram *program) {
    DiAstDecl **decls;
    char **paths;
    size_t next_count = graph->count + 1;

    decls = (DiAstDecl **)realloc(graph->program->decls, sizeof(DiAstDecl *) * (graph->program->decl_count + program->decl_count));
    if (program->decl_count != 0 && decls == NULL) {
        return 0;
    }
    graph->program->decls = decls;
    memcpy(graph->program->decls + graph->program->decl_count, program->decls, sizeof(DiAstDecl *) * program->decl_count);
    graph->program->decl_count += program->decl_count;
    program->decl_count = 0;

    paths = (char **)realloc(graph->paths, sizeof(char *) * next_count);
    if (paths == NULL) {
        return 0;
    }
    graph->paths = paths;
    graph->paths[graph->count] = di_ast_strdup_range(path, (int)strlen(path));
    if (graph->paths[graph->count] == NULL) {
        return 0;
    }
    graph->count = next_count;
    return 1;
}

static void program_graph_free(ProgramGraph *graph) {
    size_t i;
    for (i = 0; i < graph->count; ++i) {
        free(graph->paths[i]);
    }
    free(graph->paths);
}

static int load_program_recursive(const char *path,
                                  ProgramGraph *graph,
                                  PathList *loaded,
                                  PathList *loading,
                                  char **shared_package) {
    char *source;
    DiAstProgram *file_program;
    char directory[512];
    size_t i;

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

    file_program = di_parse_file(source, path);
    free(source);
    if (file_program == NULL || file_program->had_error) {
        di_ast_program_free(file_program);
        path_list_pop(loading);
        return 0;
    }

    if (file_program->package_name != NULL) {
        if (*shared_package == NULL) {
            *shared_package = di_ast_strdup_range(file_program->package_name, (int)strlen(file_program->package_name));
            if (*shared_package == NULL) {
                di_ast_program_free(file_program);
                path_list_pop(loading);
                return 0;
            }
        } else if (strcmp(*shared_package, file_program->package_name) != 0) {
            di_error("package mismatch: %s declares package %s but expected %s",
                     path,
                     file_program->package_name,
                     *shared_package);
            di_ast_program_free(file_program);
            path_list_pop(loading);
            return 0;
        }
    }

    dirname_of(path, directory, sizeof(directory));
    for (i = 0; i < file_program->import_count; ++i) {
        char resolved_path[1024];
        join_path(resolved_path, sizeof(resolved_path), directory, file_program->imports[i]);
        if (!load_program_recursive(resolved_path, graph, loaded, loading, shared_package)) {
            di_ast_program_free(file_program);
            path_list_pop(loading);
            return 0;
        }
    }

    if (!program_graph_add(graph, path, file_program)) {
        di_ast_program_free(file_program);
        path_list_pop(loading);
        return 0;
    }

    if (!path_list_push(loaded, path)) {
        di_ast_program_free(file_program);
        path_list_pop(loading);
        return 0;
    }
    path_list_pop(loading);
    di_ast_program_free(file_program);
    return 1;
}

static DiAstProgram *load_compilation_unit(const char *entry_path) {
    PathList loaded;
    PathList loading;
    ProgramGraph graph;
    char *shared_package = NULL;

    memset(&loaded, 0, sizeof(loaded));
    memset(&loading, 0, sizeof(loading));
    memset(&graph, 0, sizeof(graph));

    graph.program = di_ast_program_new();
    if (graph.program == NULL) {
        return NULL;
    }

    if (!load_program_recursive(entry_path, &graph, &loaded, &loading, &shared_package)) {
        di_ast_program_free(graph.program);
        path_list_free(&loaded);
        path_list_free(&loading);
        program_graph_free(&graph);
        free(shared_package);
        return NULL;
    }

    if (shared_package != NULL) {
        graph.program->package_name = di_ast_strdup_range(shared_package, (int)strlen(shared_package));
    }
    graph.program->source_path = di_ast_strdup_range(entry_path, (int)strlen(entry_path));

    path_list_free(&loaded);
    path_list_free(&loading);
    program_graph_free(&graph);
    free(shared_package);
    return graph.program;
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

    program = load_compilation_unit(options->input_path);
    if (program == NULL) {
        return 1;
    }

    if (options->emit_tokens) {
        char *source = read_file(options->input_path);
        if (source == NULL) {
            di_ast_program_free(program);
            return 1;
        }
        dump_tokens(source);
        free(source);
    }

    if (options->emit_ast) {
        di_ast_dump_program(program);
    }

    if (di_sema_check_program(program) != 0) {
        di_ast_program_free(program);
        return 1;
    }

    if (di_codegen_emit_llvm_ir(program, options->input_path) != 0) {
        di_ast_program_free(program);
        return 1;
    }

    if (di_codegen_build_native(program, options->input_path, options->run_after_build) != 0) {
        di_ast_program_free(program);
        return 1;
    }

    if (options->emit_ir) {
        di_info("emit-ir requested");
    }

    di_ast_program_free(program);
    return 0;
}

#include "di.h"

#include "codegen_llvm.h"
#include "diag.h"
#include "ir.h"
#include "lexer.h"
#include "parser.h"
#include "sema.h"
#include "token.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>

#ifndef DI_STDLIB_DIR
#define DI_STDLIB_DIR "."
#endif

typedef struct {
    char **items;
    size_t count;
} PathList;

typedef enum {
    DI_PACKAGE_APP = 0,
    DI_PACKAGE_LIB,
    DI_PACKAGE_KERNEL
} DiPackageKind;

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

typedef struct {
    char *name;
    char *kind;
    char *entry;
    char **dep_names;
    char **dep_paths;
    size_t dep_count;
} PackageManifest;

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

static char *trim_in_place(char *text) {
    char *end;
    while (*text == ' ' || *text == '\t' || *text == '\r' || *text == '\n') {
        text++;
    }
    end = text + strlen(text);
    while (end > text &&
           (end[-1] == ' ' || end[-1] == '\t' || end[-1] == '\r' || end[-1] == '\n')) {
        end--;
    }
    *end = '\0';
    return text;
}

static int path_is_directory(const char *path) {
    struct stat info;
    if (stat(path, &info) != 0) {
        return 0;
    }
    return S_ISDIR(info.st_mode);
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

static int file_exists(const char *path) {
    FILE *file = fopen(path, "rb");
    if (file == NULL) {
        return 0;
    }
    fclose(file);
    return 1;
}

static void package_manifest_free(PackageManifest *manifest) {
    size_t i;
    if (manifest == NULL) {
        return;
    }
    free(manifest->name);
    free(manifest->kind);
    free(manifest->entry);
    for (i = 0; i < manifest->dep_count; ++i) {
        free(manifest->dep_names[i]);
        free(manifest->dep_paths[i]);
    }
    free(manifest->dep_names);
    free(manifest->dep_paths);
}

static DiPackageKind package_kind_from_text(const char *kind) {
    if (strcmp(kind, "lib") == 0) {
        return DI_PACKAGE_LIB;
    }
    if (strcmp(kind, "kernel") == 0) {
        return DI_PACKAGE_KERNEL;
    }
    return DI_PACKAGE_APP;
}

static int package_manifest_add_dep(PackageManifest *manifest, const char *name, const char *path) {
    char **names;
    char **paths;
    char *name_copy;
    char *path_copy;

    name_copy = di_ast_strdup_range(name, (int)strlen(name));
    path_copy = di_ast_strdup_range(path, (int)strlen(path));
    if (name_copy == NULL || path_copy == NULL) {
        free(name_copy);
        free(path_copy);
        return 0;
    }

    names = (char **)realloc(manifest->dep_names, sizeof(char *) * (manifest->dep_count + 1));
    if (names == NULL) {
        free(name_copy);
        free(path_copy);
        return 0;
    }
    manifest->dep_names = names;
    paths = (char **)realloc(manifest->dep_paths, sizeof(char *) * (manifest->dep_count + 1));
    if (paths == NULL) {
        free(name_copy);
        free(path_copy);
        return 0;
    }
    manifest->dep_paths = paths;
    manifest->dep_names[manifest->dep_count] = name_copy;
    manifest->dep_paths[manifest->dep_count] = path_copy;
    manifest->dep_count++;
    return 1;
}

static int package_manifest_read(const char *target_dir, PackageManifest *manifest) {
    char manifest_path[1024];
    FILE *file;
    char line[512];

    memset(manifest, 0, sizeof(*manifest));
    snprintf(manifest_path, sizeof(manifest_path), "%s/di.mod", target_dir);
    file = fopen(manifest_path, "rb");
    if (file == NULL) {
        di_error("missing package manifest: %s", manifest_path);
        return 0;
    }

    while (fgets(line, sizeof(line), file) != NULL) {
        char *trimmed = trim_in_place(line);
        char *equals;
        char *key;
        char *value;
        size_t len;

        if (*trimmed == '\0' || *trimmed == '#') {
            continue;
        }
        equals = strchr(trimmed, '=');
        if (equals == NULL) {
            continue;
        }
        *equals = '\0';
        key = trim_in_place(trimmed);
        value = trim_in_place(equals + 1);
        len = strlen(value);
        if (len >= 2 && value[0] == '"' && value[len - 1] == '"') {
            value[len - 1] = '\0';
            value++;
        }

        if (strcmp(key, "name") == 0) {
            free(manifest->name);
            manifest->name = di_ast_strdup_range(value, (int)strlen(value));
        } else if (strcmp(key, "kind") == 0) {
            free(manifest->kind);
            manifest->kind = di_ast_strdup_range(value, (int)strlen(value));
        } else if (strcmp(key, "entry") == 0) {
            free(manifest->entry);
            manifest->entry = di_ast_strdup_range(value, (int)strlen(value));
        } else if (strncmp(key, "dep.", 4) == 0) {
            if (!package_manifest_add_dep(manifest, key + 4, value)) {
                fclose(file);
                package_manifest_free(manifest);
                return 0;
            }
        }
    }

    fclose(file);
    if (manifest->name == NULL || manifest->kind == NULL || manifest->entry == NULL) {
        di_error("package manifest %s must define name, kind, and entry", manifest_path);
        package_manifest_free(manifest);
        return 0;
    }
    if (strcmp(manifest->kind, "app") != 0 &&
        strcmp(manifest->kind, "lib") != 0 &&
        strcmp(manifest->kind, "kernel") != 0) {
        di_error("package manifest %s has invalid kind '%s'", manifest_path, manifest->kind);
        package_manifest_free(manifest);
        return 0;
    }
    return 1;
}

static int find_package_root(const char *path, char *root_path, size_t root_path_size) {
    char current[1024];
    char manifest_path[1060];

    snprintf(current, sizeof(current), "%s", path);
    while (1) {
        snprintf(manifest_path, sizeof(manifest_path), "%s/di.mod", current);
        if (file_exists(manifest_path)) {
            snprintf(root_path, root_path_size, "%s", current);
            return 1;
        }
        dirname_of(current, current, sizeof(current));
        if (strcmp(current, ".") == 0 || strcmp(current, "/") == 0) {
            break;
        }
    }
    return 0;
}

static int resolve_package_import(char *out,
                                  size_t out_size,
                                  const char *base_dir,
                                  const char *import_path) {
    char package_root[1024];
    PackageManifest manifest;
    const char *remainder;
    size_t i;

    if (strncmp(import_path, "pkg/", 4) != 0) {
        return 0;
    }
    if (!find_package_root(base_dir, package_root, sizeof(package_root))) {
        di_error("package import '%s' requires a package root with di.mod", import_path);
        return -1;
    }
    if (!package_manifest_read(package_root, &manifest)) {
        return -1;
    }

    remainder = import_path + 4;
    for (i = 0; i < manifest.dep_count; ++i) {
        size_t name_len = strlen(manifest.dep_names[i]);
        if (strncmp(remainder, manifest.dep_names[i], name_len) == 0 &&
            (remainder[name_len] == '\0' || remainder[name_len] == '/')) {
            char dep_root[1024];
            join_path(dep_root, sizeof(dep_root), package_root, manifest.dep_paths[i]);
            if (remainder[name_len] == '\0') {
                PackageManifest dep_manifest;
                int ok = package_manifest_read(dep_root, &dep_manifest);
                if (!ok) {
                    package_manifest_free(&manifest);
                    return -1;
                }
                join_path(out, out_size, dep_root, dep_manifest.entry);
                package_manifest_free(&dep_manifest);
            } else {
                join_path(out, out_size, dep_root, remainder + name_len + 1);
            }
            package_manifest_free(&manifest);
            return 1;
        }
    }

    di_error("unknown package dependency in import '%s'", import_path);
    package_manifest_free(&manifest);
    return -1;
}

static void resolve_import_path(char *out, size_t out_size, const char *base_dir, const char *import_path) {
    const char *stdlib_root = getenv("DI_STDLIB_DIR");
    int package_result;

    if (stdlib_root == NULL || stdlib_root[0] == '\0') {
        stdlib_root = DI_STDLIB_DIR;
    }

    if (strncmp(import_path, "std/", 4) == 0) {
        join_path(out, out_size, stdlib_root, import_path);
        if (file_exists(out)) {
            return;
        }
    }

    package_result = resolve_package_import(out, out_size, base_dir, import_path);
    if (package_result == 1) {
        return;
    }
    if (package_result < 0) {
        out[0] = '\0';
        return;
    }

    join_path(out, out_size, base_dir, import_path);
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
        resolve_import_path(resolved_path, sizeof(resolved_path), directory, file_program->imports[i]);
        if (resolved_path[0] == '\0') {
            di_ast_program_free(file_program);
            path_list_pop(loading);
            return 0;
        }
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

static int resolve_build_target(const char *target_path,
                                char *entry_path,
                                size_t entry_path_size,
                                DiPackageKind *package_kind) {
    PackageManifest manifest;

    if (!path_is_directory(target_path)) {
        snprintf(entry_path, entry_path_size, "%s", target_path);
        if (package_kind != NULL) {
            *package_kind = DI_PACKAGE_APP;
        }
        return 1;
    }

    if (!package_manifest_read(target_path, &manifest)) {
        return 0;
    }
    join_path(entry_path, entry_path_size, target_path, manifest.entry);
    if (package_kind != NULL) {
        *package_kind = package_kind_from_text(manifest.kind);
    }
    package_manifest_free(&manifest);
    return 1;
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
    char manifest[512];
    const char *name = options->project_name != NULL ? options->project_name : "app";
    const char *entry_rel = options->project_is_kernel ? "src/boot.di" :
                            options->project_is_library ? "src/lib.di" :
                            "src/main.di";
    const char *kind = options->project_is_kernel ? "kernel" :
                       options->project_is_library ? "lib" :
                       "app";
    const char *main_source =
        "import \"std/io.di\"\n"
        "import \"std/int.di\"\n"
        "\n"
        "func banner(title: str): int {\n"
        "    stdout(title)\n"
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
        "    print_int(gcd(total, 10))\n"
        "    return 0\n"
        "}\n";
    const char *lib_source =
        "import \"std/int.di\"\n"
        "\n"
        "func double_int(x: int): int {\n"
        "    return x + x\n"
        "}\n";
    const char *kernel_source =
        "func kmain(): int {\n"
        "    var boot_magic = 42\n"
        "    return boot_magic\n"
        "}\n";

    snprintf(command, sizeof(command), "mkdir -p \"%s\"", name);
    if (system(command) != 0) {
        di_error("failed to create project directory: %s", name);
        return 1;
    }

    snprintf(command, sizeof(command), "mkdir -p \"%s/src\"", name);
    if (system(command) != 0) {
        di_error("failed to create src directory: %s/src", name);
        return 1;
    }

    snprintf(path, sizeof(path), "%s/di.mod", name);
    snprintf(manifest, sizeof(manifest),
             "name = \"%s\"\n"
             "kind = \"%s\"\n"
             "entry = \"%s\"\n",
             name,
             kind,
             entry_rel);
    if (write_text_file(path, manifest) != 0) {
        return 1;
    }

    snprintf(path, sizeof(path), "%s/%s", name, entry_rel);
    if (write_text_file(path,
                        options->project_is_kernel ? kernel_source :
                        options->project_is_library ? lib_source :
                        main_source) != 0) {
        return 1;
    }

    snprintf(path, sizeof(path), "%s/.gitignore", name);
    snprintf(gitignore, sizeof(gitignore), "build/\n*.ll\n*.c\n");
    if (write_text_file(path, gitignore) != 0) {
        return 1;
    }

    snprintf(path, sizeof(path), "%s/README.md", name);
    if (options->project_is_kernel) {
        snprintf(readme, sizeof(readme),
                 "# %s\n\n"
                 "This kernel package was generated by `di new --kernel`.\n\n"
                 "It builds as a freestanding object through the current Di toolchain.\n\n"
                 "## Validate\n\n"
                 "```sh\n"
                 "di check .\n"
                 "di emit-ir .\n"
                 "di build .\n"
                 "```\n",
                 name);
    } else if (options->project_is_library) {
        snprintf(readme, sizeof(readme),
                 "# %s\n\n"
                 "This library package was generated by `di new --lib`.\n\n"
                 "Source files use the `.di` extension, and package metadata lives in `di.mod`.\n\n"
                 "## Validate\n\n"
                 "```sh\n"
                 "di check .\n"
                 "di emit-ir .\n"
                 "```\n",
                 name);
    } else {
        snprintf(readme, sizeof(readme),
                 "# %s\n\n"
                 "This app package was generated by `di new`.\n\n"
                 "Source files use the `.di` extension, and package metadata lives in `di.mod`.\n\n"
                 "## Run\n\n"
                 "```sh\n"
                 "di run .\n"
                 "```\n"
                 "\n"
                 "## Build\n\n"
                 "```sh\n"
                 "di check .\n"
                 "di build .\n"
                 "di emit-ir .\n"
                 "```\n"
                 "\n"
                 "## Watch\n\n"
                 "```sh\n"
                 "di watch .\n"
                 "```\n",
                 name);
    }
    if (write_text_file(path, readme) != 0) {
        return 1;
    }

    di_info("created %s package '%s' with entry file %s/%s",
            options->project_is_kernel ? "kernel" :
            options->project_is_library ? "library" : "app",
            name,
            name,
            entry_rel);
    return 0;
}

int di_driver_run(const DiOptions *options) {
    DiAstProgram *program;
    DiIrProgram *ir_program;
    char resolved_target[1024];
    DiPackageKind package_kind = DI_PACKAGE_APP;

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

    if (!resolve_build_target(options->input_path, resolved_target, sizeof(resolved_target), &package_kind)) {
        return 1;
    }

    program = load_compilation_unit(resolved_target);
    if (program == NULL) {
        return 1;
    }

    if (options->emit_tokens) {
        char *source = read_file(resolved_target);
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

    if (di_sema_check_program(program, package_kind == DI_PACKAGE_APP) != 0) {
        di_ast_program_free(program);
        return 1;
    }

    if (options->command == DI_CMD_CHECK) {
        di_info("check succeeded for %s", options->input_path);
        di_ast_program_free(program);
        return 0;
    }

    ir_program = di_ir_lower_program(program);
    if (ir_program == NULL) {
        di_ast_program_free(program);
        return 1;
    }

    if (di_codegen_emit_llvm_ir(ir_program, resolved_target) != 0) {
        di_ir_program_free(ir_program);
        di_ast_program_free(program);
        return 1;
    }

    if (package_kind != DI_PACKAGE_APP) {
        if (options->run_after_build) {
            di_error("cannot run non-app package: %s", options->input_path);
            di_ir_program_free(ir_program);
            di_ast_program_free(program);
            return 1;
        }
        if (package_kind == DI_PACKAGE_KERNEL) {
            if (di_codegen_build_native(ir_program, resolved_target, 0, DI_CODEGEN_FREESTANDING) != 0) {
                di_ir_program_free(ir_program);
                di_ast_program_free(program);
                return 1;
            }
            di_info("built kernel package object for %s", options->input_path);
        } else {
            di_info("built library package IR for %s", options->input_path);
        }
        di_ir_program_free(ir_program);
        di_ast_program_free(program);
        return 0;
    }

    if (di_codegen_build_native(ir_program, resolved_target, options->run_after_build, DI_CODEGEN_HOSTED) != 0) {
        di_ir_program_free(ir_program);
        di_ast_program_free(program);
        return 1;
    }

    if (options->emit_ir) {
        di_info("emit-ir requested");
    }

    di_ir_program_free(ir_program);
    di_ast_program_free(program);
    return 0;
}

#include "di.h"

#include "diag.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#ifdef _WIN32
#include <sys/stat.h>
#include <windows.h>
#else
#include <sys/stat.h>
#include <unistd.h>
#endif

static void print_usage(void) {
    fprintf(stderr,
            "usage:\n"
            "  di <file.di|package-dir>\n"
            "  di <build|run|emit-ir|check|watch> <file.di|package-dir> [--ast] [--tokens] [-- <program args...>]\n"
            "  di new <project-name> [--lib|--kernel]\n");
}

static int has_di_extension(const char *path) {
    size_t len;

    if (path == NULL) {
        return 0;
    }
    len = strlen(path);
    return len >= 3 && strcmp(path + len - 3, ".di") == 0;
}

static long long file_mtime(const char *path) {
    struct stat info;
    if (stat(path, &info) != 0) {
        return -1;
    }
#ifdef _WIN32
    return (long long)info.st_mtime;
#else
    return (long long)info.st_mtim.tv_sec * 1000000000LL + (long long)info.st_mtim.tv_nsec;
#endif
}

static int path_is_directory(const char *path) {
    struct stat info;
    if (stat(path, &info) != 0) {
        return 0;
    }
#ifdef _WIN32
    return (info.st_mode & _S_IFDIR) != 0;
#else
    return S_ISDIR(info.st_mode);
#endif
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

static int read_manifest_entry_path(const char *target, char *buffer, size_t buffer_size) {
    char manifest_path[512];
    FILE *file;
    char line[512];

    if (!path_is_directory(target)) {
        snprintf(buffer, buffer_size, "%s", target);
        return 1;
    }

    snprintf(manifest_path, sizeof(manifest_path), "%s/di.mod", target);
    file = fopen(manifest_path, "rb");
    if (file == NULL) {
        return 0;
    }

    while (fgets(line, sizeof(line), file) != NULL) {
        char *trimmed = trim_in_place(line);
        char *equals;
        if (*trimmed == '\0' || *trimmed == '#') {
            continue;
        }
        equals = strchr(trimmed, '=');
        if (equals == NULL) {
            continue;
        }
        *equals = '\0';
        if (strcmp(trim_in_place(trimmed), "entry") == 0) {
            char *value = trim_in_place(equals + 1);
            size_t len = strlen(value);
            if (len >= 2 && value[0] == '"' && value[len - 1] == '"') {
                value[len - 1] = '\0';
                value++;
            }
            if (strcmp(target, ".") == 0) {
                snprintf(buffer, buffer_size, "%s", value);
            } else {
                snprintf(buffer, buffer_size, "%s/%s", target, value);
            }
            fclose(file);
            return 1;
        }
    }

    fclose(file);
    return 0;
}

static void di_sleep_ms(int ms) {
#ifdef _WIN32
    Sleep((DWORD)ms);
#else
    usleep((useconds_t)(ms * 1000));
#endif
}

static int run_watch_loop(DiOptions *options) {
    long long last_seen;
    int first_build = 1;
    char watched_path[512];

    if (options->input_path == NULL) {
        di_error("watch requires an input file");
        return 1;
    }

    if (!read_manifest_entry_path(options->input_path, watched_path, sizeof(watched_path))) {
        di_error("watch could not resolve target: %s", options->input_path);
        return 1;
    }

    last_seen = file_mtime(watched_path);
    if (last_seen < 0) {
        di_error("could not stat watched file: %s", watched_path);
        return 1;
    }

    options->run_after_build = 1;
    options->command = DI_CMD_RUN;
    di_info("watching %s", watched_path);

    for (;;) {
        long long current = file_mtime(watched_path);
        if (current < 0) {
            di_error("could not stat watched file: %s", watched_path);
            return 1;
        }
        if (first_build || current != last_seen) {
            if (!first_build) {
                di_info("change detected, rebuilding");
            }
            last_seen = current;
            first_build = 0;
            (void)di_driver_run(options);
        }
        di_sleep_ms(700);
    }
}

int main(int argc, char **argv) {
    DiOptions options;
    int watch_mode = 0;

    if (argc < 2) {
        print_usage();
        return 1;
    }

    memset(&options, 0, sizeof(options));
    options.command = DI_CMD_BUILD;

    if (argc == 2 && (has_di_extension(argv[1]) || path_is_directory(argv[1]))) {
        options.command = DI_CMD_RUN;
        options.input_path = argv[1];
        options.run_after_build = 1;
        return di_driver_run(&options);
    }

    if (strcmp(argv[1], "new") == 0) {
        if (argc < 3) {
            di_error("new requires a project name");
            return 1;
        }
        options.command = DI_CMD_NEW;
        options.project_name = argv[2];
        for (int i = 3; i < argc; ++i) {
            if (strcmp(argv[i], "--lib") == 0) {
                options.project_is_library = 1;
            } else if (strcmp(argv[i], "--kernel") == 0) {
                options.project_is_kernel = 1;
            } else {
                di_error("unknown flag for new: %s", argv[i]);
                return 1;
            }
        }
        if (options.project_is_library && options.project_is_kernel) {
            di_error("new can use only one of --lib or --kernel");
            return 1;
        }
        return di_driver_run(&options);
    }

    if (argc < 3) {
        print_usage();
        return 1;
    }

    options.input_path = argv[2];
    if (!has_di_extension(options.input_path) && !path_is_directory(options.input_path)) {
        di_error("di expects a .di source file or package directory: %s", options.input_path);
        return 1;
    }

    if (strcmp(argv[1], "run") == 0) {
        options.command = DI_CMD_RUN;
        options.run_after_build = 1;
    } else if (strcmp(argv[1], "emit-ir") == 0) {
        options.command = DI_CMD_EMIT_IR;
        options.emit_ir = 1;
    } else if (strcmp(argv[1], "check") == 0) {
        options.command = DI_CMD_CHECK;
    } else if (strcmp(argv[1], "watch") == 0) {
        watch_mode = 1;
        options.command = DI_CMD_RUN;
        options.run_after_build = 1;
    } else if (strcmp(argv[1], "build") != 0) {
        di_error("unknown command: %s", argv[1]);
        print_usage();
        return 1;
    }

    {
        int i = 3;
        while (i < argc) {
            if (strcmp(argv[i], "--") == 0) {
                i++;
                options.run_argv = (const char **)&argv[i];
                options.run_argc = argc - i;
                break;
            }
            if (strcmp(argv[i], "--ast") == 0) {
                options.emit_ast = 1;
            } else if (strcmp(argv[i], "--tokens") == 0) {
                options.emit_tokens = 1;
            } else {
                di_error("unknown flag: %s", argv[i]);
                return 1;
            }
            i++;
        }
    }

    if (watch_mode) {
        return run_watch_loop(&options);
    }

    return di_driver_run(&options);
}

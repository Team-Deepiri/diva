#include "diri.h"

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
            "  diri <file.di>\n"
            "  diri <build|run|emit-ir|watch> <file.di> [--ast] [--tokens]\n"
            "  diri new <project-name>\n");
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

static void diri_sleep_ms(int ms) {
#ifdef _WIN32
    Sleep((DWORD)ms);
#else
    usleep((useconds_t)(ms * 1000));
#endif
}

static int run_watch_loop(DiriOptions *options) {
    long long last_seen;
    int first_build = 1;

    if (options->input_path == NULL) {
        diri_error("watch requires an input file");
        return 1;
    }

    last_seen = file_mtime(options->input_path);
    if (last_seen < 0) {
        diri_error("could not stat watched file: %s", options->input_path);
        return 1;
    }

    options->run_after_build = 1;
    options->command = DIRI_CMD_RUN;
    diri_info("watching %s", options->input_path);

    for (;;) {
        long long current = file_mtime(options->input_path);
        if (current < 0) {
            diri_error("could not stat watched file: %s", options->input_path);
            return 1;
        }
        if (first_build || current != last_seen) {
            if (!first_build) {
                diri_info("change detected, rebuilding");
            }
            last_seen = current;
            first_build = 0;
            (void)diri_driver_run(options);
        }
        diri_sleep_ms(700);
    }
}

int main(int argc, char **argv) {
    DiriOptions options;
    int watch_mode = 0;

    if (argc < 2) {
        print_usage();
        return 1;
    }

    memset(&options, 0, sizeof(options));
    options.command = DIRI_CMD_BUILD;

    if (argc == 2 && has_di_extension(argv[1])) {
        options.command = DIRI_CMD_RUN;
        options.input_path = argv[1];
        options.run_after_build = 1;
        return diri_driver_run(&options);
    }

    if (strcmp(argv[1], "new") == 0) {
        if (argc < 3) {
            diri_error("new requires a project name");
            return 1;
        }
        options.command = DIRI_CMD_NEW;
        options.project_name = argv[2];
        return diri_driver_run(&options);
    }

    if (argc < 3) {
        print_usage();
        return 1;
    }

    options.input_path = argv[2];
    if (!has_di_extension(options.input_path)) {
        diri_error("diri expects a .di source file: %s", options.input_path);
        return 1;
    }

    if (strcmp(argv[1], "run") == 0) {
        options.command = DIRI_CMD_RUN;
        options.run_after_build = 1;
    } else if (strcmp(argv[1], "emit-ir") == 0) {
        options.command = DIRI_CMD_EMIT_IR;
        options.emit_ir = 1;
    } else if (strcmp(argv[1], "watch") == 0) {
        watch_mode = 1;
        options.command = DIRI_CMD_RUN;
        options.run_after_build = 1;
    } else if (strcmp(argv[1], "build") != 0) {
        diri_error("unknown command: %s", argv[1]);
        print_usage();
        return 1;
    }

    for (int i = 3; i < argc; ++i) {
        if (strcmp(argv[i], "--ast") == 0) {
            options.emit_ast = 1;
        } else if (strcmp(argv[i], "--tokens") == 0) {
            options.emit_tokens = 1;
        } else {
            diri_error("unknown flag: %s", argv[i]);
            return 1;
        }
    }

    if (watch_mode) {
        return run_watch_loop(&options);
    }

    return diri_driver_run(&options);
}

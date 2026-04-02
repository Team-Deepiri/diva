#ifndef DI_H
#define DI_H

typedef enum {
    DI_CMD_BUILD = 0,
    DI_CMD_RUN,
    DI_CMD_EMIT_IR,
    DI_CMD_NEW
} DiCommand;

typedef struct {
    DiCommand command;
    const char *input_path;
    const char *project_name;
    int emit_tokens;
    int emit_ast;
    int emit_ir;
    int run_after_build;
} DiOptions;

int di_driver_run(const DiOptions *options);

#endif

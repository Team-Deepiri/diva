#ifndef DIRI_H
#define DIRI_H

typedef enum {
    DIRI_CMD_BUILD = 0,
    DIRI_CMD_RUN,
    DIRI_CMD_EMIT_IR,
    DIRI_CMD_NEW
} DiriCommand;

typedef struct {
    DiriCommand command;
    const char *input_path;
    const char *project_name;
    int emit_tokens;
    int emit_ast;
    int emit_ir;
    int run_after_build;
} DiriOptions;

int diri_driver_run(const DiriOptions *options);

#endif

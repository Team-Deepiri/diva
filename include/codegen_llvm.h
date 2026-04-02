#ifndef DI_CODEGEN_LLVM_H
#define DI_CODEGEN_LLVM_H

#include "ir.h"

#define DI_CODEGEN_HOSTED 0
#define DI_CODEGEN_FREESTANDING 1

int di_codegen_emit_llvm_ir(const DiIrProgram *program, const char *input_path);
int di_codegen_build_native(const DiIrProgram *program, const char *input_path, int run_after_build, int codegen_mode,
                            const char **run_argv, int run_argc);

#endif

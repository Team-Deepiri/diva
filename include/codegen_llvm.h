#ifndef DI_CODEGEN_LLVM_H
#define DI_CODEGEN_LLVM_H

#include "ir.h"

int di_codegen_emit_llvm_ir(const DiIrProgram *program, const char *input_path);
int di_codegen_build_native(const DiIrProgram *program, const char *input_path, int run_after_build);

#endif

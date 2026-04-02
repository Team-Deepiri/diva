#ifndef DI_CODEGEN_LLVM_H
#define DI_CODEGEN_LLVM_H

#include "ast.h"

int di_codegen_emit_llvm_ir(const DiAstProgram *program, const char *input_path);
int di_codegen_build_native(const DiAstProgram *program, const char *input_path, int run_after_build);

#endif

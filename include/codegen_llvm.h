#ifndef DIRI_CODEGEN_LLVM_H
#define DIRI_CODEGEN_LLVM_H

#include "ast.h"

int diri_codegen_emit_llvm_ir(const DiriAstProgram *program, const char *input_path);
int diri_codegen_build_native(const DiriAstProgram *program, const char *input_path, int run_after_build);

#endif

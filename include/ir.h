#ifndef DI_IR_H
#define DI_IR_H

#include "ast.h"

typedef enum {
    DI_IR_STRUCT_DECL = 0,
    DI_IR_FUNCTION,
    DI_IR_EXTERN_FUNCTION
} DiIrDeclKind;

typedef struct {
    const char *name;
    const char *type_name;
} DiIrField;

typedef struct {
    const char *name;
    const char *type_name;
} DiIrParam;

typedef struct {
    const char *param_name;
    const char *type_name;
} DiIrGenericBinding;

typedef struct {
    DiIrDeclKind kind;
    const char *name;
    const char *owner_type;
    const char *symbol_name;
    const char *return_type;
    DiIrField *fields;
    size_t field_count;
    DiIrParam *params;
    size_t param_count;
    DiIrGenericBinding *generic_bindings;
    size_t generic_binding_count;
    DiAstStmt **body;
    size_t body_count;
} DiIrDecl;

typedef struct {
    const char *package_name;
    const char *source_path;
    DiIrDecl *decls;
    size_t decl_count;
} DiIrProgram;

DiIrProgram *di_ir_lower_program(const DiAstProgram *program);
void di_ir_program_free(DiIrProgram *program);

#endif

#include "ir.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static char *di_ir_strdup(const char *text) {
    size_t len;
    char *copy;

    if (text == NULL) {
        return NULL;
    }
    len = strlen(text);
    copy = (char *)malloc(len + 1);
    if (copy == NULL) {
        return NULL;
    }
    memcpy(copy, text, len + 1);
    return copy;
}

static const char *map_runtime_symbol(const char *name) {
    if (strcmp(name, "print_int") == 0) return "di_runtime_print_int";
    if (strcmp(name, "print_str") == 0) return "di_runtime_print_str";
    return name;
}

static char *make_symbol_name(const DiAstDecl *decl) {
    char buffer[256];

    if (decl->owner_type == NULL) {
        return di_ir_strdup(map_runtime_symbol(decl->name));
    }

    snprintf(buffer, sizeof(buffer), "%s_%s", decl->owner_type, decl->name);
    return di_ir_strdup(buffer);
}

DiIrProgram *di_ir_lower_program(const DiAstProgram *program) {
    DiIrProgram *ir_program;
    size_t i;

    if (program == NULL) {
        return NULL;
    }

    ir_program = (DiIrProgram *)calloc(1, sizeof(DiIrProgram));
    if (ir_program == NULL) {
        return NULL;
    }

    ir_program->package_name = di_ir_strdup(program->package_name);
    ir_program->source_path = di_ir_strdup(program->source_path);
    ir_program->decl_count = program->decl_count;
    if (program->decl_count != 0) {
        ir_program->decls = (DiIrDecl *)calloc(program->decl_count, sizeof(DiIrDecl));
        if (ir_program->decls == NULL) {
            di_ir_program_free(ir_program);
            return NULL;
        }
    }

    for (i = 0; i < program->decl_count; ++i) {
        const DiAstDecl *decl = program->decls[i];
        DiIrDecl *ir_decl = &ir_program->decls[i];
        size_t j;

        ir_decl->kind = decl->kind == DI_AST_STRUCT_DECL ? DI_IR_STRUCT_DECL :
                        decl->kind == DI_AST_EXTERN_FUNCTION ? DI_IR_EXTERN_FUNCTION :
                        DI_IR_FUNCTION;
        ir_decl->name = di_ir_strdup(decl->name);
        ir_decl->owner_type = di_ir_strdup(decl->owner_type);
        ir_decl->symbol_name = make_symbol_name(decl);
        ir_decl->return_type = di_ir_strdup(decl->return_type.name);
        ir_decl->field_count = decl->field_count;
        ir_decl->param_count = decl->param_count;
        ir_decl->body = decl->body;
        ir_decl->body_count = decl->body_count;

        if ((decl->field_count != 0 && ir_decl->symbol_name == NULL) ||
            (decl->kind != DI_AST_STRUCT_DECL && ir_decl->symbol_name == NULL) ||
            (decl->return_type.name != NULL && ir_decl->return_type == NULL) ||
            (decl->name != NULL && ir_decl->name == NULL)) {
            di_ir_program_free(ir_program);
            return NULL;
        }

        if (decl->field_count != 0) {
            ir_decl->fields = (DiIrField *)calloc(decl->field_count, sizeof(DiIrField));
            if (ir_decl->fields == NULL) {
                di_ir_program_free(ir_program);
                return NULL;
            }
            for (j = 0; j < decl->field_count; ++j) {
                ir_decl->fields[j].name = di_ir_strdup(decl->fields[j].name);
                ir_decl->fields[j].type_name = di_ir_strdup(decl->fields[j].type.name);
                if (ir_decl->fields[j].name == NULL || ir_decl->fields[j].type_name == NULL) {
                    di_ir_program_free(ir_program);
                    return NULL;
                }
            }
        }

        if (decl->param_count != 0) {
            ir_decl->params = (DiIrParam *)calloc(decl->param_count, sizeof(DiIrParam));
            if (ir_decl->params == NULL) {
                di_ir_program_free(ir_program);
                return NULL;
            }
            for (j = 0; j < decl->param_count; ++j) {
                ir_decl->params[j].name = di_ir_strdup(decl->params[j].name);
                ir_decl->params[j].type_name = di_ir_strdup(decl->params[j].type.name);
                if (ir_decl->params[j].name == NULL || ir_decl->params[j].type_name == NULL) {
                    di_ir_program_free(ir_program);
                    return NULL;
                }
            }
        }
    }

    return ir_program;
}

void di_ir_program_free(DiIrProgram *program) {
    size_t i;
    size_t j;

    if (program == NULL) {
        return;
    }

    free((char *)program->package_name);
    free((char *)program->source_path);
    for (i = 0; i < program->decl_count; ++i) {
        DiIrDecl *decl = &program->decls[i];
        free((char *)decl->name);
        free((char *)decl->owner_type);
        free((char *)decl->symbol_name);
        free((char *)decl->return_type);
        for (j = 0; j < decl->field_count; ++j) {
            free((char *)decl->fields[j].name);
            free((char *)decl->fields[j].type_name);
        }
        free(decl->fields);
        for (j = 0; j < decl->param_count; ++j) {
            free((char *)decl->params[j].name);
            free((char *)decl->params[j].type_name);
        }
        free(decl->params);
    }
    free(program->decls);
    free(program);
}

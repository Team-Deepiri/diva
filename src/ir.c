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

static const DiAstDecl *find_generic_function(const DiAstProgram *program, const char *name) {
    size_t i;
    for (i = 0; i < program->decl_count; ++i) {
        const DiAstDecl *decl = program->decls[i];
        if ((decl->kind == DI_AST_FUNCTION || decl->kind == DI_AST_EXTERN_FUNCTION) &&
            decl->owner_type == NULL &&
            decl->generic_param_count != 0 &&
            strcmp(decl->name, name) == 0) {
            return decl;
        }
    }
    return NULL;
}

static const char *resolve_type_name(const DiAstDecl *decl,
                                     const char *type_name,
                                     const DiIrGenericBinding *bindings,
                                     size_t binding_count) {
    size_t i;
    size_t len;
    static char buffer[16][128];
    static int index = 0;

    for (i = 0; i < binding_count; ++i) {
        if (strcmp(bindings[i].param_name, type_name) == 0) {
            return bindings[i].type_name;
        }
    }

    len = strlen(type_name);
    if (len > 2 && strcmp(type_name + len - 2, "[]") == 0) {
        const char *elem;
        index = (index + 1) % 16;
        memcpy(buffer[index], type_name, len - 2);
        buffer[index][len - 2] = '\0';
        elem = resolve_type_name(decl, buffer[index], bindings, binding_count);
        snprintf(buffer[index], sizeof(buffer[index]), "%s[]", elem);
        return buffer[index];
    }

    (void)decl;
    return type_name;
}

static char *make_symbol_name(const DiAstDecl *decl,
                              const char *symbol_override,
                              const DiIrGenericBinding *bindings,
                              size_t binding_count) {
    char buffer[256];
    size_t i;

    if (symbol_override != NULL) {
        return di_ir_strdup(symbol_override);
    }
    if (decl->generic_param_count != 0) {
        size_t offset = 0;
        offset += (size_t)snprintf(buffer + offset, sizeof(buffer) - offset, "%s__", decl->name);
        for (i = 0; i < binding_count && offset + 1 < sizeof(buffer); ++i) {
            if (i != 0) {
                offset += (size_t)snprintf(buffer + offset, sizeof(buffer) - offset, "_");
            }
            offset += (size_t)snprintf(buffer + offset, sizeof(buffer) - offset, "%s", bindings[i].type_name);
        }
        return di_ir_strdup(buffer);
    }
    if (decl->owner_type == NULL && strcmp(decl->name, "main") == 0) {
        return di_ir_strdup("di_user_main");
    }
    if (decl->owner_type == NULL) {
        return di_ir_strdup(map_runtime_symbol(decl->name));
    }
    snprintf(buffer, sizeof(buffer), "%s_%s", decl->owner_type, decl->name);
    return di_ir_strdup(buffer);
}

static int add_ir_decl(DiIrProgram *program, DiIrDecl decl) {
    DiIrDecl *decls = (DiIrDecl *)realloc(program->decls, (program->decl_count + 1) * sizeof(DiIrDecl));
    if (decls == NULL) {
        return 0;
    }
    program->decls = decls;
    program->decls[program->decl_count++] = decl;
    return 1;
}

static const DiIrDecl *find_ir_decl_by_symbol(const DiIrProgram *program, const char *symbol_name) {
    size_t i;
    for (i = 0; i < program->decl_count; ++i) {
        if (program->decls[i].symbol_name != NULL &&
            strcmp(program->decls[i].symbol_name, symbol_name) == 0) {
            return &program->decls[i];
        }
    }
    return NULL;
}

static int lower_decl_copy(DiIrProgram *ir_program,
                           const DiAstDecl *decl,
                           const char *symbol_override,
                           const DiIrGenericBinding *bindings,
                           size_t binding_count) {
    DiIrDecl ir_decl;
    size_t j;

    memset(&ir_decl, 0, sizeof(ir_decl));
    ir_decl.kind = decl->kind == DI_AST_STRUCT_DECL ? DI_IR_STRUCT_DECL :
                   decl->kind == DI_AST_EXTERN_FUNCTION ? DI_IR_EXTERN_FUNCTION :
                   DI_IR_FUNCTION;
    ir_decl.name = di_ir_strdup(decl->name);
    ir_decl.owner_type = di_ir_strdup(decl->owner_type);
    ir_decl.symbol_name = make_symbol_name(decl, symbol_override, bindings, binding_count);
    if (decl->return_type.name != NULL) {
        ir_decl.return_type = di_ir_strdup(resolve_type_name(decl, decl->return_type.name, bindings, binding_count));
    }
    ir_decl.body = decl->body;
    ir_decl.body_count = decl->body_count;

    if (binding_count != 0) {
        ir_decl.generic_bindings = (DiIrGenericBinding *)calloc(binding_count, sizeof(DiIrGenericBinding));
        if (ir_decl.generic_bindings == NULL) {
            return 0;
        }
        ir_decl.generic_binding_count = binding_count;
        for (j = 0; j < binding_count; ++j) {
            ir_decl.generic_bindings[j].param_name = di_ir_strdup(bindings[j].param_name);
            ir_decl.generic_bindings[j].type_name = di_ir_strdup(bindings[j].type_name);
        }
    }

    if (decl->field_count != 0) {
        ir_decl.fields = (DiIrField *)calloc(decl->field_count, sizeof(DiIrField));
        if (ir_decl.fields == NULL) {
            return 0;
        }
        ir_decl.field_count = decl->field_count;
        for (j = 0; j < decl->field_count; ++j) {
            ir_decl.fields[j].name = di_ir_strdup(decl->fields[j].name);
            ir_decl.fields[j].type_name = di_ir_strdup(resolve_type_name(decl, decl->fields[j].type.name, bindings, binding_count));
        }
    }

    if (decl->param_count != 0) {
        ir_decl.params = (DiIrParam *)calloc(decl->param_count, sizeof(DiIrParam));
        if (ir_decl.params == NULL) {
            return 0;
        }
        ir_decl.param_count = decl->param_count;
        for (j = 0; j < decl->param_count; ++j) {
            ir_decl.params[j].name = di_ir_strdup(decl->params[j].name);
            ir_decl.params[j].type_name = di_ir_strdup(resolve_type_name(decl, decl->params[j].type.name, bindings, binding_count));
        }
    }

    return add_ir_decl(ir_program, ir_decl);
}

static int collect_generic_calls_expr(DiIrProgram *ir_program, const DiAstProgram *program, const DiAstExpr *expr);

static int collect_generic_calls_stmt(DiIrProgram *ir_program, const DiAstProgram *program, const DiAstStmt *stmt) {
    size_t i;

    if (stmt == NULL) {
        return 1;
    }

    switch (stmt->kind) {
        case DI_AST_VAR_STMT:
            return collect_generic_calls_expr(ir_program, program, stmt->as.var_stmt.value);
        case DI_AST_ASSIGN_STMT:
            return collect_generic_calls_expr(ir_program, program, stmt->as.assign_stmt.value);
        case DI_AST_FIELD_ASSIGN_STMT:
            return collect_generic_calls_expr(ir_program, program, stmt->as.field_assign_stmt.target) &&
                   collect_generic_calls_expr(ir_program, program, stmt->as.field_assign_stmt.value);
        case DI_AST_INDEX_ASSIGN_STMT:
            return collect_generic_calls_expr(ir_program, program, stmt->as.index_assign_stmt.target) &&
                   collect_generic_calls_expr(ir_program, program, stmt->as.index_assign_stmt.value);
        case DI_AST_RETURN_STMT:
            return collect_generic_calls_expr(ir_program, program, stmt->as.return_stmt.value);
        case DI_AST_EXPR_STMT:
            return collect_generic_calls_expr(ir_program, program, stmt->as.expr_stmt.expr);
        case DI_AST_IF_STMT:
            if (!collect_generic_calls_expr(ir_program, program, stmt->as.if_stmt.condition)) return 0;
            for (i = 0; i < stmt->as.if_stmt.then_block.count; ++i) {
                if (!collect_generic_calls_stmt(ir_program, program, stmt->as.if_stmt.then_block.items[i])) return 0;
            }
            for (i = 0; i < stmt->as.if_stmt.else_block.count; ++i) {
                if (!collect_generic_calls_stmt(ir_program, program, stmt->as.if_stmt.else_block.items[i])) return 0;
            }
            return 1;
        case DI_AST_WHILE_STMT:
            if (!collect_generic_calls_expr(ir_program, program, stmt->as.while_stmt.condition)) return 0;
            if (stmt->as.while_stmt.update != NULL &&
                !collect_generic_calls_stmt(ir_program, program, stmt->as.while_stmt.update)) return 0;
            for (i = 0; i < stmt->as.while_stmt.body.count; ++i) {
                if (!collect_generic_calls_stmt(ir_program, program, stmt->as.while_stmt.body.items[i])) return 0;
            }
            return 1;
        case DI_AST_FLUX_STMT:
            if (!collect_generic_calls_expr(ir_program, program, stmt->as.flux_stmt.iterable)) return 0;
            for (i = 0; i < stmt->as.flux_stmt.body.count; ++i) {
                if (!collect_generic_calls_stmt(ir_program, program, stmt->as.flux_stmt.body.items[i])) return 0;
            }
            return 1;
        default:
            return 1;
    }
}

static int collect_generic_calls_expr(DiIrProgram *ir_program, const DiAstProgram *program, const DiAstExpr *expr) {
    size_t i;

    if (expr == NULL) {
        return 1;
    }

    switch (expr->kind) {
        case DI_AST_CALL_EXPR:
            if (!collect_generic_calls_expr(ir_program, program, expr->as.call.callee)) return 0;
            for (i = 0; i < expr->as.call.arg_count; ++i) {
                if (!collect_generic_calls_expr(ir_program, program, expr->as.call.args[i])) return 0;
            }
            if (expr->as.call.generic_arg_count != 0 &&
                expr->as.call.callee->kind == DI_AST_IDENT_EXPR &&
                expr->as.call.resolved_name != NULL &&
                find_ir_decl_by_symbol(ir_program, expr->as.call.resolved_name) == NULL) {
                const DiAstDecl *target = find_generic_function(program, expr->as.call.callee->as.ident_name);
                if (target != NULL) {
                    DiIrGenericBinding *bindings = (DiIrGenericBinding *)calloc(expr->as.call.generic_arg_count,
                                                                               sizeof(DiIrGenericBinding));
                    if (bindings == NULL) {
                        return 0;
                    }
                    for (i = 0; i < expr->as.call.generic_arg_count; ++i) {
                        bindings[i].param_name = target->generic_params[i];
                        bindings[i].type_name = expr->as.call.generic_args[i].name;
                    }
                    if (!lower_decl_copy(ir_program, target, expr->as.call.resolved_name, bindings, expr->as.call.generic_arg_count)) {
                        free(bindings);
                        return 0;
                    }
                    free(bindings);
                    for (i = 0; i < target->body_count; ++i) {
                        if (!collect_generic_calls_stmt(ir_program, program, target->body[i])) {
                            return 0;
                        }
                    }
                }
            }
            return 1;
        case DI_AST_BINARY_EXPR:
            return collect_generic_calls_expr(ir_program, program, expr->as.binary.left) &&
                   collect_generic_calls_expr(ir_program, program, expr->as.binary.right);
        case DI_AST_UNARY_EXPR:
            return collect_generic_calls_expr(ir_program, program, expr->as.unary.operand);
        case DI_AST_FIELD_EXPR:
            return collect_generic_calls_expr(ir_program, program, expr->as.field.base);
        case DI_AST_STRUCT_INIT_EXPR:
            for (i = 0; i < expr->as.struct_init.field_count; ++i) {
                if (!collect_generic_calls_expr(ir_program, program, expr->as.struct_init.fields[i].value)) return 0;
            }
            return 1;
        case DI_AST_INDEX_EXPR:
            return collect_generic_calls_expr(ir_program, program, expr->as.index.base) &&
                   collect_generic_calls_expr(ir_program, program, expr->as.index.index);
        case DI_AST_ARRAY_INIT_EXPR:
            for (i = 0; i < expr->as.array_init.item_count; ++i) {
                if (!collect_generic_calls_expr(ir_program, program, expr->as.array_init.items[i])) return 0;
            }
            return 1;
        case DI_AST_RANGE_EXPR:
            return collect_generic_calls_expr(ir_program, program, expr->as.range.start) &&
                   collect_generic_calls_expr(ir_program, program, expr->as.range.end);
        default:
            return 1;
    }
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

    for (i = 0; i < program->decl_count; ++i) {
        const DiAstDecl *decl = program->decls[i];
        if (decl->kind == DI_AST_TRAIT_DECL || decl->kind == DI_AST_IMPL_DECL) {
            continue;
        }
        if (decl->generic_param_count != 0) {
            continue;
        }
        if (!lower_decl_copy(ir_program, decl, NULL, NULL, 0)) {
            di_ir_program_free(ir_program);
            return NULL;
        }
    }

    for (i = 0; i < ir_program->decl_count; ++i) {
        size_t j;
        for (j = 0; j < ir_program->decls[i].body_count; ++j) {
            if (!collect_generic_calls_stmt(ir_program, program, ir_program->decls[i].body[j])) {
                di_ir_program_free(ir_program);
                return NULL;
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
        for (j = 0; j < decl->generic_binding_count; ++j) {
            free((char *)decl->generic_bindings[j].param_name);
            free((char *)decl->generic_bindings[j].type_name);
        }
        free(decl->generic_bindings);
    }
    free(program->decls);
    free(program);
}

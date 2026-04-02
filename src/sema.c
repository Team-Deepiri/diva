#include "sema.h"

#include "diag.h"

#include <stddef.h>
#include <stdlib.h>
#include <string.h>

typedef struct {
    const char *name;
    const char *type_name;
} ScopeEntry;

typedef struct {
    ScopeEntry entries[256];
    size_t count;
} ScopeFrame;

typedef struct {
    ScopeFrame frames[64];
    size_t depth;
} ScopeStack;

static int same_name(const char *a, const char *b) {
    while (*a != '\0' && *b != '\0') {
        if (*a != *b) {
            return 0;
        }
        a++;
        b++;
    }
    return *a == '\0' && *b == '\0';
}

static const DiAstDecl *find_struct_decl(const DiAstProgram *program, const char *name) {
    size_t i;
    for (i = 0; i < program->decl_count; ++i) {
        if (program->decls[i]->kind == DI_AST_STRUCT_DECL && same_name(program->decls[i]->name, name)) {
            return program->decls[i];
        }
    }
    return NULL;
}

static const DiAstDecl *find_function_decl(const DiAstProgram *program, const char *name) {
    size_t i;
    for (i = 0; i < program->decl_count; ++i) {
        if ((program->decls[i]->kind == DI_AST_FUNCTION || program->decls[i]->kind == DI_AST_EXTERN_FUNCTION) &&
            program->decls[i]->owner_type == NULL &&
            same_name(program->decls[i]->name, name)) {
            return program->decls[i];
        }
    }
    return NULL;
}

static const DiAstDecl *find_trait_decl(const DiAstProgram *program, const char *name) {
    size_t i;
    for (i = 0; i < program->decl_count; ++i) {
        if (program->decls[i]->kind == DI_AST_TRAIT_DECL &&
            same_name(program->decls[i]->name, name)) {
            return program->decls[i];
        }
    }
    return NULL;
}

static const DiAstDecl *find_method_decl(const DiAstProgram *program, const char *owner_type, const char *name) {
    size_t i;
    for (i = 0; i < program->decl_count; ++i) {
        if ((program->decls[i]->kind == DI_AST_FUNCTION || program->decls[i]->kind == DI_AST_EXTERN_FUNCTION) &&
            program->decls[i]->owner_type != NULL &&
            same_name(program->decls[i]->owner_type, owner_type) &&
            same_name(program->decls[i]->name, name)) {
            return program->decls[i];
        }
    }
    return NULL;
}

static const DiAstField *find_struct_field(const DiAstDecl *decl, const char *field_name) {
    size_t i;
    for (i = 0; i < decl->field_count; ++i) {
        if (same_name(decl->fields[i].name, field_name)) {
            return &decl->fields[i];
        }
    }
    return NULL;
}

static void scope_push(ScopeStack *stack) {
    stack->frames[stack->depth].count = 0;
    stack->depth++;
}

static void scope_pop(ScopeStack *stack) {
    if (stack->depth != 0) {
        stack->depth--;
    }
}

static int scope_add(ScopeStack *stack, const char *name, const char *type_name) {
    ScopeFrame *frame;
    size_t i;

    if (stack->depth == 0) {
        return 0;
    }

    frame = &stack->frames[stack->depth - 1];
    for (i = 0; i < frame->count; ++i) {
        if (same_name(frame->entries[i].name, name)) {
            return 0;
        }
    }
    frame->entries[frame->count].name = name;
    frame->entries[frame->count].type_name = type_name;
    frame->count++;
    return 1;
}

static int scope_contains_current(const ScopeStack *stack, const char *name) {
    const ScopeFrame *frame;
    size_t i;

    if (stack->depth == 0) {
        return 0;
    }
    frame = &stack->frames[stack->depth - 1];
    for (i = 0; i < frame->count; ++i) {
        if (same_name(frame->entries[i].name, name)) {
            return 1;
        }
    }
    return 0;
}

static const char *scope_lookup(const ScopeStack *stack, const char *name) {
    size_t depth_index = stack->depth;
    while (depth_index > 0) {
        const ScopeFrame *frame = &stack->frames[depth_index - 1];
        size_t i = frame->count;
        while (i > 0) {
            if (same_name(frame->entries[i - 1].name, name)) {
                return frame->entries[i - 1].type_name;
            }
            i--;
        }
        depth_index--;
    }
    return NULL;
}

static int type_equals(const char *a, const char *b) {
    return same_name(a, b);
}

static int same_signature(const DiAstDecl *left, const DiAstDecl *right) {
    size_t i;
    if (left->kind != right->kind ||
        !type_equals(left->return_type.name, right->return_type.name) ||
        left->param_count != right->param_count ||
        left->generic_param_count != right->generic_param_count) {
        return 0;
    }
    for (i = 0; i < left->param_count; ++i) {
        if (!type_equals(left->params[i].type.name, right->params[i].type.name)) {
            return 0;
        }
    }
    for (i = 0; i < left->generic_param_count; ++i) {
        if (!same_name(left->generic_params[i], right->generic_params[i])) {
            return 0;
        }
    }
    return 1;
}

static int decl_has_generic_param(const DiAstDecl *decl, const char *name) {
    size_t i;
    if (decl == NULL) {
        return 0;
    }
    for (i = 0; i < decl->generic_param_count; ++i) {
        if (same_name(decl->generic_params[i], name)) {
            return 1;
        }
    }
    return 0;
}

static int is_reserved_c_identifier(const char *name) {
    static const char *reserved[] = {
        "auto", "break", "case", "char", "const", "continue", "default",
        "do", "double", "else", "enum", "extern", "float", "for", "goto",
        "if", "inline", "int", "long", "register", "restrict", "return",
        "short", "signed", "sizeof", "static", "struct", "switch", "typedef",
        "union", "unsigned", "void", "volatile", "while", "_Bool"
    };
    size_t i;
    for (i = 0; i < sizeof(reserved) / sizeof(reserved[0]); ++i) {
        if (same_name(name, reserved[i])) {
            return 1;
        }
    }
    return same_name(name, "di_runtime_print_int") || same_name(name, "di_runtime_print_str");
}

static int validate_identifier_name(const char *kind, const char *name, const char *context) {
    if (is_reserved_c_identifier(name)) {
        if (context != NULL) {
            di_error("%s '%s' in %s uses a reserved backend identifier", kind, name, context);
        } else {
            di_error("%s '%s' uses a reserved backend identifier", kind, name);
        }
        return 0;
    }
    return 1;
}

static int is_array_type(const char *type_name) {
    size_t len = strlen(type_name);
    return len > 2 && strcmp(type_name + len - 2, "[]") == 0;
}

static const char *array_element_type(const char *type_name) {
    static char buffer[64];
    size_t len = strlen(type_name);
    if (!is_array_type(type_name) || len - 2 >= sizeof(buffer)) {
        return NULL;
    }
    memcpy(buffer, type_name, len - 2);
    buffer[len - 2] = '\0';
    return buffer;
}

static int is_builtin_type(const char *type_name) {
    return type_equals(type_name, "int") ||
           type_equals(type_name, "bool") ||
           type_equals(type_name, "str") ||
           type_equals(type_name, "void") ||
           type_equals(type_name, "range");
}

static int type_exists(const DiAstProgram *program, const DiAstDecl *decl, const char *type_name) {
    const char *elem_type;
    if (is_builtin_type(type_name)) {
        return 1;
    }
    if (decl_has_generic_param(decl, type_name)) {
        return 1;
    }
    elem_type = array_element_type(type_name);
    if (elem_type != NULL) {
        return type_exists(program, decl, elem_type);
    }
    return find_struct_decl(program, type_name) != NULL;
}

static const char *resolve_decl_type(const DiAstDecl *decl,
                                     const char *type_name,
                                     const DiAstType *generic_args,
                                     size_t generic_arg_count) {
    size_t i;
    if (decl == NULL || generic_args == NULL) {
        return type_name;
    }
    for (i = 0; i < decl->generic_param_count && i < generic_arg_count; ++i) {
        if (same_name(decl->generic_params[i], type_name)) {
            return generic_args[i].name;
        }
    }
    return type_name;
}

static char *make_generic_symbol_name(const DiAstDecl *decl, const DiAstType *generic_args, size_t generic_arg_count) {
    size_t i;
    size_t size = strlen(decl->name) + 3;
    char *buffer;
    for (i = 0; i < generic_arg_count; ++i) {
        size += strlen(generic_args[i].name) + 2;
    }
    buffer = (char *)malloc(size);
    if (buffer == NULL) {
        return NULL;
    }
    buffer[0] = '\0';
    strcpy(buffer, decl->name);
    strcat(buffer, "__");
    for (i = 0; i < generic_arg_count; ++i) {
        if (i != 0) {
            strcat(buffer, "_");
        }
        strcat(buffer, generic_args[i].name);
    }
    return buffer;
}

static const char *check_expr(const DiAstProgram *program, DiAstExpr *expr, const DiAstDecl *decl, ScopeStack *scopes);
static int check_stmt_list(const DiAstProgram *program, DiAstStmt **items, size_t count, const DiAstDecl *decl, ScopeStack *scopes, int new_scope);

static const char *check_expr(const DiAstProgram *program, DiAstExpr *expr, const DiAstDecl *decl, ScopeStack *scopes) {
    size_t i;

    if (expr == NULL) {
        di_error("missing expression in function %s", decl->name);
        return NULL;
    }

    switch (expr->kind) {
        case DI_AST_INT_EXPR:
            expr->inferred_type = "int";
            return expr->inferred_type;
        case DI_AST_BOOL_EXPR:
            expr->inferred_type = "bool";
            return expr->inferred_type;
        case DI_AST_STRING_EXPR:
            expr->inferred_type = "str";
            return expr->inferred_type;
        case DI_AST_IDENT_EXPR: {
            const char *type_name = scope_lookup(scopes, expr->as.ident_name);
            if (type_name != NULL) {
                expr->inferred_type = type_name;
                return expr->inferred_type;
            }
            di_error("unknown identifier '%s' in function %s", expr->as.ident_name, decl->name);
            return NULL;
        }
        case DI_AST_UNARY_EXPR: {
            const char *operand_type = check_expr(program, expr->as.unary.operand, decl, scopes);
            if (operand_type == NULL) {
                return NULL;
            }
            if (!type_equals(operand_type, "bool") && !type_equals(operand_type, "int")) {
                di_error("operator ! requires bool or int");
                return NULL;
            }
            expr->inferred_type = "bool";
            return expr->inferred_type;
        }
        case DI_AST_FIELD_EXPR: {
            const char *base_type = check_expr(program, expr->as.field.base, decl, scopes);
            const DiAstDecl *struct_decl;
            const DiAstField *field;
            if (base_type == NULL) {
                return NULL;
            }
            struct_decl = find_struct_decl(program, base_type);
            if (struct_decl == NULL) {
                di_error("type '%s' does not have fields", base_type);
                return NULL;
            }
            field = find_struct_field(struct_decl, expr->as.field.field_name);
            if (field == NULL) {
                expr->inferred_type = "__method__";
                return expr->inferred_type;
            }
            expr->inferred_type = field->type.name;
            return expr->inferred_type;
        }
        case DI_AST_STRUCT_INIT_EXPR: {
            const DiAstDecl *struct_decl = find_struct_decl(program, expr->as.struct_init.type_name);
            if (struct_decl == NULL) {
                di_error("unknown struct type '%s'", expr->as.struct_init.type_name);
                return NULL;
            }
            for (i = 0; i < expr->as.struct_init.field_count; ++i) {
                const DiAstField *field = find_struct_field(struct_decl, expr->as.struct_init.fields[i].name);
                const char *value_type;
                if (field == NULL) {
                    di_error("struct '%s' has no field '%s'", struct_decl->name, expr->as.struct_init.fields[i].name);
                    return NULL;
                }
                value_type = check_expr(program, expr->as.struct_init.fields[i].value, decl, scopes);
                if (value_type == NULL || !type_equals(value_type, field->type.name)) {
                    di_error("initializer for %s.%s has wrong type", struct_decl->name, field->name);
                    return NULL;
                }
            }
            expr->inferred_type = struct_decl->name;
            return expr->inferred_type;
        }
        case DI_AST_ARRAY_INIT_EXPR: {
            const char *item_type = NULL;
            for (i = 0; i < expr->as.array_init.item_count; ++i) {
                const char *current = check_expr(program, expr->as.array_init.items[i], decl, scopes);
                if (current == NULL) {
                    return NULL;
                }
                if (item_type == NULL) {
                    item_type = current;
                } else if (!type_equals(item_type, current)) {
                    di_error("array literal has mixed element types");
                    return NULL;
                }
            }
            if (item_type == NULL) {
                item_type = "int";
            }
            if (type_equals(item_type, "int")) {
                expr->inferred_type = "int[]";
                return expr->inferred_type;
            }
            di_error("only int[] arrays are supported currently");
            return NULL;
        }
        case DI_AST_INDEX_EXPR: {
            const char *base_type = check_expr(program, expr->as.index.base, decl, scopes);
            const char *index_type = check_expr(program, expr->as.index.index, decl, scopes);
            const char *elem_type;
            if (base_type == NULL || index_type == NULL) {
                return NULL;
            }
            if (!type_equals(index_type, "int")) {
                di_error("array index must be int");
                return NULL;
            }
            elem_type = array_element_type(base_type);
            if (elem_type == NULL) {
                di_error("cannot index non-array type '%s'", base_type);
                return NULL;
            }
            expr->inferred_type = elem_type;
            return expr->inferred_type;
        }
        case DI_AST_RANGE_EXPR: {
            const char *start_type = check_expr(program, expr->as.range.start, decl, scopes);
            const char *end_type = check_expr(program, expr->as.range.end, decl, scopes);
            if (start_type == NULL || end_type == NULL) {
                return NULL;
            }
            if (!type_equals(start_type, "int") || !type_equals(end_type, "int")) {
                di_error("range bounds must be int");
                return NULL;
            }
            expr->inferred_type = "range";
            return expr->inferred_type;
        }
        case DI_AST_CALL_EXPR: {
            if (expr->as.call.callee->kind == DI_AST_IDENT_EXPR) {
                const DiAstDecl *target = find_function_decl(program, expr->as.call.callee->as.ident_name);
                if (target == NULL) {
                    di_error("unknown function '%s' in function %s", expr->as.call.callee->as.ident_name, decl->name);
                    return NULL;
                }
                if (target->generic_param_count != expr->as.call.generic_arg_count) {
                    di_error("call to '%s' requires %zu generic type argument(s), got %zu",
                               target->name,
                               target->generic_param_count,
                               expr->as.call.generic_arg_count);
                    return NULL;
                }
                if (target->param_count != expr->as.call.arg_count) {
                    di_error("call to '%s' has %zu argument(s), expected %zu",
                               target->name,
                               expr->as.call.arg_count,
                               target->param_count);
                    return NULL;
                }
                for (i = 0; i < expr->as.call.arg_count; ++i) {
                    const char *arg_type = check_expr(program, expr->as.call.args[i], decl, scopes);
                    const char *expected_type = resolve_decl_type(target,
                                                                  target->params[i].type.name,
                                                                  expr->as.call.generic_args,
                                                                  expr->as.call.generic_arg_count);
                    if (arg_type == NULL) {
                        return NULL;
                    }
                    if (!type_equals(arg_type, expected_type)) {
                        di_error("argument %zu to '%s' has type %s, expected %s",
                                   i + 1,
                                   target->name,
                                   arg_type,
                                   expected_type);
                        return NULL;
                    }
                }
                if (target->generic_param_count != 0) {
                    expr->as.call.resolved_name = make_generic_symbol_name(target,
                                                                           expr->as.call.generic_args,
                                                                           expr->as.call.generic_arg_count);
                } else {
                    expr->as.call.resolved_name = target->name;
                }
                expr->inferred_type = resolve_decl_type(target,
                                                        target->return_type.name,
                                                        expr->as.call.generic_args,
                                                        expr->as.call.generic_arg_count);
                return expr->inferred_type;
            }

            if (expr->as.call.callee->kind == DI_AST_FIELD_EXPR) {
                const char *base_type = check_expr(program, expr->as.call.callee->as.field.base, decl, scopes);
                const DiAstDecl *target;
                if (base_type == NULL) {
                    return NULL;
                }
                target = find_method_decl(program, base_type, expr->as.call.callee->as.field.field_name);
                if (target == NULL) {
                    di_error("type '%s' has no method '%s'", base_type, expr->as.call.callee->as.field.field_name);
                    return NULL;
                }
                if (target->param_count != expr->as.call.arg_count + 1) {
                    di_error("call to '%s.%s' has %zu argument(s), expected %zu",
                               base_type,
                               target->name,
                               expr->as.call.arg_count,
                               target->param_count - 1);
                    return NULL;
                }
                for (i = 0; i < expr->as.call.arg_count; ++i) {
                    const char *arg_type = check_expr(program, expr->as.call.args[i], decl, scopes);
                    if (arg_type == NULL) {
                        return NULL;
                    }
                    if (!type_equals(arg_type, target->params[i + 1].type.name)) {
                        di_error("argument %zu to '%s.%s' has type %s, expected %s",
                                   i + 1,
                                   base_type,
                                   target->name,
                                   arg_type,
                                   target->params[i + 1].type.name);
                        return NULL;
                    }
                }
                expr->as.call.resolved_name = target->name;
                expr->inferred_type = target->return_type.name;
                return expr->inferred_type;
            }

            di_error("invalid call target");
            return NULL;
        }
        case DI_AST_BINARY_EXPR: {
            const char *left_type = check_expr(program, expr->as.binary.left, decl, scopes);
            const char *right_type = check_expr(program, expr->as.binary.right, decl, scopes);
            if (left_type == NULL || right_type == NULL) {
                return NULL;
            }
            if (expr->as.binary.op == DI_BIN_AND || expr->as.binary.op == DI_BIN_OR) {
                if ((!type_equals(left_type, "bool") && !type_equals(left_type, "int")) ||
                    (!type_equals(right_type, "bool") && !type_equals(right_type, "int"))) {
                    di_error("logical operator %s requires bool or int operands", di_binary_op_name(expr->as.binary.op));
                    return NULL;
                }
                expr->inferred_type = "bool";
                return expr->inferred_type;
            }
            if (!type_equals(left_type, right_type)) {
                di_error("binary operator %s used with mismatched types %s and %s",
                           di_binary_op_name(expr->as.binary.op),
                           left_type,
                           right_type);
                return NULL;
            }
            switch (expr->as.binary.op) {
                case DI_BIN_ADD:
                case DI_BIN_SUB:
                case DI_BIN_MUL:
                case DI_BIN_DIV:
                    if (!type_equals(left_type, "int")) {
                        di_error("arithmetic operator %s requires int operands", di_binary_op_name(expr->as.binary.op));
                        return NULL;
                    }
                    expr->inferred_type = "int";
                    return expr->inferred_type;
                default:
                    expr->inferred_type = "bool";
                    return expr->inferred_type;
            }
        }
        default:
            return NULL;
    }
}

static int check_stmt(const DiAstProgram *program, DiAstStmt *stmt, const DiAstDecl *decl, ScopeStack *scopes) {
    if (stmt->kind == DI_AST_VAR_STMT) {
        const char *value_type = check_expr(program, stmt->as.var_stmt.value, decl, scopes);
        if (value_type == NULL) {
            return 1;
        }
        if (scope_contains_current(scopes, stmt->as.var_stmt.name)) {
            di_error("duplicate declaration of '%s' in the same scope", stmt->as.var_stmt.name);
            return 1;
        }
        if (stmt->as.var_stmt.has_explicit_type) {
            if (!type_equals(value_type, stmt->as.var_stmt.type.name)) {
                di_error("var binding '%s' has value type %s, expected %s",
                           stmt->as.var_stmt.name,
                           value_type,
                           stmt->as.var_stmt.type.name);
                return 1;
            }
        } else {
            stmt->as.var_stmt.type.name = value_type;
        }
        if (!scope_add(scopes, stmt->as.var_stmt.name, stmt->as.var_stmt.type.name)) {
            di_error("failed to record declaration of '%s'", stmt->as.var_stmt.name);
            return 1;
        }
        return 0;
    }

    if (stmt->kind == DI_AST_ASSIGN_STMT) {
        const char *target_type = scope_lookup(scopes, stmt->as.assign_stmt.name);
        const char *value_type;
        if (target_type == NULL) {
            di_error("cannot assign to unknown variable '%s'", stmt->as.assign_stmt.name);
            return 1;
        }
        value_type = check_expr(program, stmt->as.assign_stmt.value, decl, scopes);
        if (value_type == NULL) {
            return 1;
        }
        if (!type_equals(target_type, value_type)) {
            di_error("assignment to '%s' has type %s, expected %s",
                       stmt->as.assign_stmt.name,
                       value_type,
                       target_type);
            return 1;
        }
        return 0;
    }

    if (stmt->kind == DI_AST_FIELD_ASSIGN_STMT) {
        const char *target_type = check_expr(program, stmt->as.field_assign_stmt.target, decl, scopes);
        const char *value_type = check_expr(program, stmt->as.field_assign_stmt.value, decl, scopes);
        if (target_type == NULL || value_type == NULL) {
            return 1;
        }
        if (!type_equals(target_type, value_type)) {
            di_error("field assignment has type %s, expected %s", value_type, target_type);
            return 1;
        }
        return 0;
    }

    if (stmt->kind == DI_AST_INDEX_ASSIGN_STMT) {
        const char *target_type = check_expr(program, stmt->as.index_assign_stmt.target, decl, scopes);
        const char *value_type = check_expr(program, stmt->as.index_assign_stmt.value, decl, scopes);
        if (target_type == NULL || value_type == NULL) {
            return 1;
        }
        if (!type_equals(target_type, value_type)) {
            di_error("array assignment has type %s, expected %s", value_type, target_type);
            return 1;
        }
        return 0;
    }

    if (stmt->kind == DI_AST_RETURN_STMT) {
        const char *value_type = check_expr(program, stmt->as.return_stmt.value, decl, scopes);
        if (value_type == NULL) {
            return 1;
        }
        if (!type_equals(value_type, decl->return_type.name)) {
            di_error("function %s returns %s, expected %s",
                       decl->name,
                       value_type,
                       decl->return_type.name);
            return 1;
        }
        return 0;
    }

    if (stmt->kind == DI_AST_EXPR_STMT) {
        return check_expr(program, stmt->as.expr_stmt.expr, decl, scopes) == NULL ? 1 : 0;
    }

    if (stmt->kind == DI_AST_IF_STMT) {
        const char *cond_type = check_expr(program, stmt->as.if_stmt.condition, decl, scopes);
        if (cond_type == NULL) {
            return 1;
        }
        if (!type_equals(cond_type, "bool") && !type_equals(cond_type, "int")) {
            di_error("if condition must be bool or int");
            return 1;
        }
        return check_stmt_list(program, stmt->as.if_stmt.then_block.items, stmt->as.if_stmt.then_block.count, decl, scopes, 1) +
               check_stmt_list(program, stmt->as.if_stmt.else_block.items, stmt->as.if_stmt.else_block.count, decl, scopes, 1);
    }

    if (stmt->kind == DI_AST_WHILE_STMT) {
        const char *cond_type = check_expr(program, stmt->as.while_stmt.condition, decl, scopes);
        int failures = 0;
        if (cond_type == NULL) {
            return 1;
        }
        if (!type_equals(cond_type, "bool") && !type_equals(cond_type, "int")) {
            di_error("while condition must be bool or int");
            return 1;
        }
        scope_push(scopes);
        failures += check_stmt_list(program, stmt->as.while_stmt.body.items, stmt->as.while_stmt.body.count, decl, scopes, 0);
        if (stmt->as.while_stmt.update != NULL) {
            failures += check_stmt(program, stmt->as.while_stmt.update, decl, scopes);
        }
        scope_pop(scopes);
        return failures;
    }

    if (stmt->kind == DI_AST_FLUX_STMT) {
        const char *iterable_type = check_expr(program, stmt->as.flux_stmt.iterable, decl, scopes);
        const char *item_type = NULL;
        int failures;
        if (iterable_type == NULL) {
            return 1;
        }
        if (type_equals(iterable_type, "range")) {
            item_type = "int";
        } else if (type_equals(iterable_type, "int[]")) {
            item_type = "int";
        } else {
            di_error("flux currently supports ranges and int[] values");
            return 1;
        }
        scope_push(scopes);
        if (!scope_add(scopes, stmt->as.flux_stmt.name, item_type)) {
            di_error("failed to bind flux iterator '%s'", stmt->as.flux_stmt.name);
            scope_pop(scopes);
            return 1;
        }
        failures = check_stmt_list(program, stmt->as.flux_stmt.body.items, stmt->as.flux_stmt.body.count, decl, scopes, 0);
        scope_pop(scopes);
        return failures;
    }

    return 0;
}

static int check_stmt_list(const DiAstProgram *program, DiAstStmt **items, size_t count, const DiAstDecl *decl, ScopeStack *scopes, int new_scope) {
    size_t i;
    int failures = 0;

    if (new_scope) {
        scope_push(scopes);
    }
    for (i = 0; i < count; ++i) {
        failures += check_stmt(program, items[i], decl, scopes);
    }
    if (new_scope) {
        scope_pop(scopes);
    }
    return failures;
}

int di_sema_check_program(const DiAstProgram *program, int require_main) {
    size_t i;
    size_t k;
    int seen_main = 0;
    int failures = 0;

    if (program == NULL || program->had_error) {
        return 1;
    }

    for (i = 0; i < program->decl_count; ++i) {
        const DiAstDecl *decl = program->decls[i];
        size_t j;
        const char *decl_kind_name = decl->kind == DI_AST_STRUCT_DECL ? "type" :
                                     decl->kind == DI_AST_TRAIT_DECL ? "trait" :
                                     decl->kind == DI_AST_IMPL_DECL ? "impl" :
                                     "declaration";

        if (!validate_identifier_name(decl_kind_name, decl->name, decl->owner_type)) {
            failures++;
        }
        if (decl->owner_type != NULL &&
            !validate_identifier_name("owner type", decl->owner_type, decl->name)) {
            failures++;
        }
        for (j = 0; j < decl->generic_param_count; ++j) {
            if (!validate_identifier_name("generic parameter", decl->generic_params[j], decl->name)) {
                failures++;
            }
        }
        for (k = i + 1; k < program->decl_count; ++k) {
            const DiAstDecl *other = program->decls[k];
            const char *decl_owner = decl->owner_type != NULL ? decl->owner_type : "";
            const char *other_owner = other->owner_type != NULL ? other->owner_type : "";
            if (decl->kind == DI_AST_IMPL_DECL || other->kind == DI_AST_IMPL_DECL) {
                continue;
            }
            if (same_name(decl_owner, other_owner) && same_name(decl->name, other->name)) {
                if (decl->kind == DI_AST_EXTERN_FUNCTION &&
                    other->kind == DI_AST_EXTERN_FUNCTION &&
                    same_signature(decl, other)) {
                    continue;
                }
                di_error("duplicate top-level declaration '%s'", decl->name);
                failures++;
                break;
            }
        }

        if (decl->kind == DI_AST_FUNCTION && decl->owner_type == NULL &&
            decl->generic_param_count == 0 && same_name(decl->name, "main")) {
            seen_main = 1;
        }

        if (decl->kind == DI_AST_STRUCT_DECL) {
            for (j = 0; j < decl->field_count; ++j) {
                if (!validate_identifier_name("field", decl->fields[j].name, decl->name)) {
                    failures++;
                }
                if (!type_exists(program, decl, decl->fields[j].type.name)) {
                    di_error("unknown field type '%s' in struct %s", decl->fields[j].type.name, decl->name);
                    failures++;
                }
            }
            continue;
        }

        if (decl->kind == DI_AST_TRAIT_DECL) {
            for (j = 0; j < decl->trait_method_count; ++j) {
                const DiAstDecl *method = decl->trait_methods[j];
                size_t p;
                if (!validate_identifier_name("trait method", method->name, decl->name)) {
                    failures++;
                }
                for (p = 0; p < method->param_count; ++p) {
                    if (!type_exists(program, method, method->params[p].type.name)) {
                        di_error("unknown parameter type '%s' in trait %s method %s",
                                 method->params[p].type.name,
                                 decl->name,
                                 method->name);
                        failures++;
                    }
                }
                if (!type_exists(program, method, method->return_type.name)) {
                    di_error("unknown return type '%s' in trait %s method %s",
                             method->return_type.name,
                             decl->name,
                             method->name);
                    failures++;
                }
            }
            continue;
        }

        if (decl->kind == DI_AST_IMPL_DECL) {
            const DiAstDecl *trait_decl = find_trait_decl(program, decl->name);
            const DiAstDecl *struct_decl = find_struct_decl(program, decl->owner_type);
            if (trait_decl == NULL) {
                di_error("unknown trait '%s' in impl", decl->name);
                failures++;
            }
            if (struct_decl == NULL) {
                di_error("unknown type '%s' in impl for trait %s", decl->owner_type, decl->name);
                failures++;
            }
            if (trait_decl != NULL && struct_decl != NULL) {
                for (j = 0; j < trait_decl->trait_method_count; ++j) {
                    const DiAstDecl *required = trait_decl->trait_methods[j];
                    const DiAstDecl *actual = find_method_decl(program, decl->owner_type, required->name);
                    size_t p;
                    if (actual == NULL) {
                        di_error("type '%s' does not implement required method '%s' for trait %s",
                                 decl->owner_type,
                                 required->name,
                                 decl->name);
                        failures++;
                        continue;
                    }
                    if (actual->param_count != required->param_count + 1) {
                        di_error("method '%s.%s' does not match trait %s parameter count",
                                 decl->owner_type,
                                 required->name,
                                 decl->name);
                        failures++;
                        continue;
                    }
                    if (!type_equals(actual->params[0].type.name, decl->owner_type)) {
                        di_error("method '%s.%s' has invalid self parameter for trait %s",
                                 decl->owner_type,
                                 required->name,
                                 decl->name);
                        failures++;
                    }
                    for (p = 0; p < required->param_count; ++p) {
                        if (!type_equals(actual->params[p + 1].type.name, required->params[p].type.name)) {
                            di_error("method '%s.%s' parameter %zu does not match trait %s",
                                     decl->owner_type,
                                     required->name,
                                     p + 1,
                                     decl->name);
                            failures++;
                        }
                    }
                    if (!type_equals(actual->return_type.name, required->return_type.name)) {
                        di_error("method '%s.%s' return type does not match trait %s",
                                 decl->owner_type,
                                 required->name,
                                 decl->name);
                        failures++;
                    }
                }
            }
            continue;
        }

        if (decl->owner_type != NULL && decl->generic_param_count != 0) {
            di_error("generic methods are not supported yet: %s.%s", decl->owner_type, decl->name);
            failures++;
        }

        if (decl->kind == DI_AST_EXTERN_FUNCTION) {
            continue;
        }

        for (j = 0; j < decl->param_count; ++j) {
            if (!validate_identifier_name("parameter", decl->params[j].name, decl->name)) {
                failures++;
            }
            if (!type_exists(program, decl, decl->params[j].type.name)) {
                di_error("unknown parameter type '%s' in function %s", decl->params[j].type.name, decl->name);
                failures++;
            }
        }
        if (!type_exists(program, decl, decl->return_type.name)) {
            di_error("unknown return type '%s' in function %s", decl->return_type.name, decl->name);
            failures++;
        }
    }

    for (i = 0; i < program->decl_count; ++i) {
        const DiAstDecl *decl = program->decls[i];
        ScopeStack scopes;
        size_t j;

        if (decl->kind == DI_AST_STRUCT_DECL ||
            decl->kind == DI_AST_EXTERN_FUNCTION ||
            decl->kind == DI_AST_TRAIT_DECL ||
            decl->kind == DI_AST_IMPL_DECL) {
            continue;
        }

        scopes.depth = 0;
        scope_push(&scopes);
        for (j = 0; j < decl->param_count; ++j) {
            if (!scope_add(&scopes, decl->params[j].name, decl->params[j].type.name)) {
                di_error("duplicate parameter '%s' in function %s", decl->params[j].name, decl->name);
                failures++;
            }
        }
        failures += check_stmt_list(program, decl->body, decl->body_count, decl, &scopes, 0);
    }

    if (require_main && !seen_main) {
        di_error("program is missing a main function");
        failures++;
    }

    return failures == 0 ? 0 : 1;
}

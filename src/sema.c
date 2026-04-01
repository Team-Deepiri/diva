#include "sema.h"

#include "diag.h"

#include <stddef.h>
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

static const DiriAstDecl *find_decl(const DiriAstProgram *program, const char *name) {
    size_t i;

    for (i = 0; i < program->decl_count; ++i) {
        if (same_name(program->decls[i]->name, name)) {
            return program->decls[i];
        }
    }
    return NULL;
}

static const DiriAstField *find_struct_field(const DiriAstDecl *decl, const char *field_name) {
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

static const char *check_expr(const DiriAstProgram *program, DiriAstExpr *expr, const DiriAstDecl *decl, ScopeStack *scopes);
static int check_stmt_list(const DiriAstProgram *program, DiriAstStmt **items, size_t count, const DiriAstDecl *decl, ScopeStack *scopes, int new_scope);

static const char *check_expr(const DiriAstProgram *program, DiriAstExpr *expr, const DiriAstDecl *decl, ScopeStack *scopes) {
    size_t i;

    if (expr == NULL) {
        diri_error("missing expression in function %s", decl->name);
        return NULL;
    }

    if (expr->kind == DIRI_AST_INT_EXPR) {
        expr->inferred_type = "int";
        return expr->inferred_type;
    }

    if (expr->kind == DIRI_AST_BOOL_EXPR) {
        expr->inferred_type = "bool";
        return expr->inferred_type;
    }

    if (expr->kind == DIRI_AST_STRING_EXPR) {
        expr->inferred_type = "str";
        return expr->inferred_type;
    }

    if (expr->kind == DIRI_AST_IDENT_EXPR) {
        const char *type_name = scope_lookup(scopes, expr->as.ident_name);
        if (type_name != NULL) {
            expr->inferred_type = type_name;
            return expr->inferred_type;
        }
        diri_error("unknown identifier '%s' in function %s", expr->as.ident_name, decl->name);
        return NULL;
    }

    if (expr->kind == DIRI_AST_FIELD_EXPR) {
        const char *base_type = check_expr(program, expr->as.field.base, decl, scopes);
        const DiriAstDecl *struct_decl;
        const DiriAstField *field;
        if (base_type == NULL) {
            return NULL;
        }
        struct_decl = find_decl(program, base_type);
        if (struct_decl == NULL || struct_decl->kind != DIRI_AST_STRUCT_DECL) {
            diri_error("type '%s' does not have fields", base_type);
            return NULL;
        }
        field = find_struct_field(struct_decl, expr->as.field.field_name);
        if (field == NULL) {
            diri_error("struct '%s' has no field '%s'", base_type, expr->as.field.field_name);
            return NULL;
        }
        expr->inferred_type = field->type.name;
        return expr->inferred_type;
    }

    if (expr->kind == DIRI_AST_STRUCT_INIT_EXPR) {
        const DiriAstDecl *struct_decl = find_decl(program, expr->as.struct_init.type_name);
        size_t i;
        if (struct_decl == NULL || struct_decl->kind != DIRI_AST_STRUCT_DECL) {
            diri_error("unknown struct type '%s'", expr->as.struct_init.type_name);
            return NULL;
        }
        for (i = 0; i < expr->as.struct_init.field_count; ++i) {
            const DiriAstField *field = find_struct_field(struct_decl, expr->as.struct_init.fields[i].name);
            const char *value_type;
            if (field == NULL) {
                diri_error("struct '%s' has no field '%s'", struct_decl->name, expr->as.struct_init.fields[i].name);
                return NULL;
            }
            value_type = check_expr(program, expr->as.struct_init.fields[i].value, decl, scopes);
            if (value_type == NULL || !type_equals(value_type, field->type.name)) {
                diri_error("initializer for %s.%s has wrong type", struct_decl->name, field->name);
                return NULL;
            }
        }
        expr->inferred_type = struct_decl->name;
        return expr->inferred_type;
    }

    if (expr->kind == DIRI_AST_ARRAY_INIT_EXPR) {
        size_t i;
        const char *item_type = NULL;
        for (i = 0; i < expr->as.array_init.item_count; ++i) {
            const char *current = check_expr(program, expr->as.array_init.items[i], decl, scopes);
            if (current == NULL) {
                return NULL;
            }
            if (item_type == NULL) {
                item_type = current;
            } else if (!type_equals(item_type, current)) {
                diri_error("array literal has mixed element types");
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
        diri_error("only int[] arrays are supported currently");
        return NULL;
    }

    if (expr->kind == DIRI_AST_INDEX_EXPR) {
        const char *base_type = check_expr(program, expr->as.index.base, decl, scopes);
        const char *index_type = check_expr(program, expr->as.index.index, decl, scopes);
        const char *elem_type;
        if (base_type == NULL || index_type == NULL) {
            return NULL;
        }
        if (!type_equals(index_type, "int")) {
            diri_error("array index must be int");
            return NULL;
        }
        elem_type = array_element_type(base_type);
        if (elem_type == NULL) {
            diri_error("cannot index non-array type '%s'", base_type);
            return NULL;
        }
        expr->inferred_type = elem_type;
        return expr->inferred_type;
    }

    if (expr->kind == DIRI_AST_CALL_EXPR) {
        const DiriAstDecl *target = find_decl(program, expr->as.call.callee);
        if (target == NULL) {
            diri_error("unknown function '%s' in function %s", expr->as.call.callee, decl->name);
            return NULL;
        }
        if (target->param_count != expr->as.call.arg_count) {
            diri_error("call to '%s' has %zu argument(s), expected %zu",
                       expr->as.call.callee,
                       expr->as.call.arg_count,
                       target->param_count);
            return NULL;
        }
        for (i = 0; i < expr->as.call.arg_count; ++i) {
            const char *arg_type = check_expr(program, expr->as.call.args[i], decl, scopes);
            if (arg_type == NULL) {
                return NULL;
            }
            if (!type_equals(arg_type, target->params[i].type.name)) {
                diri_error("argument %zu to '%s' has type %s, expected %s",
                           i + 1,
                           expr->as.call.callee,
                           arg_type,
                           target->params[i].type.name);
                return NULL;
            }
        }
        expr->inferred_type = target->return_type.name;
        return expr->inferred_type;
    }

    if (expr->kind == DIRI_AST_BINARY_EXPR) {
        const char *left_type = check_expr(program, expr->as.binary.left, decl, scopes);
        const char *right_type = check_expr(program, expr->as.binary.right, decl, scopes);

        if (left_type == NULL || right_type == NULL) {
            return NULL;
        }

        if (!type_equals(left_type, right_type)) {
            diri_error("binary operator %s used with mismatched types %s and %s",
                       diri_binary_op_name(expr->as.binary.op),
                       left_type,
                       right_type);
            return NULL;
        }

        switch (expr->as.binary.op) {
            case DIRI_BIN_ADD:
            case DIRI_BIN_SUB:
            case DIRI_BIN_MUL:
            case DIRI_BIN_DIV:
                if (!type_equals(left_type, "int")) {
                    diri_error("arithmetic operator %s requires int operands",
                               diri_binary_op_name(expr->as.binary.op));
                    return NULL;
                }
                expr->inferred_type = "int";
                return expr->inferred_type;
            default:
                expr->inferred_type = "bool";
                return expr->inferred_type;
        }
    }

    return NULL;
}

static int check_stmt(const DiriAstProgram *program, DiriAstStmt *stmt, const DiriAstDecl *decl, ScopeStack *scopes) {
    if (stmt->kind == DIRI_AST_LET_STMT) {
        const char *value_type = check_expr(program, stmt->as.let_stmt.value, decl, scopes);
        if (value_type == NULL) {
            return 1;
        }
        if (scope_contains_current(scopes, stmt->as.let_stmt.name)) {
            diri_error("duplicate declaration of '%s' in the same scope", stmt->as.let_stmt.name);
            return 1;
        }
        if (!type_equals(value_type, stmt->as.let_stmt.type.name)) {
            diri_error("let binding '%s' has value type %s, expected %s",
                       stmt->as.let_stmt.name,
                       value_type,
                       stmt->as.let_stmt.type.name);
            return 1;
        }
        if (!scope_add(scopes, stmt->as.let_stmt.name, stmt->as.let_stmt.type.name)) {
            diri_error("failed to record declaration of '%s'", stmt->as.let_stmt.name);
            return 1;
        }
        return 0;
    }

    if (stmt->kind == DIRI_AST_ASSIGN_STMT) {
        const char *target_type = scope_lookup(scopes, stmt->as.assign_stmt.name);
        const char *value_type;
        if (target_type == NULL) {
            diri_error("cannot assign to unknown variable '%s'", stmt->as.assign_stmt.name);
            return 1;
        }
        value_type = check_expr(program, stmt->as.assign_stmt.value, decl, scopes);
        if (value_type == NULL) {
            return 1;
        }
        if (!type_equals(target_type, value_type)) {
            diri_error("assignment to '%s' has type %s, expected %s",
                       stmt->as.assign_stmt.name,
                       value_type,
                       target_type);
            return 1;
        }
        return 0;
    }

    if (stmt->kind == DIRI_AST_FIELD_ASSIGN_STMT) {
        const char *target_type = check_expr(program, stmt->as.field_assign_stmt.target, decl, scopes);
        const char *value_type = check_expr(program, stmt->as.field_assign_stmt.value, decl, scopes);
        if (target_type == NULL || value_type == NULL) {
            return 1;
        }
        if (!type_equals(target_type, value_type)) {
            diri_error("field assignment has type %s, expected %s", value_type, target_type);
            return 1;
        }
        return 0;
    }

    if (stmt->kind == DIRI_AST_RETURN_STMT) {
        const char *value_type = check_expr(program, stmt->as.return_stmt.value, decl, scopes);
        if (value_type == NULL) {
            return 1;
        }
        if (!type_equals(value_type, decl->return_type.name)) {
            diri_error("function %s returns %s, expected %s",
                       decl->name,
                       value_type,
                       decl->return_type.name);
            return 1;
        }
        return 0;
    }

    if (stmt->kind == DIRI_AST_EXPR_STMT) {
        return check_expr(program, stmt->as.expr_stmt.expr, decl, scopes) == NULL ? 1 : 0;
    }

    if (stmt->kind == DIRI_AST_IF_STMT) {
        const char *cond_type = check_expr(program, stmt->as.if_stmt.condition, decl, scopes);
        if (cond_type == NULL) {
            return 1;
        }
        if (!type_equals(cond_type, "bool") && !type_equals(cond_type, "int")) {
            diri_error("if condition must be bool or int");
            return 1;
        }
        return check_stmt_list(program, stmt->as.if_stmt.then_block.items, stmt->as.if_stmt.then_block.count, decl, scopes, 1) +
               check_stmt_list(program, stmt->as.if_stmt.else_block.items, stmt->as.if_stmt.else_block.count, decl, scopes, 1);
    }

    if (stmt->kind == DIRI_AST_WHILE_STMT) {
        const char *cond_type = check_expr(program, stmt->as.while_stmt.condition, decl, scopes);
        if (cond_type == NULL) {
            return 1;
        }
        if (!type_equals(cond_type, "bool") && !type_equals(cond_type, "int")) {
            diri_error("while condition must be bool or int");
            return 1;
        }
        return check_stmt_list(program, stmt->as.while_stmt.body.items, stmt->as.while_stmt.body.count, decl, scopes, 1);
    }

    return 0;
}

static int check_stmt_list(const DiriAstProgram *program, DiriAstStmt **items, size_t count, const DiriAstDecl *decl, ScopeStack *scopes, int new_scope) {
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

int diri_sema_check_program(const DiriAstProgram *program) {
    size_t i;
    int seen_main = 0;
    int failures = 0;

    if (program == NULL || program->had_error) {
        return 1;
    }

    for (i = 0; i < program->decl_count; ++i) {
        const DiriAstDecl *decl = program->decls[i];
        ScopeStack scopes;
        size_t j;

        if (same_name(decl->name, "main")) {
            seen_main = 1;
        }

        if (decl->kind == DIRI_AST_EXTERN_FUNCTION) {
            continue;
        }
        if (decl->kind == DIRI_AST_STRUCT_DECL) {
            for (j = 0; j < decl->field_count; ++j) {
                if (find_decl(program, decl->fields[j].type.name) == NULL &&
                    !type_equals(decl->fields[j].type.name, "int") &&
                    !type_equals(decl->fields[j].type.name, "bool") &&
                    !type_equals(decl->fields[j].type.name, "str") &&
                    !type_equals(decl->fields[j].type.name, "void")) {
                    diri_error("unknown field type '%s' in struct %s", decl->fields[j].type.name, decl->name);
                    failures++;
                }
            }
            continue;
        }

        scopes.depth = 0;
        scope_push(&scopes);
        for (j = 0; j < decl->param_count; ++j) {
            if (!scope_add(&scopes, decl->params[j].name, decl->params[j].type.name)) {
                diri_error("duplicate parameter '%s' in function %s", decl->params[j].name, decl->name);
                failures++;
            }
        }
        failures += check_stmt_list(program, decl->body, decl->body_count, decl, &scopes, 0);
    }

    if (!seen_main) {
        diri_error("program is missing a main function");
        failures++;
    }

    return failures == 0 ? 0 : 1;
}

#include "ast.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static void *diri_realloc_array(void *ptr, size_t count, size_t item_size) {
    return realloc(ptr, count * item_size);
}

char *diri_ast_strdup_range(const char *start, int length) {
    char *copy;

    copy = (char *)malloc((size_t)length + 1);
    if (copy == NULL) {
        return NULL;
    }
    memcpy(copy, start, (size_t)length);
    copy[length] = '\0';
    return copy;
}

DiriAstProgram *diri_ast_program_new(void) {
    return (DiriAstProgram *)calloc(1, sizeof(DiriAstProgram));
}

DiriAstDecl *diri_ast_decl_new(DiriAstKind kind, const char *name) {
    DiriAstDecl *decl = (DiriAstDecl *)calloc(1, sizeof(DiriAstDecl));
    if (decl == NULL) {
        return NULL;
    }
    decl->kind = kind;
    decl->name = name;
    return decl;
}

DiriAstStmt *diri_ast_stmt_new(DiriAstKind kind) {
    DiriAstStmt *stmt = (DiriAstStmt *)calloc(1, sizeof(DiriAstStmt));
    if (stmt == NULL) {
        return NULL;
    }
    stmt->kind = kind;
    return stmt;
}

DiriAstExpr *diri_ast_expr_new(DiriAstKind kind) {
    DiriAstExpr *expr = (DiriAstExpr *)calloc(1, sizeof(DiriAstExpr));
    if (expr == NULL) {
        return NULL;
    }
    expr->kind = kind;
    return expr;
}

int diri_ast_program_add_decl(DiriAstProgram *program, DiriAstDecl *decl) {
    DiriAstDecl **decls;

    decls = (DiriAstDecl **)diri_realloc_array(program->decls, program->decl_count + 1, sizeof(DiriAstDecl *));
    if (decls == NULL) {
        return 0;
    }
    program->decls = decls;
    program->decls[program->decl_count++] = decl;
    return 1;
}

int diri_ast_decl_add_param(DiriAstDecl *decl, DiriAstParam param) {
    DiriAstParam *params;

    params = (DiriAstParam *)diri_realloc_array(decl->params, decl->param_count + 1, sizeof(DiriAstParam));
    if (params == NULL) {
        return 0;
    }
    decl->params = params;
    decl->params[decl->param_count++] = param;
    return 1;
}

int diri_ast_decl_add_stmt(DiriAstDecl *decl, DiriAstStmt *stmt) {
    DiriAstStmt **body;

    body = (DiriAstStmt **)diri_realloc_array(decl->body, decl->body_count + 1, sizeof(DiriAstStmt *));
    if (body == NULL) {
        return 0;
    }
    decl->body = body;
    decl->body[decl->body_count++] = stmt;
    return 1;
}

int diri_ast_decl_add_field(DiriAstDecl *decl, DiriAstField field) {
    DiriAstField *fields;

    fields = (DiriAstField *)diri_realloc_array(decl->fields, decl->field_count + 1, sizeof(DiriAstField));
    if (fields == NULL) {
        return 0;
    }
    decl->fields = fields;
    decl->fields[decl->field_count++] = field;
    return 1;
}

int diri_ast_block_add_stmt(DiriAstBlock *block, DiriAstStmt *stmt) {
    DiriAstStmt **items;

    items = (DiriAstStmt **)diri_realloc_array(block->items, block->count + 1, sizeof(DiriAstStmt *));
    if (items == NULL) {
        return 0;
    }
    block->items = items;
    block->items[block->count++] = stmt;
    return 1;
}

int diri_ast_call_add_arg(DiriAstExpr *expr, DiriAstExpr *arg) {
    DiriAstExpr **args;

    args = (DiriAstExpr **)diri_realloc_array(expr->as.call.args, expr->as.call.arg_count + 1, sizeof(DiriAstExpr *));
    if (args == NULL) {
        return 0;
    }
    expr->as.call.args = args;
    expr->as.call.args[expr->as.call.arg_count++] = arg;
    return 1;
}

int diri_ast_struct_init_add_field(DiriAstExpr *expr, DiriAstInitField field) {
    DiriAstInitField *fields;

    fields = (DiriAstInitField *)diri_realloc_array(expr->as.struct_init.fields, expr->as.struct_init.field_count + 1, sizeof(DiriAstInitField));
    if (fields == NULL) {
        return 0;
    }
    expr->as.struct_init.fields = fields;
    expr->as.struct_init.fields[expr->as.struct_init.field_count++] = field;
    return 1;
}

int diri_ast_array_add_item(DiriAstExpr *expr, DiriAstExpr *item) {
    DiriAstExpr **items;

    items = (DiriAstExpr **)diri_realloc_array(expr->as.array_init.items, expr->as.array_init.item_count + 1, sizeof(DiriAstExpr *));
    if (items == NULL) {
        return 0;
    }
    expr->as.array_init.items = items;
    expr->as.array_init.items[expr->as.array_init.item_count++] = item;
    return 1;
}

const char *diri_binary_op_name(DiriBinaryOp op) {
    switch (op) {
        case DIRI_BIN_ADD: return "+";
        case DIRI_BIN_SUB: return "-";
        case DIRI_BIN_MUL: return "*";
        case DIRI_BIN_DIV: return "/";
        case DIRI_BIN_EQ: return "==";
        case DIRI_BIN_NE: return "!=";
        case DIRI_BIN_LT: return "<";
        case DIRI_BIN_GT: return ">";
        case DIRI_BIN_LE: return "<=";
        case DIRI_BIN_GE: return ">=";
        default: return "?";
    }
}

static void dump_indent(int indent) {
    for (int i = 0; i < indent; ++i) {
        printf("  ");
    }
}

static void dump_stmt(const DiriAstStmt *stmt, int indent);

static void dump_expr(const DiriAstExpr *expr, int indent) {
    size_t i;

    if (expr == NULL) {
        dump_indent(indent);
        printf("(null expr)\n");
        return;
    }

    dump_indent(indent);
    switch (expr->kind) {
        case DIRI_AST_INT_EXPR:
            printf("Int(%ld)\n", expr->as.int_value);
            break;
        case DIRI_AST_BOOL_EXPR:
            printf("Bool(%s)\n", expr->as.bool_value ? "true" : "false");
            break;
        case DIRI_AST_STRING_EXPR:
            printf("String(\"%s\")\n", expr->as.string_value);
            break;
        case DIRI_AST_IDENT_EXPR:
            printf("Ident(%s)\n", expr->as.ident_name);
            break;
        case DIRI_AST_FIELD_EXPR:
            printf("Field(%s)\n", expr->as.field.field_name);
            dump_expr(expr->as.field.base, indent + 1);
            break;
        case DIRI_AST_INDEX_EXPR:
            printf("Index\n");
            dump_expr(expr->as.index.base, indent + 1);
            dump_expr(expr->as.index.index, indent + 1);
            break;
        case DIRI_AST_CALL_EXPR:
            printf("Call(%s)\n", expr->as.call.callee);
            for (i = 0; i < expr->as.call.arg_count; ++i) {
                dump_expr(expr->as.call.args[i], indent + 1);
            }
            break;
        case DIRI_AST_BINARY_EXPR:
            printf("Binary(%s)\n", diri_binary_op_name(expr->as.binary.op));
            dump_expr(expr->as.binary.left, indent + 1);
            dump_expr(expr->as.binary.right, indent + 1);
            break;
        case DIRI_AST_STRUCT_INIT_EXPR:
            printf("StructInit(%s)\n", expr->as.struct_init.type_name);
            for (i = 0; i < expr->as.struct_init.field_count; ++i) {
                dump_indent(indent + 1);
                printf("InitField(%s)\n", expr->as.struct_init.fields[i].name);
                dump_expr(expr->as.struct_init.fields[i].value, indent + 2);
            }
            break;
        case DIRI_AST_ARRAY_INIT_EXPR:
            printf("ArrayInit\n");
            for (i = 0; i < expr->as.array_init.item_count; ++i) {
                dump_expr(expr->as.array_init.items[i], indent + 1);
            }
            break;
        default:
            printf("%s\n", diri_ast_kind_name(expr->kind));
            break;
    }
}

static void dump_block(const DiriAstBlock *block, int indent) {
    size_t i;

    for (i = 0; i < block->count; ++i) {
        dump_stmt(block->items[i], indent);
    }
}

static void dump_stmt(const DiriAstStmt *stmt, int indent) {
    if (stmt == NULL) {
        return;
    }

    dump_indent(indent);
    switch (stmt->kind) {
        case DIRI_AST_LET_STMT:
            printf("Let(%s: %s)\n", stmt->as.let_stmt.name, stmt->as.let_stmt.type.name);
            dump_expr(stmt->as.let_stmt.value, indent + 1);
            break;
        case DIRI_AST_ASSIGN_STMT:
            printf("Assign(%s)\n", stmt->as.assign_stmt.name);
            dump_expr(stmt->as.assign_stmt.value, indent + 1);
            break;
        case DIRI_AST_FIELD_ASSIGN_STMT:
            printf("FieldAssign\n");
            dump_expr(stmt->as.field_assign_stmt.target, indent + 1);
            dump_expr(stmt->as.field_assign_stmt.value, indent + 1);
            break;
        case DIRI_AST_RETURN_STMT:
            printf("Return\n");
            dump_expr(stmt->as.return_stmt.value, indent + 1);
            break;
        case DIRI_AST_IF_STMT:
            printf("If\n");
            dump_indent(indent + 1);
            printf("Condition\n");
            dump_expr(stmt->as.if_stmt.condition, indent + 2);
            dump_indent(indent + 1);
            printf("Then\n");
            dump_block(&stmt->as.if_stmt.then_block, indent + 2);
            if (stmt->as.if_stmt.else_block.count != 0) {
                dump_indent(indent + 1);
                printf("Else\n");
                dump_block(&stmt->as.if_stmt.else_block, indent + 2);
            }
            break;
        case DIRI_AST_WHILE_STMT:
            printf("While\n");
            dump_indent(indent + 1);
            printf("Condition\n");
            dump_expr(stmt->as.while_stmt.condition, indent + 2);
            dump_indent(indent + 1);
            printf("Body\n");
            dump_block(&stmt->as.while_stmt.body, indent + 2);
            break;
        default:
            printf("ExprStmt\n");
            dump_expr(stmt->as.expr_stmt.expr, indent + 1);
            break;
    }
}

void diri_ast_dump_program(const DiriAstProgram *program) {
    size_t i;
    size_t j;

    if (program == NULL) {
        printf("Program(null)\n");
        return;
    }

    printf("Program\n");
    for (i = 0; i < program->decl_count; ++i) {
        const DiriAstDecl *decl = program->decls[i];
        dump_indent(1);
        if (decl->kind == DIRI_AST_STRUCT_DECL) {
            printf("struct %s\n", decl->name);
            for (j = 0; j < decl->field_count; ++j) {
                dump_indent(2);
                printf("Field(%s: %s)\n", decl->fields[j].name, decl->fields[j].type.name);
            }
            continue;
        }
        printf("%s %s -> %s\n", diri_ast_kind_name(decl->kind), decl->name, decl->return_type.name);
        for (j = 0; j < decl->param_count; ++j) {
            dump_indent(2);
            printf("Param(%s: %s)\n", decl->params[j].name, decl->params[j].type.name);
        }
        for (j = 0; j < decl->body_count; ++j) {
            dump_stmt(decl->body[j], 2);
        }
    }
}

static void free_expr(DiriAstExpr *expr) {
    size_t i;

    if (expr == NULL) {
        return;
    }
    if (expr->kind == DIRI_AST_STRING_EXPR) {
        free((char *)expr->as.string_value);
    } else if (expr->kind == DIRI_AST_BINARY_EXPR) {
        free_expr(expr->as.binary.left);
        free_expr(expr->as.binary.right);
    } else if (expr->kind == DIRI_AST_FIELD_EXPR) {
        free_expr(expr->as.field.base);
        free((char *)expr->as.field.field_name);
    } else if (expr->kind == DIRI_AST_INDEX_EXPR) {
        free_expr(expr->as.index.base);
        free_expr(expr->as.index.index);
    } else if (expr->kind == DIRI_AST_STRUCT_INIT_EXPR) {
        for (i = 0; i < expr->as.struct_init.field_count; ++i) {
            free((char *)expr->as.struct_init.fields[i].name);
            free_expr(expr->as.struct_init.fields[i].value);
        }
        free((char *)expr->as.struct_init.type_name);
        free(expr->as.struct_init.fields);
    } else if (expr->kind == DIRI_AST_ARRAY_INIT_EXPR) {
        for (i = 0; i < expr->as.array_init.item_count; ++i) {
            free_expr(expr->as.array_init.items[i]);
        }
        free(expr->as.array_init.items);
    } else if (expr->kind == DIRI_AST_IDENT_EXPR) {
        free((char *)expr->as.ident_name);
    } else if (expr->kind == DIRI_AST_CALL_EXPR) {
        free((char *)expr->as.call.callee);
        for (i = 0; i < expr->as.call.arg_count; ++i) {
            free_expr(expr->as.call.args[i]);
        }
        free(expr->as.call.args);
    }
    free(expr);
}

static void free_stmt(DiriAstStmt *stmt) {
    size_t i;

    if (stmt == NULL) {
        return;
    }
    if (stmt->kind == DIRI_AST_LET_STMT) {
        free((char *)stmt->as.let_stmt.name);
        free((char *)stmt->as.let_stmt.type.name);
        free_expr(stmt->as.let_stmt.value);
    } else if (stmt->kind == DIRI_AST_ASSIGN_STMT) {
        free((char *)stmt->as.assign_stmt.name);
        free_expr(stmt->as.assign_stmt.value);
    } else if (stmt->kind == DIRI_AST_FIELD_ASSIGN_STMT) {
        free_expr(stmt->as.field_assign_stmt.target);
        free_expr(stmt->as.field_assign_stmt.value);
    } else if (stmt->kind == DIRI_AST_RETURN_STMT) {
        free_expr(stmt->as.return_stmt.value);
    } else if (stmt->kind == DIRI_AST_IF_STMT) {
        free_expr(stmt->as.if_stmt.condition);
        for (i = 0; i < stmt->as.if_stmt.then_block.count; ++i) {
            free_stmt(stmt->as.if_stmt.then_block.items[i]);
        }
        free(stmt->as.if_stmt.then_block.items);
        for (i = 0; i < stmt->as.if_stmt.else_block.count; ++i) {
            free_stmt(stmt->as.if_stmt.else_block.items[i]);
        }
        free(stmt->as.if_stmt.else_block.items);
    } else if (stmt->kind == DIRI_AST_WHILE_STMT) {
        free_expr(stmt->as.while_stmt.condition);
        for (i = 0; i < stmt->as.while_stmt.body.count; ++i) {
            free_stmt(stmt->as.while_stmt.body.items[i]);
        }
        free(stmt->as.while_stmt.body.items);
    } else {
        free_expr(stmt->as.expr_stmt.expr);
    }
    free(stmt);
}

void diri_ast_program_free(DiriAstProgram *program) {
    size_t i;
    size_t j;

    if (program == NULL) {
        return;
    }
    for (i = 0; i < program->decl_count; ++i) {
        DiriAstDecl *decl = program->decls[i];
        free((char *)decl->name);
        free((char *)decl->return_type.name);
        for (j = 0; j < decl->field_count; ++j) {
            free((char *)decl->fields[j].name);
            free((char *)decl->fields[j].type.name);
        }
        free(decl->fields);
        for (j = 0; j < decl->param_count; ++j) {
            free((char *)decl->params[j].name);
            free((char *)decl->params[j].type.name);
        }
        free(decl->params);
        for (j = 0; j < decl->body_count; ++j) {
            free_stmt(decl->body[j]);
        }
        free(decl->body);
        free(decl);
    }
    free(program->decls);
    free(program);
}

const char *diri_ast_kind_name(DiriAstKind kind) {
    switch (kind) {
        case DIRI_AST_PROGRAM: return "program";
        case DIRI_AST_STRUCT_DECL: return "struct_decl";
        case DIRI_AST_FUNCTION: return "function";
        case DIRI_AST_EXTERN_FUNCTION: return "extern_function";
        case DIRI_AST_LET_STMT: return "let_stmt";
        case DIRI_AST_ASSIGN_STMT: return "assign_stmt";
        case DIRI_AST_FIELD_ASSIGN_STMT: return "field_assign_stmt";
        case DIRI_AST_RETURN_STMT: return "return_stmt";
        case DIRI_AST_EXPR_STMT: return "expr_stmt";
        case DIRI_AST_IF_STMT: return "if_stmt";
        case DIRI_AST_WHILE_STMT: return "while_stmt";
        case DIRI_AST_INT_EXPR: return "int_expr";
        case DIRI_AST_BOOL_EXPR: return "bool_expr";
        case DIRI_AST_STRING_EXPR: return "string_expr";
        case DIRI_AST_IDENT_EXPR: return "ident_expr";
        case DIRI_AST_CALL_EXPR: return "call_expr";
        case DIRI_AST_BINARY_EXPR: return "binary_expr";
        case DIRI_AST_FIELD_EXPR: return "field_expr";
        case DIRI_AST_STRUCT_INIT_EXPR: return "struct_init_expr";
        case DIRI_AST_INDEX_EXPR: return "index_expr";
        case DIRI_AST_ARRAY_INIT_EXPR: return "array_init_expr";
        default: return "unknown";
    }
}

#include "ast.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static void *di_realloc_array(void *ptr, size_t count, size_t item_size) {
    return realloc(ptr, count * item_size);
}

char *di_ast_strdup_range(const char *start, int length) {
    char *copy = (char *)malloc((size_t)length + 1);
    if (copy == NULL) {
        return NULL;
    }
    memcpy(copy, start, (size_t)length);
    copy[length] = '\0';
    return copy;
}

DiAstProgram *di_ast_program_new(void) {
    return (DiAstProgram *)calloc(1, sizeof(DiAstProgram));
}

DiAstDecl *di_ast_decl_new(DiAstKind kind, const char *name) {
    DiAstDecl *decl = (DiAstDecl *)calloc(1, sizeof(DiAstDecl));
    if (decl == NULL) {
        return NULL;
    }
    decl->kind = kind;
    decl->name = name;
    return decl;
}

DiAstStmt *di_ast_stmt_new(DiAstKind kind) {
    DiAstStmt *stmt = (DiAstStmt *)calloc(1, sizeof(DiAstStmt));
    if (stmt == NULL) {
        return NULL;
    }
    stmt->kind = kind;
    return stmt;
}

DiAstExpr *di_ast_expr_new(DiAstKind kind) {
    DiAstExpr *expr = (DiAstExpr *)calloc(1, sizeof(DiAstExpr));
    if (expr == NULL) {
        return NULL;
    }
    expr->kind = kind;
    return expr;
}

int di_ast_program_add_decl(DiAstProgram *program, DiAstDecl *decl) {
    DiAstDecl **decls = (DiAstDecl **)di_realloc_array(program->decls, program->decl_count + 1, sizeof(DiAstDecl *));
    if (decls == NULL) {
        return 0;
    }
    program->decls = decls;
    program->decls[program->decl_count++] = decl;
    return 1;
}

int di_ast_program_add_import(DiAstProgram *program, const char *import_path) {
    char **imports;
    char *copy;

    copy = di_ast_strdup_range(import_path, (int)strlen(import_path));
    if (copy == NULL) {
        return 0;
    }
    imports = (char **)di_realloc_array(program->imports, program->import_count + 1, sizeof(char *));
    if (imports == NULL) {
        free(copy);
        return 0;
    }
    program->imports = imports;
    program->imports[program->import_count++] = copy;
    return 1;
}

int di_ast_decl_add_param(DiAstDecl *decl, DiAstParam param) {
    DiAstParam *params = (DiAstParam *)di_realloc_array(decl->params, decl->param_count + 1, sizeof(DiAstParam));
    if (params == NULL) {
        return 0;
    }
    decl->params = params;
    decl->params[decl->param_count++] = param;
    return 1;
}

int di_ast_decl_add_stmt(DiAstDecl *decl, DiAstStmt *stmt) {
    DiAstStmt **body = (DiAstStmt **)di_realloc_array(decl->body, decl->body_count + 1, sizeof(DiAstStmt *));
    if (body == NULL) {
        return 0;
    }
    decl->body = body;
    decl->body[decl->body_count++] = stmt;
    return 1;
}

int di_ast_decl_add_field(DiAstDecl *decl, DiAstField field) {
    DiAstField *fields = (DiAstField *)di_realloc_array(decl->fields, decl->field_count + 1, sizeof(DiAstField));
    if (fields == NULL) {
        return 0;
    }
    decl->fields = fields;
    decl->fields[decl->field_count++] = field;
    return 1;
}

int di_ast_block_add_stmt(DiAstBlock *block, DiAstStmt *stmt) {
    DiAstStmt **items = (DiAstStmt **)di_realloc_array(block->items, block->count + 1, sizeof(DiAstStmt *));
    if (items == NULL) {
        return 0;
    }
    block->items = items;
    block->items[block->count++] = stmt;
    return 1;
}

int di_ast_call_add_arg(DiAstExpr *expr, DiAstExpr *arg) {
    DiAstExpr **args = (DiAstExpr **)di_realloc_array(expr->as.call.args, expr->as.call.arg_count + 1, sizeof(DiAstExpr *));
    if (args == NULL) {
        return 0;
    }
    expr->as.call.args = args;
    expr->as.call.args[expr->as.call.arg_count++] = arg;
    return 1;
}

int di_ast_struct_init_add_field(DiAstExpr *expr, DiAstInitField field) {
    DiAstInitField *fields = (DiAstInitField *)di_realloc_array(expr->as.struct_init.fields, expr->as.struct_init.field_count + 1, sizeof(DiAstInitField));
    if (fields == NULL) {
        return 0;
    }
    expr->as.struct_init.fields = fields;
    expr->as.struct_init.fields[expr->as.struct_init.field_count++] = field;
    return 1;
}

int di_ast_array_add_item(DiAstExpr *expr, DiAstExpr *item) {
    DiAstExpr **items = (DiAstExpr **)di_realloc_array(expr->as.array_init.items, expr->as.array_init.item_count + 1, sizeof(DiAstExpr *));
    if (items == NULL) {
        return 0;
    }
    expr->as.array_init.items = items;
    expr->as.array_init.items[expr->as.array_init.item_count++] = item;
    return 1;
}

const char *di_binary_op_name(DiBinaryOp op) {
    switch (op) {
        case DI_BIN_ADD: return "+";
        case DI_BIN_SUB: return "-";
        case DI_BIN_MUL: return "*";
        case DI_BIN_DIV: return "/";
        case DI_BIN_EQ: return "==";
        case DI_BIN_NE: return "!=";
        case DI_BIN_LT: return "<";
        case DI_BIN_GT: return ">";
        case DI_BIN_LE: return "<=";
        case DI_BIN_GE: return ">=";
        case DI_BIN_AND: return "&";
        case DI_BIN_OR: return "|";
        default: return "?";
    }
}

static void dump_indent(int indent) {
    int i;
    for (i = 0; i < indent; ++i) {
        printf("  ");
    }
}

static void dump_stmt(const DiAstStmt *stmt, int indent);

static void dump_expr(const DiAstExpr *expr, int indent) {
    size_t i;

    if (expr == NULL) {
        dump_indent(indent);
        printf("(null expr)\n");
        return;
    }

    dump_indent(indent);
    switch (expr->kind) {
        case DI_AST_INT_EXPR:
            printf("Int(%ld)\n", expr->as.int_value);
            break;
        case DI_AST_BOOL_EXPR:
            printf("Bool(%s)\n", expr->as.bool_value ? "true" : "false");
            break;
        case DI_AST_STRING_EXPR:
            printf("String(\"%s\")\n", expr->as.string_value);
            break;
        case DI_AST_IDENT_EXPR:
            printf("Ident(%s)\n", expr->as.ident_name);
            break;
        case DI_AST_CALL_EXPR:
            printf("Call\n");
            dump_expr(expr->as.call.callee, indent + 1);
            for (i = 0; i < expr->as.call.arg_count; ++i) {
                dump_expr(expr->as.call.args[i], indent + 1);
            }
            break;
        case DI_AST_BINARY_EXPR:
            printf("Binary(%s)\n", di_binary_op_name(expr->as.binary.op));
            dump_expr(expr->as.binary.left, indent + 1);
            dump_expr(expr->as.binary.right, indent + 1);
            break;
        case DI_AST_UNARY_EXPR:
            printf("Unary(!)\n");
            dump_expr(expr->as.unary.operand, indent + 1);
            break;
        case DI_AST_FIELD_EXPR:
            printf("Field(%s)\n", expr->as.field.field_name);
            dump_expr(expr->as.field.base, indent + 1);
            break;
        case DI_AST_STRUCT_INIT_EXPR:
            printf("StructInit(%s)\n", expr->as.struct_init.type_name);
            for (i = 0; i < expr->as.struct_init.field_count; ++i) {
                dump_indent(indent + 1);
                printf("InitField(%s)\n", expr->as.struct_init.fields[i].name);
                dump_expr(expr->as.struct_init.fields[i].value, indent + 2);
            }
            break;
        case DI_AST_INDEX_EXPR:
            printf("Index\n");
            dump_expr(expr->as.index.base, indent + 1);
            dump_expr(expr->as.index.index, indent + 1);
            break;
        case DI_AST_ARRAY_INIT_EXPR:
            printf("ArrayInit\n");
            for (i = 0; i < expr->as.array_init.item_count; ++i) {
                dump_expr(expr->as.array_init.items[i], indent + 1);
            }
            break;
        case DI_AST_RANGE_EXPR:
            printf("Range\n");
            dump_expr(expr->as.range.start, indent + 1);
            dump_expr(expr->as.range.end, indent + 1);
            break;
        default:
            printf("%s\n", di_ast_kind_name(expr->kind));
            break;
    }
}

static void dump_block(const DiAstBlock *block, int indent) {
    size_t i;
    for (i = 0; i < block->count; ++i) {
        dump_stmt(block->items[i], indent);
    }
}

static void dump_stmt(const DiAstStmt *stmt, int indent) {
    if (stmt == NULL) {
        return;
    }

    dump_indent(indent);
    switch (stmt->kind) {
        case DI_AST_VAR_STMT:
            printf("Var(%s", stmt->as.var_stmt.name);
            if (stmt->as.var_stmt.type.name != NULL) {
                printf(": %s", stmt->as.var_stmt.type.name);
            }
            printf(")\n");
            dump_expr(stmt->as.var_stmt.value, indent + 1);
            break;
        case DI_AST_ASSIGN_STMT:
            printf("Assign(%s)\n", stmt->as.assign_stmt.name);
            dump_expr(stmt->as.assign_stmt.value, indent + 1);
            break;
        case DI_AST_FIELD_ASSIGN_STMT:
            printf("FieldAssign\n");
            dump_expr(stmt->as.field_assign_stmt.target, indent + 1);
            dump_expr(stmt->as.field_assign_stmt.value, indent + 1);
            break;
        case DI_AST_INDEX_ASSIGN_STMT:
            printf("IndexAssign\n");
            dump_expr(stmt->as.index_assign_stmt.target, indent + 1);
            dump_expr(stmt->as.index_assign_stmt.value, indent + 1);
            break;
        case DI_AST_RETURN_STMT:
            printf("Return\n");
            dump_expr(stmt->as.return_stmt.value, indent + 1);
            break;
        case DI_AST_EXPR_STMT:
            printf("ExprStmt\n");
            dump_expr(stmt->as.expr_stmt.expr, indent + 1);
            break;
        case DI_AST_IF_STMT:
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
        case DI_AST_WHILE_STMT:
            printf("While\n");
            dump_indent(indent + 1);
            printf("Condition\n");
            dump_expr(stmt->as.while_stmt.condition, indent + 2);
            if (stmt->as.while_stmt.update != NULL) {
                dump_indent(indent + 1);
                printf("Update\n");
                dump_stmt(stmt->as.while_stmt.update, indent + 2);
            }
            dump_indent(indent + 1);
            printf("Body\n");
            dump_block(&stmt->as.while_stmt.body, indent + 2);
            break;
        case DI_AST_FLUX_STMT:
            printf("Flux(%s)\n", stmt->as.flux_stmt.name);
            dump_expr(stmt->as.flux_stmt.iterable, indent + 1);
            dump_block(&stmt->as.flux_stmt.body, indent + 1);
            break;
        default:
            printf("%s\n", di_ast_kind_name(stmt->kind));
            break;
    }
}

void di_ast_dump_program(const DiAstProgram *program) {
    size_t i;
    size_t j;

    if (program == NULL) {
        printf("Program(null)\n");
        return;
    }

    printf("Program");
    if (program->package_name != NULL) {
        printf(" package=%s", program->package_name);
    }
    if (program->source_path != NULL) {
        printf(" source=%s", program->source_path);
    }
    printf("\n");
    for (i = 0; i < program->import_count; ++i) {
        dump_indent(1);
        printf("Import(%s)\n", program->imports[i]);
    }
    for (i = 0; i < program->decl_count; ++i) {
        const DiAstDecl *decl = program->decls[i];
        dump_indent(1);
        if (decl->kind == DI_AST_STRUCT_DECL) {
            printf("struct %s\n", decl->name);
            for (j = 0; j < decl->field_count; ++j) {
                dump_indent(2);
                printf("Field(%s: %s)\n", decl->fields[j].name, decl->fields[j].type.name);
            }
            continue;
        }
        if (decl->owner_type != NULL) {
            printf("%s %s.%s -> %s\n", di_ast_kind_name(decl->kind), decl->owner_type, decl->name, decl->return_type.name);
        } else {
            printf("%s %s -> %s\n", di_ast_kind_name(decl->kind), decl->name, decl->return_type.name);
        }
        for (j = 0; j < decl->param_count; ++j) {
            dump_indent(2);
            printf("Param(%s: %s)\n", decl->params[j].name, decl->params[j].type.name);
        }
        for (j = 0; j < decl->body_count; ++j) {
            dump_stmt(decl->body[j], 2);
        }
    }
}

static void free_expr(DiAstExpr *expr) {
    size_t i;

    if (expr == NULL) {
        return;
    }

    switch (expr->kind) {
        case DI_AST_STRING_EXPR:
            free((char *)expr->as.string_value);
            break;
        case DI_AST_IDENT_EXPR:
            free((char *)expr->as.ident_name);
            break;
        case DI_AST_CALL_EXPR:
            free_expr(expr->as.call.callee);
            for (i = 0; i < expr->as.call.arg_count; ++i) {
                free_expr(expr->as.call.args[i]);
            }
            free(expr->as.call.args);
            break;
        case DI_AST_BINARY_EXPR:
            free_expr(expr->as.binary.left);
            free_expr(expr->as.binary.right);
            break;
        case DI_AST_UNARY_EXPR:
            free_expr(expr->as.unary.operand);
            break;
        case DI_AST_FIELD_EXPR:
            free_expr(expr->as.field.base);
            free((char *)expr->as.field.field_name);
            break;
        case DI_AST_STRUCT_INIT_EXPR:
            for (i = 0; i < expr->as.struct_init.field_count; ++i) {
                free((char *)expr->as.struct_init.fields[i].name);
                free_expr(expr->as.struct_init.fields[i].value);
            }
            free((char *)expr->as.struct_init.type_name);
            free(expr->as.struct_init.fields);
            break;
        case DI_AST_INDEX_EXPR:
            free_expr(expr->as.index.base);
            free_expr(expr->as.index.index);
            break;
        case DI_AST_ARRAY_INIT_EXPR:
            for (i = 0; i < expr->as.array_init.item_count; ++i) {
                free_expr(expr->as.array_init.items[i]);
            }
            free(expr->as.array_init.items);
            break;
        case DI_AST_RANGE_EXPR:
            free_expr(expr->as.range.start);
            free_expr(expr->as.range.end);
            break;
        default:
            break;
    }

    free(expr);
}

static void free_stmt(DiAstStmt *stmt) {
    size_t i;

    if (stmt == NULL) {
        return;
    }

    switch (stmt->kind) {
        case DI_AST_VAR_STMT:
            free((char *)stmt->as.var_stmt.name);
            if (stmt->as.var_stmt.has_explicit_type && stmt->as.var_stmt.type.name != NULL) {
                free((char *)stmt->as.var_stmt.type.name);
            }
            free_expr(stmt->as.var_stmt.value);
            break;
        case DI_AST_ASSIGN_STMT:
            free((char *)stmt->as.assign_stmt.name);
            free_expr(stmt->as.assign_stmt.value);
            break;
        case DI_AST_FIELD_ASSIGN_STMT:
            free_expr(stmt->as.field_assign_stmt.target);
            free_expr(stmt->as.field_assign_stmt.value);
            break;
        case DI_AST_INDEX_ASSIGN_STMT:
            free_expr(stmt->as.index_assign_stmt.target);
            free_expr(stmt->as.index_assign_stmt.value);
            break;
        case DI_AST_RETURN_STMT:
            free_expr(stmt->as.return_stmt.value);
            break;
        case DI_AST_EXPR_STMT:
            free_expr(stmt->as.expr_stmt.expr);
            break;
        case DI_AST_IF_STMT:
            free_expr(stmt->as.if_stmt.condition);
            for (i = 0; i < stmt->as.if_stmt.then_block.count; ++i) {
                free_stmt(stmt->as.if_stmt.then_block.items[i]);
            }
            free(stmt->as.if_stmt.then_block.items);
            for (i = 0; i < stmt->as.if_stmt.else_block.count; ++i) {
                free_stmt(stmt->as.if_stmt.else_block.items[i]);
            }
            free(stmt->as.if_stmt.else_block.items);
            break;
        case DI_AST_WHILE_STMT:
            free_expr(stmt->as.while_stmt.condition);
            free_stmt(stmt->as.while_stmt.update);
            for (i = 0; i < stmt->as.while_stmt.body.count; ++i) {
                free_stmt(stmt->as.while_stmt.body.items[i]);
            }
            free(stmt->as.while_stmt.body.items);
            break;
        case DI_AST_FLUX_STMT:
            free((char *)stmt->as.flux_stmt.name);
            free_expr(stmt->as.flux_stmt.iterable);
            for (i = 0; i < stmt->as.flux_stmt.body.count; ++i) {
                free_stmt(stmt->as.flux_stmt.body.items[i]);
            }
            free(stmt->as.flux_stmt.body.items);
            break;
        default:
            break;
    }

    free(stmt);
}

void di_ast_program_free(DiAstProgram *program) {
    size_t i;
    size_t j;

    if (program == NULL) {
        return;
    }

    for (i = 0; i < program->decl_count; ++i) {
        DiAstDecl *decl = program->decls[i];
        free((char *)decl->name);
        free((char *)decl->owner_type);
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

    free((char *)program->package_name);
    free((char *)program->source_path);
    for (i = 0; i < program->import_count; ++i) {
        free(program->imports[i]);
    }
    free(program->imports);
    free(program->decls);
    free(program);
}

const char *di_ast_kind_name(DiAstKind kind) {
    switch (kind) {
        case DI_AST_PROGRAM: return "program";
        case DI_AST_STRUCT_DECL: return "struct_decl";
        case DI_AST_FUNCTION: return "function";
        case DI_AST_EXTERN_FUNCTION: return "extern_function";
        case DI_AST_VAR_STMT: return "var_stmt";
        case DI_AST_ASSIGN_STMT: return "assign_stmt";
        case DI_AST_FIELD_ASSIGN_STMT: return "field_assign_stmt";
        case DI_AST_INDEX_ASSIGN_STMT: return "index_assign_stmt";
        case DI_AST_RETURN_STMT: return "return_stmt";
        case DI_AST_EXPR_STMT: return "expr_stmt";
        case DI_AST_IF_STMT: return "if_stmt";
        case DI_AST_WHILE_STMT: return "while_stmt";
        case DI_AST_FLUX_STMT: return "flux_stmt";
        case DI_AST_INT_EXPR: return "int_expr";
        case DI_AST_BOOL_EXPR: return "bool_expr";
        case DI_AST_STRING_EXPR: return "string_expr";
        case DI_AST_IDENT_EXPR: return "ident_expr";
        case DI_AST_CALL_EXPR: return "call_expr";
        case DI_AST_BINARY_EXPR: return "binary_expr";
        case DI_AST_UNARY_EXPR: return "unary_expr";
        case DI_AST_FIELD_EXPR: return "field_expr";
        case DI_AST_STRUCT_INIT_EXPR: return "struct_init_expr";
        case DI_AST_INDEX_EXPR: return "index_expr";
        case DI_AST_ARRAY_INIT_EXPR: return "array_init_expr";
        case DI_AST_RANGE_EXPR: return "range_expr";
        default: return "unknown";
    }
}

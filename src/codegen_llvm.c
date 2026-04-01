#include "codegen_llvm.h"

#include "diag.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#ifndef DIRI_RUNTIME_SOURCE
#define DIRI_RUNTIME_SOURCE "runtime/runtime.c"
#endif

typedef struct {
    const char *name;
    const char *type_name;
    size_t array_len;
    char ref_name[32];
} LocalBinding;

typedef struct {
    LocalBinding locals[256];
    size_t local_count;
    int temp_id;
    int label_id;
    int string_id;
} LlvmFuncContext;

typedef struct {
    const char *value;
    char global_name[32];
} StringEntry;

static const DiriAstProgram *g_llvm_program = NULL;
static const DiriAstDecl *find_struct_decl_codegen(const DiriAstProgram *program, const char *type_name);
static int find_local(LocalBinding *locals, size_t local_count, const char *name);

static const char *map_runtime_symbol(const char *name) {
    if (strcmp(name, "print_int") == 0) {
        return "diri_runtime_print_int";
    }
    if (strcmp(name, "print_str") == 0) {
        return "diri_runtime_print_str";
    }
    return name;
}

static const char *llvm_type_name(const char *type_name) {
    static char buffer[16][64];
    static int buffer_index = 0;
    if (strcmp(type_name, "int") == 0) return "i32";
    if (strcmp(type_name, "bool") == 0) return "i1";
    if (strcmp(type_name, "void") == 0) return "void";
    if (strcmp(type_name, "str") == 0) return "ptr";
    if (g_llvm_program != NULL && find_struct_decl_codegen(g_llvm_program, type_name) != NULL) {
        buffer_index = (buffer_index + 1) % 16;
        snprintf(buffer[buffer_index], sizeof(buffer[buffer_index]), "%%struct.%s", type_name);
        return buffer[buffer_index];
    }
    return "i32";
}

static const char *llvm_storage_type_name(const char *type_name, size_t array_len) {
    static char buffer[8][64];
    static int buffer_index = 0;

    if (strcmp(type_name, "int[]") == 0) {
        buffer_index = (buffer_index + 1) % 8;
        snprintf(buffer[buffer_index], sizeof(buffer[buffer_index]), "[%zu x i32]", array_len);
        return buffer[buffer_index];
    }
    return llvm_type_name(type_name);
}

static const char *c_type_name(const char *type_name) {
    if (strcmp(type_name, "void") == 0) return "void";
    if (strcmp(type_name, "str") == 0) return "const char *";
    return "int";
}

static int is_int_array_type_codegen(const char *type_name) {
    return strcmp(type_name, "int[]") == 0;
}

static const DiriAstDecl *find_struct_decl_codegen(const DiriAstProgram *program, const char *type_name) {
    size_t i;
    for (i = 0; i < program->decl_count; ++i) {
        if (program->decls[i]->kind == DIRI_AST_STRUCT_DECL &&
            strcmp(program->decls[i]->name, type_name) == 0) {
            return program->decls[i];
        }
    }
    return NULL;
}

static void emit_c_type(FILE *out, const DiriAstProgram *program, const char *type_name) {
    if (program != NULL && find_struct_decl_codegen(program, type_name) != NULL) {
        fprintf(out, "struct %s", type_name);
        return;
    }
    fprintf(out, "%s", c_type_name(type_name));
}

static int find_struct_field_index(const DiriAstDecl *decl, const char *field_name) {
    size_t i;
    for (i = 0; i < decl->field_count; ++i) {
        if (strcmp(decl->fields[i].name, field_name) == 0) {
            return (int)i;
        }
    }
    return -1;
}

static void emit_expr_llvm(FILE *out,
                           const DiriAstExpr *expr,
                           LlvmFuncContext *ctx,
                           StringEntry *strings,
                           size_t string_count,
                           char *result_name,
                           size_t result_size,
                           const char **result_type);

static int emit_field_pointer_llvm(FILE *out,
                                   const DiriAstExpr *target,
                                   LlvmFuncContext *ctx,
                                   char *pointer_name,
                                   size_t pointer_size,
                                   const char **field_type) {
    if (target->kind == DIRI_AST_FIELD_EXPR && target->as.field.base->kind == DIRI_AST_IDENT_EXPR) {
        int local_index = find_local(ctx->locals, ctx->local_count, target->as.field.base->as.ident_name);
        const DiriAstDecl *struct_decl;
        int field_index;

        if (local_index < 0) {
            return 0;
        }
        struct_decl = find_struct_decl_codegen(g_llvm_program, ctx->locals[local_index].type_name);
        field_index = struct_decl != NULL ? find_struct_field_index(struct_decl, target->as.field.field_name) : -1;
        if (struct_decl == NULL || field_index < 0) {
            return 0;
        }
        snprintf(pointer_name, pointer_size, "%%%d", ctx->temp_id++);
        fprintf(out, "  %s = getelementptr inbounds %s, %s* %s, i32 0, i32 %d\n",
                pointer_name,
                llvm_type_name(ctx->locals[local_index].type_name),
                llvm_type_name(ctx->locals[local_index].type_name),
                ctx->locals[local_index].ref_name,
                field_index);
        *field_type = target->inferred_type;
        return 1;
    }
    return 0;
}

static int emit_index_pointer_llvm(FILE *out,
                                   const DiriAstExpr *target,
                                   LlvmFuncContext *ctx,
                                   StringEntry *strings,
                                   size_t string_count,
                                   char *pointer_name,
                                   size_t pointer_size,
                                   const char **item_type) {
    if (target->kind == DIRI_AST_INDEX_EXPR && target->as.index.base->kind == DIRI_AST_IDENT_EXPR) {
        int local_index = find_local(ctx->locals, ctx->local_count, target->as.index.base->as.ident_name);
        if (local_index >= 0 && strcmp(ctx->locals[local_index].type_name, "int[]") == 0) {
            char index_name[256];
            const char *index_type;
            const char *array_storage_type = llvm_storage_type_name("int[]", ctx->locals[local_index].array_len);

            emit_expr_llvm(out, target->as.index.index, ctx, strings, string_count, index_name, sizeof(index_name), &index_type);
            snprintf(pointer_name, pointer_size, "%%%d", ctx->temp_id++);
            fprintf(out, "  %s = getelementptr inbounds %s, %s* %s, i32 0, i32 %s\n",
                    pointer_name,
                    array_storage_type,
                    array_storage_type,
                    ctx->locals[local_index].ref_name,
                    index_name);
            *item_type = target->inferred_type;
            return 1;
        }
    }
    return 0;
}

static int is_comparison_op(DiriBinaryOp op) {
    return op == DIRI_BIN_EQ || op == DIRI_BIN_NE || op == DIRI_BIN_LT || op == DIRI_BIN_GT || op == DIRI_BIN_LE || op == DIRI_BIN_GE;
}

static void make_output_base(const char *input_path, char *buffer, size_t buffer_size) {
    char normalized[256];
    size_t i;
    size_t out = 0;

    for (i = 0; input_path[i] != '\0' && out + 1 < sizeof(normalized); ++i) {
        char c = input_path[i];
        if (c == '/' || c == '\\') {
            normalized[out++] = '_';
        } else if (c == '.') {
            break;
        } else if ((c >= 'a' && c <= 'z') ||
                   (c >= 'A' && c <= 'Z') ||
                   (c >= '0' && c <= '9') ||
                   c == '_' ||
                   c == '-') {
            normalized[out++] = c;
        } else {
            normalized[out++] = '_';
        }
    }
    normalized[out] = '\0';
    snprintf(buffer, buffer_size, "build/%s", normalized);
}

static void emit_llvm_string_constant(FILE *out, const char *global_name, const char *value) {
    size_t len = strlen(value) + 1;
    size_t i;

    fprintf(out, "@%s = private unnamed_addr constant [%zu x i8] c\"", global_name, len);
    for (i = 0; i + 1 < len; ++i) {
        unsigned char ch = (unsigned char)value[i];
        if (ch == '\\' || ch == '"') {
            fprintf(out, "\\%02X", ch);
        } else if (ch < 32 || ch > 126) {
            fprintf(out, "\\%02X", ch);
        } else {
            fputc((int)ch, out);
        }
    }
    fprintf(out, "\\00\"\n");
}

static const char *intern_string_literal(StringEntry *entries, size_t *count, const char *value, int *string_id) {
    size_t i;

    for (i = 0; i < *count; ++i) {
        if (strcmp(entries[i].value, value) == 0) {
            return entries[i].global_name;
        }
    }

    entries[*count].value = value;
    snprintf(entries[*count].global_name, sizeof(entries[*count].global_name), ".str.%d", (*string_id)++);
    (*count)++;
    return entries[*count - 1].global_name;
}

static void collect_strings_expr(const DiriAstExpr *expr, StringEntry *entries, size_t *count, int *string_id);
static void collect_strings_stmt(const DiriAstStmt *stmt, StringEntry *entries, size_t *count, int *string_id);

static void collect_strings_expr(const DiriAstExpr *expr, StringEntry *entries, size_t *count, int *string_id) {
    size_t i;

    if (expr == NULL) {
        return;
    }
    if (expr->kind == DIRI_AST_STRING_EXPR) {
        (void)intern_string_literal(entries, count, expr->as.string_value, string_id);
        return;
    }
    if (expr->kind == DIRI_AST_CALL_EXPR) {
        for (i = 0; i < expr->as.call.arg_count; ++i) {
            collect_strings_expr(expr->as.call.args[i], entries, count, string_id);
        }
        return;
    }
    if (expr->kind == DIRI_AST_FIELD_EXPR) {
        collect_strings_expr(expr->as.field.base, entries, count, string_id);
        return;
    }
    if (expr->kind == DIRI_AST_STRUCT_INIT_EXPR) {
        for (i = 0; i < expr->as.struct_init.field_count; ++i) {
            collect_strings_expr(expr->as.struct_init.fields[i].value, entries, count, string_id);
        }
        return;
    }
    if (expr->kind == DIRI_AST_BINARY_EXPR) {
        collect_strings_expr(expr->as.binary.left, entries, count, string_id);
        collect_strings_expr(expr->as.binary.right, entries, count, string_id);
    }
}

static void collect_strings_block(const DiriAstBlock *block, StringEntry *entries, size_t *count, int *string_id) {
    size_t i;
    for (i = 0; i < block->count; ++i) {
        collect_strings_stmt(block->items[i], entries, count, string_id);
    }
}

static void collect_strings_stmt(const DiriAstStmt *stmt, StringEntry *entries, size_t *count, int *string_id) {
    if (stmt->kind == DIRI_AST_LET_STMT) {
        collect_strings_expr(stmt->as.let_stmt.value, entries, count, string_id);
    } else if (stmt->kind == DIRI_AST_RETURN_STMT) {
        collect_strings_expr(stmt->as.return_stmt.value, entries, count, string_id);
    } else if (stmt->kind == DIRI_AST_EXPR_STMT) {
        collect_strings_expr(stmt->as.expr_stmt.expr, entries, count, string_id);
    } else if (stmt->kind == DIRI_AST_IF_STMT) {
        collect_strings_expr(stmt->as.if_stmt.condition, entries, count, string_id);
        collect_strings_block(&stmt->as.if_stmt.then_block, entries, count, string_id);
        collect_strings_block(&stmt->as.if_stmt.else_block, entries, count, string_id);
    } else if (stmt->kind == DIRI_AST_WHILE_STMT) {
        collect_strings_expr(stmt->as.while_stmt.condition, entries, count, string_id);
        collect_strings_block(&stmt->as.while_stmt.body, entries, count, string_id);
    }
}

static int find_local(LocalBinding *locals, size_t local_count, const char *name) {
    size_t i = local_count;
    while (i > 0) {
        if (strcmp(locals[i - 1].name, name) == 0) {
            return (int)(i - 1);
        }
        i--;
    }
    return -1;
}

static void emit_expr_llvm(FILE *out,
                           const DiriAstExpr *expr,
                           LlvmFuncContext *ctx,
                           StringEntry *strings,
                           size_t string_count,
                           char *result_name,
                           size_t result_size,
                           const char **result_type) {
    if (expr->kind == DIRI_AST_INT_EXPR) {
        snprintf(result_name, result_size, "%ld", expr->as.int_value);
        *result_type = "int";
        return;
    }

    if (expr->kind == DIRI_AST_BOOL_EXPR) {
        snprintf(result_name, result_size, "%d", expr->as.bool_value ? 1 : 0);
        *result_type = "bool";
        return;
    }

    if (expr->kind == DIRI_AST_STRING_EXPR) {
        size_t len = strlen(expr->as.string_value) + 1;
        size_t i;
        const char *global_name = ".str.unknown";
        for (i = 0; i < string_count; ++i) {
            if (strcmp(strings[i].value, expr->as.string_value) == 0) {
                global_name = strings[i].global_name;
                break;
            }
        }
        snprintf(result_name, result_size,
                 "getelementptr inbounds ([%zu x i8], [%zu x i8]* @%s, i64 0, i64 0)",
                 len,
                 len,
                 global_name);
        *result_type = "str";
        return;
    }

    if (expr->kind == DIRI_AST_IDENT_EXPR) {
        int local_index = find_local(ctx->locals, ctx->local_count, expr->as.ident_name);
        if (local_index >= 0) {
            if (strcmp(ctx->locals[local_index].type_name, "int[]") == 0) {
                snprintf(result_name, result_size, "%s", ctx->locals[local_index].ref_name);
                *result_type = ctx->locals[local_index].type_name;
                return;
            }
            snprintf(result_name, result_size, "%%%d", ctx->temp_id++);
            fprintf(out, "  %s = load %s, %s* %s\n",
                    result_name,
                    llvm_type_name(ctx->locals[local_index].type_name),
                    llvm_type_name(ctx->locals[local_index].type_name),
                    ctx->locals[local_index].ref_name);
            *result_type = ctx->locals[local_index].type_name;
            return;
        }
        snprintf(result_name, result_size, "%%%s", expr->as.ident_name);
        *result_type = expr->inferred_type != NULL ? expr->inferred_type : "int";
        return;
    }

    if (expr->kind == DIRI_AST_FIELD_EXPR) {
        if (expr->as.field.base->kind == DIRI_AST_IDENT_EXPR) {
            int local_index = find_local(ctx->locals, ctx->local_count, expr->as.field.base->as.ident_name);
            const DiriAstDecl *struct_decl;
            int field_index;

            if (local_index >= 0) {
                struct_decl = find_struct_decl_codegen(g_llvm_program, ctx->locals[local_index].type_name);
                field_index = struct_decl != NULL ? find_struct_field_index(struct_decl, expr->as.field.field_name) : -1;
                if (struct_decl != NULL && field_index >= 0) {
                    char gep_name[256];
                    snprintf(gep_name, sizeof(gep_name), "%%%d", ctx->temp_id++);
                    fprintf(out, "  %s = getelementptr inbounds %s, %s* %s, i32 0, i32 %d\n",
                            gep_name,
                            llvm_type_name(ctx->locals[local_index].type_name),
                            llvm_type_name(ctx->locals[local_index].type_name),
                            ctx->locals[local_index].ref_name,
                            field_index);
                    snprintf(result_name, result_size, "%%%d", ctx->temp_id++);
                    fprintf(out, "  %s = load %s, %s* %s\n",
                            result_name,
                            llvm_type_name(expr->inferred_type),
                            llvm_type_name(expr->inferred_type),
                            gep_name);
                    *result_type = expr->inferred_type;
                    return;
                }
            }
        }
    }

    if (expr->kind == DIRI_AST_INDEX_EXPR) {
        char gep_name[256];
        if (emit_index_pointer_llvm(out, expr, ctx, strings, string_count, gep_name, sizeof(gep_name), result_type)) {
            snprintf(result_name, result_size, "%%%d", ctx->temp_id++);
            fprintf(out, "  %s = load %s, %s* %s\n",
                    result_name,
                    llvm_type_name(*result_type),
                    llvm_type_name(*result_type),
                    gep_name);
            return;
        }
    }

    if (expr->kind == DIRI_AST_STRUCT_INIT_EXPR) {
        const DiriAstDecl *struct_decl = find_struct_decl_codegen(g_llvm_program, expr->as.struct_init.type_name);
        size_t i;
        snprintf(result_name, result_size, "%%%d", ctx->temp_id++);
        fprintf(out, "  %s = insertvalue %s zeroinitializer, %s 0, 0\n",
                result_name,
                llvm_type_name(expr->as.struct_init.type_name),
                llvm_type_name(struct_decl->fields[0].type.name));
        for (i = 0; i < expr->as.struct_init.field_count; ++i) {
            char field_value[256];
            char next_name[256];
            const char *field_type;
            int field_index = find_struct_field_index(struct_decl, expr->as.struct_init.fields[i].name);
            emit_expr_llvm(out, expr->as.struct_init.fields[i].value, ctx, strings, string_count, field_value, sizeof(field_value), &field_type);
            snprintf(next_name, sizeof(next_name), "%%%d", ctx->temp_id++);
            fprintf(out, "  %s = insertvalue %s %s, %s %s, %d\n",
                    next_name,
                    llvm_type_name(expr->as.struct_init.type_name),
                    result_name,
                    llvm_type_name(field_type),
                    field_value,
                    field_index);
            snprintf(result_name, result_size, "%s", next_name);
        }
        *result_type = expr->as.struct_init.type_name;
        return;
    }

    if (expr->kind == DIRI_AST_BINARY_EXPR) {
        char left_name[256];
        char right_name[256];
        const char *left_type;
        const char *right_type;

        emit_expr_llvm(out, expr->as.binary.left, ctx, strings, string_count, left_name, sizeof(left_name), &left_type);
        emit_expr_llvm(out, expr->as.binary.right, ctx, strings, string_count, right_name, sizeof(right_name), &right_type);

        snprintf(result_name, result_size, "%%%d", ctx->temp_id++);
        if (is_comparison_op(expr->as.binary.op)) {
            const char *pred = "eq";
            switch (expr->as.binary.op) {
                case DIRI_BIN_EQ: pred = "eq"; break;
                case DIRI_BIN_NE: pred = "ne"; break;
                case DIRI_BIN_LT: pred = "slt"; break;
                case DIRI_BIN_GT: pred = "sgt"; break;
                case DIRI_BIN_LE: pred = "sle"; break;
                case DIRI_BIN_GE: pred = "sge"; break;
                default: break;
            }
            fprintf(out, "  %s = icmp %s %s %s, %s\n",
                    result_name,
                    pred,
                    llvm_type_name(left_type),
                    left_name,
                    right_name);
            *result_type = "bool";
            return;
        }

        fprintf(out, "  %s = %s %s %s, %s\n",
                result_name,
                expr->as.binary.op == DIRI_BIN_ADD ? "add" :
                expr->as.binary.op == DIRI_BIN_SUB ? "sub" :
                expr->as.binary.op == DIRI_BIN_MUL ? "mul" : "sdiv",
                llvm_type_name(left_type),
                left_name,
                right_name);
        *result_type = "int";
        return;
    }

    if (expr->kind == DIRI_AST_CALL_EXPR) {
        size_t i;
        char arg_buffer[1024];
        size_t offset = 0;
        const char *callee_type = expr->inferred_type != NULL ? expr->inferred_type : "int";

        arg_buffer[0] = '\0';
        for (i = 0; i < expr->as.call.arg_count; ++i) {
            char arg_name[256];
            const char *arg_type;

            emit_expr_llvm(out, expr->as.call.args[i], ctx, strings, string_count, arg_name, sizeof(arg_name), &arg_type);
            offset += (size_t)snprintf(arg_buffer + offset,
                                       sizeof(arg_buffer) - offset,
                                       "%s%s %s",
                                       i == 0 ? "" : ", ",
                                       llvm_type_name(arg_type),
                                       arg_name);
        }

        if (strcmp(callee_type, "void") == 0) {
            fprintf(out, "  call void @%s(%s)\n", map_runtime_symbol(expr->as.call.callee), arg_buffer);
            snprintf(result_name, result_size, "0");
            *result_type = "void";
        } else {
            snprintf(result_name, result_size, "%%%d", ctx->temp_id++);
            fprintf(out, "  %s = call %s @%s(%s)\n",
                    result_name,
                    llvm_type_name(callee_type),
                    map_runtime_symbol(expr->as.call.callee),
                    arg_buffer);
            *result_type = callee_type;
        }
        return;
    }
}

static int stmt_guarantees_return(const DiriAstStmt *stmt);
static int block_guarantees_return(DiriAstStmt **items, size_t count);
static void emit_stmt_list_llvm(FILE *out, DiriAstStmt **items, size_t count, LlvmFuncContext *ctx, StringEntry *strings, size_t string_count);
static void emit_block_llvm(FILE *out, DiriAstStmt **items, size_t count, LlvmFuncContext *ctx, StringEntry *strings, size_t string_count);

static void emit_stmt_llvm(FILE *out, const DiriAstStmt *stmt, LlvmFuncContext *ctx, StringEntry *strings, size_t string_count) {
    if (stmt->kind == DIRI_AST_LET_STMT) {
        char value_name[256];
        const char *value_type;

        snprintf(ctx->locals[ctx->local_count].ref_name, sizeof(ctx->locals[ctx->local_count].ref_name), "%%slot%d", ctx->temp_id++);
        ctx->locals[ctx->local_count].name = stmt->as.let_stmt.name;
        ctx->locals[ctx->local_count].type_name = stmt->as.let_stmt.type.name;
        ctx->locals[ctx->local_count].array_len = 0;

        if (strcmp(stmt->as.let_stmt.type.name, "int[]") == 0 &&
            stmt->as.let_stmt.value != NULL &&
            stmt->as.let_stmt.value->kind == DIRI_AST_ARRAY_INIT_EXPR) {
            size_t i;
            size_t array_len = stmt->as.let_stmt.value->as.array_init.item_count;
            const char *array_storage_type = llvm_storage_type_name("int[]", array_len);

            ctx->locals[ctx->local_count].array_len = array_len;
            fprintf(out, "  %s = alloca %s\n",
                    ctx->locals[ctx->local_count].ref_name,
                    array_storage_type);
            for (i = 0; i < array_len; ++i) {
                char item_name[256];
                char gep_name[256];
                const char *item_type;

                emit_expr_llvm(out,
                               stmt->as.let_stmt.value->as.array_init.items[i],
                               ctx,
                               strings,
                               string_count,
                               item_name,
                               sizeof(item_name),
                               &item_type);
                snprintf(gep_name, sizeof(gep_name), "%%%d", ctx->temp_id++);
                fprintf(out, "  %s = getelementptr inbounds %s, %s* %s, i32 0, i32 %zu\n",
                        gep_name,
                        array_storage_type,
                        array_storage_type,
                        ctx->locals[ctx->local_count].ref_name,
                        i);
                fprintf(out, "  store i32 %s, i32* %s\n", item_name, gep_name);
            }
            ctx->local_count++;
            return;
        }

        emit_expr_llvm(out, stmt->as.let_stmt.value, ctx, strings, string_count, value_name, sizeof(value_name), &value_type);
        fprintf(out, "  %s = alloca %s\n",
                ctx->locals[ctx->local_count].ref_name,
                llvm_storage_type_name(ctx->locals[ctx->local_count].type_name, 0));
        fprintf(out, "  store %s %s, %s* %s\n",
                llvm_type_name(ctx->locals[ctx->local_count].type_name),
                value_name,
                llvm_type_name(ctx->locals[ctx->local_count].type_name),
                ctx->locals[ctx->local_count].ref_name);
        ctx->local_count++;
        return;
    }

    if (stmt->kind == DIRI_AST_ASSIGN_STMT) {
        int local_index = find_local(ctx->locals, ctx->local_count, stmt->as.assign_stmt.name);
        char value_name[256];
        const char *value_type;

        if (local_index < 0) {
            return;
        }
        emit_expr_llvm(out, stmt->as.assign_stmt.value, ctx, strings, string_count, value_name, sizeof(value_name), &value_type);
        fprintf(out, "  store %s %s, %s* %s\n",
                llvm_type_name(ctx->locals[local_index].type_name),
                value_name,
                llvm_type_name(ctx->locals[local_index].type_name),
                ctx->locals[local_index].ref_name);
        return;
    }

    if (stmt->kind == DIRI_AST_FIELD_ASSIGN_STMT) {
        char pointer_name[256];
        char value_name[256];
        const char *field_type;
        const char *value_type;

        if (!emit_field_pointer_llvm(out, stmt->as.field_assign_stmt.target, ctx, pointer_name, sizeof(pointer_name), &field_type)) {
            return;
        }
        emit_expr_llvm(out, stmt->as.field_assign_stmt.value, ctx, strings, string_count, value_name, sizeof(value_name), &value_type);
        fprintf(out, "  store %s %s, %s* %s\n",
                llvm_type_name(field_type),
                value_name,
                llvm_type_name(field_type),
                pointer_name);
        return;
    }

    if (stmt->kind == DIRI_AST_INDEX_ASSIGN_STMT) {
        char pointer_name[256];
        char value_name[256];
        const char *item_type;
        const char *value_type;

        if (!emit_index_pointer_llvm(out, stmt->as.index_assign_stmt.target, ctx, strings, string_count, pointer_name, sizeof(pointer_name), &item_type)) {
            return;
        }
        emit_expr_llvm(out, stmt->as.index_assign_stmt.value, ctx, strings, string_count, value_name, sizeof(value_name), &value_type);
        fprintf(out, "  store %s %s, %s* %s\n",
                llvm_type_name(item_type),
                value_name,
                llvm_type_name(item_type),
                pointer_name);
        return;
    }

    if (stmt->kind == DIRI_AST_EXPR_STMT) {
        char ignored_name[256];
        const char *ignored_type;
        emit_expr_llvm(out, stmt->as.expr_stmt.expr, ctx, strings, string_count, ignored_name, sizeof(ignored_name), &ignored_type);
        return;
    }

    if (stmt->kind == DIRI_AST_RETURN_STMT) {
        char value_name[256];
        const char *value_type;
        emit_expr_llvm(out, stmt->as.return_stmt.value, ctx, strings, string_count, value_name, sizeof(value_name), &value_type);
        fprintf(out, "  ret %s %s\n", llvm_type_name(value_type), value_name);
        return;
    }

    if (stmt->kind == DIRI_AST_IF_STMT) {
        int then_id = ctx->label_id++;
        int else_id = ctx->label_id++;
        int end_id = ctx->label_id++;
        char cond_name[256];
        const char *cond_type;

        emit_expr_llvm(out, stmt->as.if_stmt.condition, ctx, strings, string_count, cond_name, sizeof(cond_name), &cond_type);
        if (strcmp(cond_type, "int") == 0) {
            char bool_name[256];
            snprintf(bool_name, sizeof(bool_name), "%%%d", ctx->temp_id++);
            fprintf(out, "  %s = icmp ne i32 %s, 0\n", bool_name, cond_name);
            strcpy(cond_name, bool_name);
        }
        fprintf(out, "  br i1 %s, label %%then%d, label %%else%d\n", cond_name, then_id, else_id);
        fprintf(out, "then%d:\n", then_id);
        emit_block_llvm(out, stmt->as.if_stmt.then_block.items, stmt->as.if_stmt.then_block.count, ctx, strings, string_count);
        if (!block_guarantees_return(stmt->as.if_stmt.then_block.items, stmt->as.if_stmt.then_block.count)) {
            fprintf(out, "  br label %%endif%d\n", end_id);
        }
        fprintf(out, "else%d:\n", else_id);
        emit_block_llvm(out, stmt->as.if_stmt.else_block.items, stmt->as.if_stmt.else_block.count, ctx, strings, string_count);
        if (!block_guarantees_return(stmt->as.if_stmt.else_block.items, stmt->as.if_stmt.else_block.count)) {
            fprintf(out, "  br label %%endif%d\n", end_id);
        }
        if (!block_guarantees_return(stmt->as.if_stmt.then_block.items, stmt->as.if_stmt.then_block.count) ||
            !block_guarantees_return(stmt->as.if_stmt.else_block.items, stmt->as.if_stmt.else_block.count)) {
            fprintf(out, "endif%d:\n", end_id);
        }
        return;
    }

    if (stmt->kind == DIRI_AST_WHILE_STMT) {
        int cond_id = ctx->label_id++;
        int body_id = ctx->label_id++;
        int end_id = ctx->label_id++;
        char cond_name[256];
        const char *cond_type;

        fprintf(out, "  br label %%whilecond%d\n", cond_id);
        fprintf(out, "whilecond%d:\n", cond_id);
        emit_expr_llvm(out, stmt->as.while_stmt.condition, ctx, strings, string_count, cond_name, sizeof(cond_name), &cond_type);
        if (strcmp(cond_type, "int") == 0) {
            char bool_name[256];
            snprintf(bool_name, sizeof(bool_name), "%%%d", ctx->temp_id++);
            fprintf(out, "  %s = icmp ne i32 %s, 0\n", bool_name, cond_name);
            strcpy(cond_name, bool_name);
        }
        fprintf(out, "  br i1 %s, label %%whilebody%d, label %%whileend%d\n", cond_name, body_id, end_id);
        fprintf(out, "whilebody%d:\n", body_id);
        emit_block_llvm(out, stmt->as.while_stmt.body.items, stmt->as.while_stmt.body.count, ctx, strings, string_count);
        if (!block_guarantees_return(stmt->as.while_stmt.body.items, stmt->as.while_stmt.body.count)) {
            fprintf(out, "  br label %%whilecond%d\n", cond_id);
        }
        fprintf(out, "whileend%d:\n", end_id);
    }
}

static void emit_block_llvm(FILE *out, DiriAstStmt **items, size_t count, LlvmFuncContext *ctx, StringEntry *strings, size_t string_count) {
    size_t saved_local_count = ctx->local_count;
    emit_stmt_list_llvm(out, items, count, ctx, strings, string_count);
    ctx->local_count = saved_local_count;
}

static int stmt_guarantees_return(const DiriAstStmt *stmt) {
    if (stmt->kind == DIRI_AST_RETURN_STMT) {
        return 1;
    }
    if (stmt->kind == DIRI_AST_IF_STMT) {
        return block_guarantees_return(stmt->as.if_stmt.then_block.items, stmt->as.if_stmt.then_block.count) &&
               block_guarantees_return(stmt->as.if_stmt.else_block.items, stmt->as.if_stmt.else_block.count);
    }
    return 0;
}

static int block_guarantees_return(DiriAstStmt **items, size_t count) {
    if (count == 0) {
        return 0;
    }
    return stmt_guarantees_return(items[count - 1]);
}

static void emit_stmt_list_llvm(FILE *out, DiriAstStmt **items, size_t count, LlvmFuncContext *ctx, StringEntry *strings, size_t string_count) {
    size_t i;
    for (i = 0; i < count; ++i) {
        emit_stmt_llvm(out, items[i], ctx, strings, string_count);
    }
}

int diri_codegen_emit_llvm_ir(const DiriAstProgram *program, const char *input_path) {
    char output_base[256];
    char output_path[300];
    FILE *out;
    size_t i;
    StringEntry strings[256];
    size_t string_count = 0;
    int string_id = 0;

    if (program == NULL) {
        return 1;
    }
    g_llvm_program = program;

    if (system("mkdir -p build") != 0) {
        diri_error("failed to create build directory");
        return 1;
    }

    make_output_base(input_path, output_base, sizeof(output_base));
    snprintf(output_path, sizeof(output_path), "%s.ll", output_base);

    out = fopen(output_path, "wb");
    if (out == NULL) {
        diri_error("failed to open LLVM IR output: %s", output_path);
        return 1;
    }

    fprintf(out, "; Generated by diri\n");
    for (i = 0; i < program->decl_count; ++i) {
        const DiriAstDecl *decl = program->decls[i];
        size_t j;
        if (decl->kind != DIRI_AST_STRUCT_DECL) {
            continue;
        }
        fprintf(out, "%%struct.%s = type { ", decl->name);
        for (j = 0; j < decl->field_count; ++j) {
            fprintf(out, "%s%s", j == 0 ? "" : ", ", llvm_type_name(decl->fields[j].type.name));
        }
        fprintf(out, " }\n");
    }
    if (program->decl_count != 0) {
        fprintf(out, "\n");
    }
    for (i = 0; i < program->decl_count; ++i) {
        const DiriAstDecl *decl = program->decls[i];
        size_t j;
        for (j = 0; j < decl->body_count; ++j) {
            collect_strings_stmt(decl->body[j], strings, &string_count, &string_id);
        }
    }
    for (i = 0; i < string_count; ++i) {
        emit_llvm_string_constant(out, strings[i].global_name, strings[i].value);
    }
    if (string_count != 0) {
        fprintf(out, "\n");
    }
    for (i = 0; i < program->decl_count; ++i) {
        const DiriAstDecl *decl = program->decls[i];
        size_t j;

        if (decl->kind == DIRI_AST_EXTERN_FUNCTION) {
            fprintf(out, "declare %s @%s(",
                    llvm_type_name(decl->return_type.name),
                    map_runtime_symbol(decl->name));
            for (j = 0; j < decl->param_count; ++j) {
                fprintf(out, "%s%s",
                        j == 0 ? "" : ", ",
                        llvm_type_name(decl->params[j].type.name));
            }
            fprintf(out, ")\n\n");
            continue;
        }
    }

    for (i = 0; i < program->decl_count; ++i) {
        const DiriAstDecl *decl = program->decls[i];
        size_t j;
        LlvmFuncContext ctx;

        memset(&ctx, 0, sizeof(ctx));
        ctx.temp_id = 1;

        if (decl->kind != DIRI_AST_FUNCTION) {
            continue;
        }

        fprintf(out, "define %s @%s(",
                llvm_type_name(decl->return_type.name),
                decl->name);
        for (j = 0; j < decl->param_count; ++j) {
            fprintf(out, "%s%s %%%s",
                    j == 0 ? "" : ", ",
                    llvm_type_name(decl->params[j].type.name),
                    decl->params[j].name);
        }
        fprintf(out, ") {\nentry:\n");

        for (j = 0; j < decl->param_count; ++j) {
            snprintf(ctx.locals[ctx.local_count].ref_name, sizeof(ctx.locals[ctx.local_count].ref_name), "%%slot%d", ctx.temp_id++);
            ctx.locals[ctx.local_count].name = decl->params[j].name;
            ctx.locals[ctx.local_count].type_name = decl->params[j].type.name;
            fprintf(out, "  %s = alloca %s\n",
                    ctx.locals[ctx.local_count].ref_name,
                    llvm_storage_type_name(ctx.locals[ctx.local_count].type_name, 0));
            fprintf(out, "  store %s %%%s, %s* %s\n",
                    llvm_type_name(ctx.locals[ctx.local_count].type_name),
                    decl->params[j].name,
                    llvm_type_name(ctx.locals[ctx.local_count].type_name),
                    ctx.locals[ctx.local_count].ref_name);
            ctx.locals[ctx.local_count].array_len = 0;
            ctx.local_count++;
        }

        emit_stmt_list_llvm(out, decl->body, decl->body_count, &ctx, strings, string_count);

        if (!block_guarantees_return(decl->body, decl->body_count) && strcmp(decl->return_type.name, "void") == 0) {
            fprintf(out, "  ret void\n");
        }
        fprintf(out, "}\n\n");
    }

    fclose(out);
    diri_info("wrote LLVM IR to %s", output_path);
    return 0;
}

static void emit_c_string(FILE *out, const char *value) {
    const unsigned char *p = (const unsigned char *)value;
    fputc('"', out);
    while (*p != '\0') {
        if (*p == '\\' || *p == '"') {
            fprintf(out, "\\%c", *p);
        } else if (*p == '\n') {
            fprintf(out, "\\n");
        } else {
            fputc(*p, out);
        }
        p++;
    }
    fputc('"', out);
}

static void emit_expr_c(FILE *out, const DiriAstExpr *expr) {
    size_t i;

    switch (expr->kind) {
        case DIRI_AST_INT_EXPR:
            fprintf(out, "%ld", expr->as.int_value);
            break;
        case DIRI_AST_BOOL_EXPR:
            fprintf(out, "%d", expr->as.bool_value ? 1 : 0);
            break;
        case DIRI_AST_STRING_EXPR:
            emit_c_string(out, expr->as.string_value);
            break;
        case DIRI_AST_IDENT_EXPR:
            fprintf(out, "%s", expr->as.ident_name);
            break;
        case DIRI_AST_FIELD_EXPR:
            emit_expr_c(out, expr->as.field.base);
            fprintf(out, ".%s", expr->as.field.field_name);
            break;
        case DIRI_AST_CALL_EXPR:
            fprintf(out, "%s(", map_runtime_symbol(expr->as.call.callee));
            for (i = 0; i < expr->as.call.arg_count; ++i) {
                if (i != 0) {
                    fprintf(out, ", ");
                }
                emit_expr_c(out, expr->as.call.args[i]);
            }
            fprintf(out, ")");
            break;
        case DIRI_AST_BINARY_EXPR:
            fprintf(out, "(");
            emit_expr_c(out, expr->as.binary.left);
            fprintf(out, " %s ", diri_binary_op_name(expr->as.binary.op));
            emit_expr_c(out, expr->as.binary.right);
            fprintf(out, ")");
            break;
        case DIRI_AST_STRUCT_INIT_EXPR:
            fprintf(out, "(struct %s){", expr->as.struct_init.type_name);
            for (i = 0; i < expr->as.struct_init.field_count; ++i) {
                if (i != 0) {
                    fprintf(out, ", ");
                }
                fprintf(out, ".%s = ", expr->as.struct_init.fields[i].name);
                emit_expr_c(out, expr->as.struct_init.fields[i].value);
            }
            fprintf(out, "}");
            break;
        case DIRI_AST_INDEX_EXPR:
            emit_expr_c(out, expr->as.index.base);
            fprintf(out, "[");
            emit_expr_c(out, expr->as.index.index);
            fprintf(out, "]");
            break;
        case DIRI_AST_ARRAY_INIT_EXPR:
            fprintf(out, "{");
            for (i = 0; i < expr->as.array_init.item_count; ++i) {
                if (i != 0) {
                    fprintf(out, ", ");
                }
                emit_expr_c(out, expr->as.array_init.items[i]);
            }
            fprintf(out, "}");
            break;
        default:
            fprintf(out, "0");
            break;
    }
}

static void emit_stmt_list_c(FILE *out, const DiriAstProgram *program, DiriAstStmt **items, size_t count, int indent);

static void emit_indent(FILE *out, int indent) {
    int i;
    for (i = 0; i < indent; ++i) {
        fprintf(out, "    ");
    }
}

static void emit_stmt_c(FILE *out, const DiriAstProgram *program, const DiriAstStmt *stmt, int indent) {
    size_t i;

    if (stmt->kind == DIRI_AST_LET_STMT) {
        emit_indent(out, indent);
        if (is_int_array_type_codegen(stmt->as.let_stmt.type.name) &&
            stmt->as.let_stmt.value != NULL &&
            stmt->as.let_stmt.value->kind == DIRI_AST_ARRAY_INIT_EXPR) {
            fprintf(out, "int %s[%zu] = ", stmt->as.let_stmt.name, stmt->as.let_stmt.value->as.array_init.item_count);
            emit_expr_c(out, stmt->as.let_stmt.value);
            fprintf(out, ";\n");
        } else {
            emit_c_type(out, program, stmt->as.let_stmt.type.name);
            fprintf(out, " %s = ", stmt->as.let_stmt.name);
            emit_expr_c(out, stmt->as.let_stmt.value);
            fprintf(out, ";\n");
        }
        return;
    }

    if (stmt->kind == DIRI_AST_ASSIGN_STMT) {
        emit_indent(out, indent);
        fprintf(out, "%s = ", stmt->as.assign_stmt.name);
        emit_expr_c(out, stmt->as.assign_stmt.value);
        fprintf(out, ";\n");
        return;
    }

    if (stmt->kind == DIRI_AST_FIELD_ASSIGN_STMT) {
        emit_indent(out, indent);
        emit_expr_c(out, stmt->as.field_assign_stmt.target);
        fprintf(out, " = ");
        emit_expr_c(out, stmt->as.field_assign_stmt.value);
        fprintf(out, ";\n");
        return;
    }

    if (stmt->kind == DIRI_AST_INDEX_ASSIGN_STMT) {
        emit_indent(out, indent);
        emit_expr_c(out, stmt->as.index_assign_stmt.target);
        fprintf(out, " = ");
        emit_expr_c(out, stmt->as.index_assign_stmt.value);
        fprintf(out, ";\n");
        return;
    }

    if (stmt->kind == DIRI_AST_EXPR_STMT) {
        emit_indent(out, indent);
        emit_expr_c(out, stmt->as.expr_stmt.expr);
        fprintf(out, ";\n");
        return;
    }

    if (stmt->kind == DIRI_AST_RETURN_STMT) {
        emit_indent(out, indent);
        fprintf(out, "return ");
        emit_expr_c(out, stmt->as.return_stmt.value);
        fprintf(out, ";\n");
        return;
    }

    if (stmt->kind == DIRI_AST_IF_STMT) {
        emit_indent(out, indent);
        fprintf(out, "if (");
        emit_expr_c(out, stmt->as.if_stmt.condition);
        fprintf(out, ") {\n");
        emit_stmt_list_c(out, program, stmt->as.if_stmt.then_block.items, stmt->as.if_stmt.then_block.count, indent + 1);
        emit_indent(out, indent);
        fprintf(out, "}");
        if (stmt->as.if_stmt.else_block.count != 0) {
            fprintf(out, " else {\n");
            emit_stmt_list_c(out, program, stmt->as.if_stmt.else_block.items, stmt->as.if_stmt.else_block.count, indent + 1);
            emit_indent(out, indent);
            fprintf(out, "}");
        }
        fprintf(out, "\n");
        return;
    }

    if (stmt->kind == DIRI_AST_WHILE_STMT) {
        emit_indent(out, indent);
        fprintf(out, "while (");
        emit_expr_c(out, stmt->as.while_stmt.condition);
        fprintf(out, ") {\n");
        emit_stmt_list_c(out, program, stmt->as.while_stmt.body.items, stmt->as.while_stmt.body.count, indent + 1);
        emit_indent(out, indent);
        fprintf(out, "}\n");
        return;
    }

    (void)i;
}

static void emit_stmt_list_c(FILE *out, const DiriAstProgram *program, DiriAstStmt **items, size_t count, int indent) {
    size_t i;
    for (i = 0; i < count; ++i) {
        emit_stmt_c(out, program, items[i], indent);
    }
}

int diri_codegen_build_native(const DiriAstProgram *program, const char *input_path, int run_after_build) {
    char output_base[256];
    char c_path[300];
    char exe_path[300];
    char command[1024];
    FILE *out;
    size_t i;

    if (program == NULL) {
        return 1;
    }

    make_output_base(input_path, output_base, sizeof(output_base));
    snprintf(c_path, sizeof(c_path), "%s.c", output_base);
    snprintf(exe_path, sizeof(exe_path), "%s", output_base);

    out = fopen(c_path, "wb");
    if (out == NULL) {
        diri_error("failed to open native output source: %s", c_path);
        return 1;
    }

    fprintf(out, "#include <stdio.h>\n\n");
    fprintf(out, "extern void diri_runtime_print_int(int x);\n");
    fprintf(out, "extern void diri_runtime_print_str(const char *x);\n\n");

    for (i = 0; i < program->decl_count; ++i) {
        const DiriAstDecl *decl = program->decls[i];
        size_t j;
        if (decl->kind != DIRI_AST_STRUCT_DECL) {
            continue;
        }
        fprintf(out, "struct %s {\n", decl->name);
        for (j = 0; j < decl->field_count; ++j) {
            fprintf(out, "    ");
            emit_c_type(out, program, decl->fields[j].type.name);
            fprintf(out, " %s;\n", decl->fields[j].name);
        }
        fprintf(out, "};\n\n");
    }

    for (i = 0; i < program->decl_count; ++i) {
        const DiriAstDecl *decl = program->decls[i];
        size_t j;

        if (decl->kind == DIRI_AST_EXTERN_FUNCTION || decl->kind == DIRI_AST_STRUCT_DECL) {
            continue;
        }

        emit_c_type(out, program, decl->return_type.name);
        fprintf(out, " %s(", decl->name);
        for (j = 0; j < decl->param_count; ++j) {
            fprintf(out, "%s", j == 0 ? "" : ", ");
            emit_c_type(out, program, decl->params[j].type.name);
            fprintf(out, " %s", decl->params[j].name);
        }
        fprintf(out, ") {\n");
        emit_stmt_list_c(out, program, decl->body, decl->body_count, 1);
        if (strcmp(decl->return_type.name, "void") == 0) {
            fprintf(out, "    return;\n");
        }
        fprintf(out, "}\n\n");
    }

    fclose(out);

    snprintf(command,
             sizeof(command),
             "cc \"%s\" \"%s\" -o \"%s\"",
             c_path,
             DIRI_RUNTIME_SOURCE,
             exe_path);
    if (system(command) != 0) {
        diri_error("failed to build native executable with cc");
        return 1;
    }

    diri_info("built native executable at %s", exe_path);

    if (run_after_build) {
        snprintf(command, sizeof(command), "\"%s\"", exe_path);
        if (system(command) != 0) {
            diri_error("failed to run executable: %s", exe_path);
            return 1;
        }
    }

    return 0;
}

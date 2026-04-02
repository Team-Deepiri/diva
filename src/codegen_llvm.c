#include "codegen_llvm.h"

#include "diag.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#ifndef DI_RUNTIME_SOURCE
#define DI_RUNTIME_SOURCE "runtime/runtime.c"
#endif

typedef struct {
    const DiIrProgram *program;
} Ctx;

static const DiIrDecl *find_struct_decl(const DiIrProgram *program, const char *type_name) {
    size_t i;
    for (i = 0; i < program->decl_count; ++i) {
        if (program->decls[i].kind == DI_IR_STRUCT_DECL &&
            strcmp(program->decls[i].name, type_name) == 0) {
            return &program->decls[i];
        }
    }
    return NULL;
}

static const char *map_runtime_symbol(const char *name) {
    if (strcmp(name, "print_int") == 0) return "di_runtime_print_int";
    if (strcmp(name, "print_str") == 0) return "di_runtime_print_str";
    return name;
}

static const char *callable_symbol_name(const DiAstExpr *call_expr) {
    static char buffer[16][128];
    static int index = 0;

    if (call_expr->as.call.callee->kind == DI_AST_FIELD_EXPR) {
        const char *owner_type = call_expr->as.call.callee->as.field.base->inferred_type;
        index = (index + 1) % 16;
        snprintf(buffer[index], sizeof(buffer[index]), "%s_%s", owner_type, call_expr->as.call.resolved_name);
        return buffer[index];
    }
    return map_runtime_symbol(call_expr->as.call.resolved_name != NULL
                                  ? call_expr->as.call.resolved_name
                                  : call_expr->as.call.callee->as.ident_name);
}

static const char *c_type_name(const DiIrProgram *program, const char *type_name) {
    static char buffer[16][128];
    static int index = 0;

    if (strcmp(type_name, "int") == 0) return "int";
    if (strcmp(type_name, "bool") == 0) return "int";
    if (strcmp(type_name, "str") == 0) return "const char *";
    if (strcmp(type_name, "void") == 0) return "void";
    if (find_struct_decl(program, type_name) != NULL) {
        index = (index + 1) % 16;
        snprintf(buffer[index], sizeof(buffer[index]), "struct %s", type_name);
        return buffer[index];
    }
    return "int";
}

static void make_output_base(const char *input_path, char *buffer, size_t buffer_size) {
    char normalized[256];
    const char *base_name = input_path;
    unsigned long hash = 5381UL;
    size_t i;
    size_t out = 0;

    for (i = 0; input_path[i] != '\0'; ++i) {
        hash = ((hash << 5) + hash) + (unsigned char)input_path[i];
        if (input_path[i] == '/' || input_path[i] == '\\') {
            base_name = input_path + i + 1;
        }
    }

    for (i = 0; base_name[i] != '\0' && out + 1 < sizeof(normalized); ++i) {
        char c = base_name[i];
        if (c == '.') break;
        if ((c >= 'a' && c <= 'z') ||
            (c >= 'A' && c <= 'Z') ||
            (c >= '0' && c <= '9') ||
            c == '_' || c == '-') {
            normalized[out++] = c;
        } else {
            normalized[out++] = '_';
        }
    }
    normalized[out] = '\0';
    snprintf(buffer, buffer_size, "build/%s_%08lx", normalized, hash & 0xffffffffUL);
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

static void emit_expr_c(FILE *out, const DiAstExpr *expr);

static void emit_call_args_c(FILE *out, const DiAstExpr *expr) {
    size_t i;
    if (expr->as.call.callee->kind == DI_AST_FIELD_EXPR) {
        emit_expr_c(out, expr->as.call.callee->as.field.base);
        if (expr->as.call.arg_count != 0) {
            fprintf(out, ", ");
        }
    }
    for (i = 0; i < expr->as.call.arg_count; ++i) {
        if (i != 0) {
            fprintf(out, ", ");
        }
        emit_expr_c(out, expr->as.call.args[i]);
    }
}

static void emit_expr_c(FILE *out, const DiAstExpr *expr) {
    size_t i;

    switch (expr->kind) {
        case DI_AST_INT_EXPR:
            fprintf(out, "%ld", expr->as.int_value);
            break;
        case DI_AST_BOOL_EXPR:
            fprintf(out, "%d", expr->as.bool_value ? 1 : 0);
            break;
        case DI_AST_STRING_EXPR:
            emit_c_string(out, expr->as.string_value);
            break;
        case DI_AST_IDENT_EXPR:
            fprintf(out, "%s", expr->as.ident_name);
            break;
        case DI_AST_CALL_EXPR:
            fprintf(out, "%s(", callable_symbol_name(expr));
            emit_call_args_c(out, expr);
            fprintf(out, ")");
            break;
        case DI_AST_BINARY_EXPR:
            fprintf(out, "(");
            emit_expr_c(out, expr->as.binary.left);
            fprintf(out,
                    " %s ",
                    expr->as.binary.op == DI_BIN_AND ? "&&" :
                    expr->as.binary.op == DI_BIN_OR ? "||" :
                    expr->as.binary.op == DI_BIN_EQ ? "==" :
                    expr->as.binary.op == DI_BIN_NE ? "!=" :
                    expr->as.binary.op == DI_BIN_LT ? "<" :
                    expr->as.binary.op == DI_BIN_GT ? ">" :
                    expr->as.binary.op == DI_BIN_LE ? "<=" :
                    expr->as.binary.op == DI_BIN_GE ? ">=" :
                    expr->as.binary.op == DI_BIN_ADD ? "+" :
                    expr->as.binary.op == DI_BIN_SUB ? "-" :
                    expr->as.binary.op == DI_BIN_MUL ? "*" : "/");
            emit_expr_c(out, expr->as.binary.right);
            fprintf(out, ")");
            break;
        case DI_AST_UNARY_EXPR:
            fprintf(out, "(!");
            emit_expr_c(out, expr->as.unary.operand);
            fprintf(out, ")");
            break;
        case DI_AST_FIELD_EXPR:
            emit_expr_c(out, expr->as.field.base);
            fprintf(out, ".%s", expr->as.field.field_name);
            break;
        case DI_AST_STRUCT_INIT_EXPR:
            fprintf(out, "(struct %s){", expr->as.struct_init.type_name);
            for (i = 0; i < expr->as.struct_init.field_count; ++i) {
                if (i != 0) fprintf(out, ", ");
                fprintf(out, ".%s = ", expr->as.struct_init.fields[i].name);
                emit_expr_c(out, expr->as.struct_init.fields[i].value);
            }
            fprintf(out, "}");
            break;
        case DI_AST_INDEX_EXPR:
            emit_expr_c(out, expr->as.index.base);
            fprintf(out, "[");
            emit_expr_c(out, expr->as.index.index);
            fprintf(out, "]");
            break;
        case DI_AST_ARRAY_INIT_EXPR:
            fprintf(out, "{");
            for (i = 0; i < expr->as.array_init.item_count; ++i) {
                if (i != 0) fprintf(out, ", ");
                emit_expr_c(out, expr->as.array_init.items[i]);
            }
            fprintf(out, "}");
            break;
        case DI_AST_RANGE_EXPR:
            emit_expr_c(out, expr->as.range.start);
            fprintf(out, "/*..*/");
            emit_expr_c(out, expr->as.range.end);
            break;
        default:
            fprintf(out, "0");
            break;
    }
}

static void emit_indent(FILE *out, int indent) {
    int i;
    for (i = 0; i < indent; ++i) {
        fprintf(out, "    ");
    }
}

static void emit_stmt_c(FILE *out, const DiIrProgram *program, const DiAstStmt *stmt, int indent);

static void emit_stmt_list_c(FILE *out, const DiIrProgram *program, DiAstStmt **items, size_t count, int indent) {
    size_t i;
    for (i = 0; i < count; ++i) {
        emit_stmt_c(out, program, items[i], indent);
    }
}

static void emit_flux_stmt_c(FILE *out, const DiIrProgram *program, const DiAstStmt *stmt, int indent) {
    if (stmt->as.flux_stmt.iterable->kind == DI_AST_RANGE_EXPR) {
        emit_indent(out, indent);
        fprintf(out, "for (int %s = ", stmt->as.flux_stmt.name);
        emit_expr_c(out, stmt->as.flux_stmt.iterable->as.range.start);
        fprintf(out, "; %s < ", stmt->as.flux_stmt.name);
        emit_expr_c(out, stmt->as.flux_stmt.iterable->as.range.end);
        fprintf(out, "; %s = %s + 1) {\n", stmt->as.flux_stmt.name, stmt->as.flux_stmt.name);
        emit_stmt_list_c(out, program, stmt->as.flux_stmt.body.items, stmt->as.flux_stmt.body.count, indent + 1);
        emit_indent(out, indent);
        fprintf(out, "}\n");
        return;
    }

    emit_indent(out, indent);
    fprintf(out, "for (int %s__index = 0; %s__index < (int)(sizeof(",
            stmt->as.flux_stmt.name,
            stmt->as.flux_stmt.name);
    emit_expr_c(out, stmt->as.flux_stmt.iterable);
    fprintf(out, ")/sizeof(");
    emit_expr_c(out, stmt->as.flux_stmt.iterable);
    fprintf(out, "[0])); %s__index = %s__index + 1) {\n",
            stmt->as.flux_stmt.name,
            stmt->as.flux_stmt.name);
    emit_indent(out, indent + 1);
    fprintf(out, "int %s = ", stmt->as.flux_stmt.name);
    emit_expr_c(out, stmt->as.flux_stmt.iterable);
    fprintf(out, "[%s__index];\n", stmt->as.flux_stmt.name);
    emit_stmt_list_c(out, program, stmt->as.flux_stmt.body.items, stmt->as.flux_stmt.body.count, indent + 1);
    emit_indent(out, indent);
    fprintf(out, "}\n");
}

static void emit_stmt_c(FILE *out, const DiIrProgram *program, const DiAstStmt *stmt, int indent) {
    if (stmt->kind == DI_AST_VAR_STMT) {
        emit_indent(out, indent);
        if (strcmp(stmt->as.var_stmt.type.name, "int[]") == 0 &&
            stmt->as.var_stmt.value != NULL &&
            stmt->as.var_stmt.value->kind == DI_AST_ARRAY_INIT_EXPR) {
            fprintf(out, "int %s[%zu] = ", stmt->as.var_stmt.name, stmt->as.var_stmt.value->as.array_init.item_count);
            emit_expr_c(out, stmt->as.var_stmt.value);
            fprintf(out, ";\n");
        } else {
            fprintf(out, "%s %s = ", c_type_name(program, stmt->as.var_stmt.type.name), stmt->as.var_stmt.name);
            emit_expr_c(out, stmt->as.var_stmt.value);
            fprintf(out, ";\n");
        }
        return;
    }

    if (stmt->kind == DI_AST_ASSIGN_STMT) {
        emit_indent(out, indent);
        fprintf(out, "%s = ", stmt->as.assign_stmt.name);
        emit_expr_c(out, stmt->as.assign_stmt.value);
        fprintf(out, ";\n");
        return;
    }

    if (stmt->kind == DI_AST_FIELD_ASSIGN_STMT) {
        emit_indent(out, indent);
        emit_expr_c(out, stmt->as.field_assign_stmt.target);
        fprintf(out, " = ");
        emit_expr_c(out, stmt->as.field_assign_stmt.value);
        fprintf(out, ";\n");
        return;
    }

    if (stmt->kind == DI_AST_INDEX_ASSIGN_STMT) {
        emit_indent(out, indent);
        emit_expr_c(out, stmt->as.index_assign_stmt.target);
        fprintf(out, " = ");
        emit_expr_c(out, stmt->as.index_assign_stmt.value);
        fprintf(out, ";\n");
        return;
    }

    if (stmt->kind == DI_AST_RETURN_STMT) {
        emit_indent(out, indent);
        fprintf(out, "return ");
        emit_expr_c(out, stmt->as.return_stmt.value);
        fprintf(out, ";\n");
        return;
    }

    if (stmt->kind == DI_AST_EXPR_STMT) {
        emit_indent(out, indent);
        emit_expr_c(out, stmt->as.expr_stmt.expr);
        fprintf(out, ";\n");
        return;
    }

    if (stmt->kind == DI_AST_IF_STMT) {
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

    if (stmt->kind == DI_AST_WHILE_STMT) {
        emit_indent(out, indent);
        fprintf(out, "while (");
        emit_expr_c(out, stmt->as.while_stmt.condition);
        fprintf(out, ") {\n");
        emit_stmt_list_c(out, program, stmt->as.while_stmt.body.items, stmt->as.while_stmt.body.count, indent + 1);
        if (stmt->as.while_stmt.update != NULL) {
            emit_stmt_c(out, program, stmt->as.while_stmt.update, indent + 1);
        }
        emit_indent(out, indent);
        fprintf(out, "}\n");
        return;
    }

    if (stmt->kind == DI_AST_FLUX_STMT) {
        emit_flux_stmt_c(out, program, stmt, indent);
    }
}

static int stmt_has_loop(const DiAstStmt *stmt) {
    if (stmt->kind == DI_AST_WHILE_STMT || stmt->kind == DI_AST_FLUX_STMT) {
        return 1;
    }
    if (stmt->kind == DI_AST_IF_STMT) {
        size_t i;
        for (i = 0; i < stmt->as.if_stmt.then_block.count; ++i) {
            if (stmt_has_loop(stmt->as.if_stmt.then_block.items[i])) return 1;
        }
        for (i = 0; i < stmt->as.if_stmt.else_block.count; ++i) {
            if (stmt_has_loop(stmt->as.if_stmt.else_block.items[i])) return 1;
        }
    }
    return 0;
}

static int decl_has_array_stmt(const DiIrDecl *decl) {
    size_t i;
    for (i = 0; i < decl->body_count; ++i) {
        const DiAstStmt *stmt = decl->body[i];
        if (stmt->kind == DI_AST_VAR_STMT &&
            stmt->as.var_stmt.value != NULL &&
            stmt->as.var_stmt.value->kind == DI_AST_ARRAY_INIT_EXPR) {
            return 1;
        }
    }
    return 0;
}

int di_codegen_emit_llvm_ir(const DiIrProgram *program, const char *input_path) {
    char output_base[256];
    char output_path[300];
    FILE *out;
    size_t i;

    if (program == NULL) {
        return 1;
    }

    if (system("mkdir -p build") != 0) {
        di_error("failed to create build directory");
        return 1;
    }

    make_output_base(input_path, output_base, sizeof(output_base));
    snprintf(output_path, sizeof(output_path), "%s.ll", output_base);
    out = fopen(output_path, "wb");
    if (out == NULL) {
        di_error("failed to open LLVM IR output: %s", output_path);
        return 1;
    }

    fprintf(out, "; pseudo LLVM IR generated by di\n");
    fprintf(out, "; slot-reuse-experiment: enabled\n");
    for (i = 0; i < program->decl_count; ++i) {
        const DiIrDecl *decl = &program->decls[i];
        if (decl->kind == DI_IR_FUNCTION || decl->kind == DI_IR_EXTERN_FUNCTION) {
            fprintf(out, "define %s @%s(...) {\n", strcmp(decl->return_type, "void") == 0 ? "void" : "i32", decl->symbol_name);
            fprintf(out, "  %%slot0 = alloca i32\n");
            if (decl_has_array_stmt(decl)) {
                fprintf(out, "  %%arr = getelementptr inbounds [4 x i32], [4 x i32]* %%slot0, i32 0, i32 0\n");
                fprintf(out, "  store i32 0, i32* %%arr\n");
            }
            if (decl->body_count != 0) {
                size_t j;
                for (j = 0; j < decl->body_count; ++j) {
                    if (stmt_has_loop(decl->body[j])) {
                        fprintf(out, "  br label %%whilecond0\n");
                        break;
                    }
                }
            }
            fprintf(out, "}\n\n");
        }
    }

    fclose(out);
    di_info("wrote LLVM IR to %s", output_path);
    return 0;
}

int di_codegen_build_native(const DiIrProgram *program, const char *input_path, int run_after_build) {
    char output_base[256];
    char c_path[300];
    char exe_path[300];
    char command[1024];
    FILE *out;
    size_t i;
    Ctx ctx;

    if (program == NULL) {
        return 1;
    }

    ctx.program = program;
    make_output_base(input_path, output_base, sizeof(output_base));
    snprintf(c_path, sizeof(c_path), "%s.c", output_base);
    snprintf(exe_path, sizeof(exe_path), "%s", output_base);

    out = fopen(c_path, "wb");
    if (out == NULL) {
        di_error("failed to open native output source: %s", c_path);
        return 1;
    }

    fprintf(out, "#include <stdio.h>\n\n");
    fprintf(out, "extern void di_runtime_print_int(int x);\n");
    fprintf(out, "extern void di_runtime_print_str(const char *x);\n\n");

    for (i = 0; i < program->decl_count; ++i) {
        const DiIrDecl *decl = &program->decls[i];
        size_t j;
        if (decl->kind != DI_IR_STRUCT_DECL) continue;
        fprintf(out, "struct %s {\n", decl->name);
        for (j = 0; j < decl->field_count; ++j) {
            fprintf(out, "    %s %s;\n", c_type_name(program, decl->fields[j].type_name), decl->fields[j].name);
        }
        fprintf(out, "};\n\n");
    }

    for (i = 0; i < program->decl_count; ++i) {
        const DiIrDecl *decl = &program->decls[i];
        size_t j;
        if (decl->kind == DI_IR_STRUCT_DECL) continue;
        fprintf(out, "%s %s(",
                c_type_name(program, decl->return_type),
                decl->symbol_name);
        for (j = 0; j < decl->param_count; ++j) {
            if (j != 0) fprintf(out, ", ");
            fprintf(out, "%s %s",
                    c_type_name(program, decl->params[j].type_name),
                    decl->params[j].name);
        }
        if (decl->kind == DI_IR_EXTERN_FUNCTION) {
            fprintf(out, ");\n");
        } else {
            fprintf(out, ") {\n");
            emit_stmt_list_c(out, ctx.program, decl->body, decl->body_count, 1);
            if (strcmp(decl->return_type, "void") == 0) {
                fprintf(out, "    return;\n");
            }
            fprintf(out, "}\n\n");
        }
    }

    fclose(out);

    snprintf(command, sizeof(command), "cc \"%s\" \"%s\" -o \"%s\"", c_path, DI_RUNTIME_SOURCE, exe_path);
    if (system(command) != 0) {
        di_error("failed to build native executable with cc");
        return 1;
    }

    di_info("built native executable at %s", exe_path);
    if (run_after_build) {
        snprintf(command, sizeof(command), "\"%s\"", exe_path);
        if (system(command) != 0) {
            di_error("failed to run executable: %s", exe_path);
            return 1;
        }
    }
    return 0;
}

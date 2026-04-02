#include "parser.h"

#include "diag.h"
#include "lexer.h"
#include "token.h"

#include <stdlib.h>
#include <string.h>

typedef struct {
    DiLexer lexer;
    DiToken current;
    int had_error;
} DiParser;

static void parser_advance(DiParser *parser) {
    parser->current = di_lexer_next(&parser->lexer);
    if (parser->current.kind == DI_TOKEN_INVALID) {
        di_error("invalid token at %d:%d", parser->current.line, parser->current.column);
        parser->had_error = 1;
    }
}

static int parser_match(DiParser *parser, DiTokenKind kind) {
    if (parser->current.kind != kind) {
        return 0;
    }
    parser_advance(parser);
    return 1;
}

static void parser_expect(DiParser *parser, DiTokenKind kind, const char *what) {
    if (!parser_match(parser, kind)) {
        di_error("expected %s at %d:%d, got %s",
                   what,
                   parser->current.line,
                   parser->current.column,
                   di_token_kind_name(parser->current.kind));
        parser->had_error = 1;
    }
}

static void parser_maybe_semi(DiParser *parser) {
    parser_match(parser, DI_TOKEN_SEMI);
}

static int parser_looks_like_struct_init(DiParser *parser) {
    DiLexer copy;
    DiToken first;
    DiToken second;

    if (parser->current.kind != DI_TOKEN_LBRACE) {
        return 0;
    }

    copy = parser->lexer;
    first = di_lexer_next(&copy);
    if (first.kind == DI_TOKEN_RBRACE) {
        return 1;
    }
    if (first.kind != DI_TOKEN_IDENT) {
        return 0;
    }

    second = di_lexer_next(&copy);
    return second.kind == DI_TOKEN_COLON;
}

static char *parser_take_text(DiParser *parser) {
    return di_ast_strdup_range(parser->current.lexeme, parser->current.length);
}

static char *copy_text(const char *text) {
    return di_ast_strdup_range(text, (int)strlen(text));
}

static int parser_looks_like_generic_call_args(DiParser *parser) {
    DiLexer copy;
    DiToken token;

    if (parser->current.kind != DI_TOKEN_LBRACKET) {
        return 0;
    }

    copy = parser->lexer;
    token = di_lexer_next(&copy);
    if (token.kind != DI_TOKEN_IDENT) {
        return 0;
    }

    for (;;) {
        token = di_lexer_next(&copy);
        if (token.kind == DI_TOKEN_COMMA) {
            token = di_lexer_next(&copy);
            if (token.kind != DI_TOKEN_IDENT) {
                return 0;
            }
            continue;
        }
        if (token.kind != DI_TOKEN_RBRACKET) {
            return 0;
        }
        break;
    }

    token = di_lexer_next(&copy);
    return token.kind == DI_TOKEN_LPAREN;
}

static void parse_generic_param_list(DiParser *parser, DiAstDecl *decl) {
    if (!parser_match(parser, DI_TOKEN_LBRACKET)) {
        return;
    }
    while (parser->current.kind != DI_TOKEN_RBRACKET && parser->current.kind != DI_TOKEN_EOF) {
        char *name;
        if (parser->current.kind != DI_TOKEN_IDENT) {
            di_error("expected generic parameter name");
            parser->had_error = 1;
            return;
        }
        name = parser_take_text(parser);
        parser_advance(parser);
        if (!di_ast_decl_add_generic_param(decl, name)) {
            free(name);
            parser->had_error = 1;
            return;
        }
        if (!parser_match(parser, DI_TOKEN_COMMA)) {
            break;
        }
    }
    parser_expect(parser, DI_TOKEN_RBRACKET, "']'");
}

static int parse_package_decl(DiParser *parser, DiAstProgram *program) {
    if (!parser_match(parser, DI_TOKEN_PACKAGE)) {
        return 1;
    }
    if (parser->current.kind != DI_TOKEN_IDENT) {
        di_error("expected package name after 'package'");
        parser->had_error = 1;
        return 0;
    }
    program->package_name = parser_take_text(parser);
    parser_advance(parser);
    parser_maybe_semi(parser);
    return 1;
}

static int parse_import_decl(DiParser *parser, DiAstProgram *program) {
    char *import_path;
    if (!parser_match(parser, DI_TOKEN_IMPORT)) {
        return 0;
    }
    if (parser->current.kind != DI_TOKEN_STRING_LIT) {
        di_error("expected string literal after 'import'");
        parser->had_error = 1;
        return 1;
    }
    import_path = di_ast_strdup_range(parser->current.lexeme + 1, parser->current.length - 2);
    if (import_path == NULL || !di_ast_program_add_import(program, import_path)) {
        parser->had_error = 1;
    }
    free(import_path);
    parser_advance(parser);
    parser_maybe_semi(parser);
    return 1;
}

static DiAstType parse_type(DiParser *parser) {
    DiAstType type;
    char buffer[128];
    size_t len;

    type.name = NULL;
    if (parser->current.kind != DI_TOKEN_IDENT) {
        di_error("expected type name at %d:%d", parser->current.line, parser->current.column);
        parser->had_error = 1;
        type.name = copy_text("error");
        return type;
    }

    type.name = parser_take_text(parser);
    parser_advance(parser);
    if (parser_match(parser, DI_TOKEN_LBRACKET)) {
        parser_expect(parser, DI_TOKEN_RBRACKET, "']'");
        len = strlen(type.name);
        if (len + 3 < sizeof(buffer)) {
            memcpy(buffer, type.name, len);
            buffer[len] = '[';
            buffer[len + 1] = ']';
            buffer[len + 2] = '\0';
            free((char *)type.name);
            type.name = copy_text(buffer);
        }
    }
    return type;
}

static DiBinaryOp token_to_binary_op(DiTokenKind kind) {
    switch (kind) {
        case DI_TOKEN_PLUS: return DI_BIN_ADD;
        case DI_TOKEN_MINUS: return DI_BIN_SUB;
        case DI_TOKEN_STAR: return DI_BIN_MUL;
        case DI_TOKEN_SLASH: return DI_BIN_DIV;
        case DI_TOKEN_EQEQ: return DI_BIN_EQ;
        case DI_TOKEN_BANGEQ: return DI_BIN_NE;
        case DI_TOKEN_LT: return DI_BIN_LT;
        case DI_TOKEN_GT: return DI_BIN_GT;
        case DI_TOKEN_LE: return DI_BIN_LE;
        case DI_TOKEN_GE: return DI_BIN_GE;
        case DI_TOKEN_AMP: return DI_BIN_AND;
        case DI_TOKEN_PIPE: return DI_BIN_OR;
        default: return DI_BIN_ADD;
    }
}

static DiAstExpr *make_binary_expr(DiBinaryOp op, DiAstExpr *left, DiAstExpr *right) {
    DiAstExpr *expr = di_ast_expr_new(DI_AST_BINARY_EXPR);
    if (expr == NULL) {
        return NULL;
    }
    expr->as.binary.op = op;
    expr->as.binary.left = left;
    expr->as.binary.right = right;
    return expr;
}

static DiAstExpr *parse_expr(DiParser *parser);
static DiAstStmt *parse_stmt(DiParser *parser);
static DiAstStmt *parse_simple_stmt(DiParser *parser, int require_semi);

static DiAstExpr *parse_call_expr(DiParser *parser, DiAstExpr *callee) {
    DiAstExpr *call_expr = di_ast_expr_new(DI_AST_CALL_EXPR);
    if (call_expr == NULL) {
        return callee;
    }
    call_expr->as.call.callee = callee;
    while (parser->current.kind != DI_TOKEN_RPAREN && parser->current.kind != DI_TOKEN_EOF) {
        DiAstExpr *arg = parse_expr(parser);
        if (arg == NULL || !di_ast_call_add_arg(call_expr, arg)) {
            parser->had_error = 1;
            return call_expr;
        }
        if (!parser_match(parser, DI_TOKEN_COMMA)) {
            break;
        }
    }
    parser_expect(parser, DI_TOKEN_RPAREN, "')'");
    return call_expr;
}

static DiAstExpr *parse_postfix(DiParser *parser, DiAstExpr *expr) {
    for (;;) {
        if (parser_match(parser, DI_TOKEN_DOT)) {
            DiAstExpr *field_expr = di_ast_expr_new(DI_AST_FIELD_EXPR);
            if (field_expr == NULL) {
                return expr;
            }
            if (parser->current.kind != DI_TOKEN_IDENT) {
                di_error("expected field name after '.'");
                parser->had_error = 1;
                return field_expr;
            }
            field_expr->as.field.base = expr;
            field_expr->as.field.field_name = parser_take_text(parser);
            parser_advance(parser);
            expr = field_expr;
            continue;
        }
        if (parser->current.kind == DI_TOKEN_LBRACKET && parser_looks_like_generic_call_args(parser)) {
            DiAstExpr *call_expr;
            parser_advance(parser);
            call_expr = di_ast_expr_new(DI_AST_CALL_EXPR);
            if (call_expr == NULL) {
                return expr;
            }
            call_expr->as.call.callee = expr;
            while (parser->current.kind != DI_TOKEN_RBRACKET && parser->current.kind != DI_TOKEN_EOF) {
                DiAstType type = parse_type(parser);
                if (!di_ast_call_add_generic_arg(call_expr, type)) {
                    parser->had_error = 1;
                    return call_expr;
                }
                if (!parser_match(parser, DI_TOKEN_COMMA)) {
                    break;
                }
            }
            parser_expect(parser, DI_TOKEN_RBRACKET, "']'");
            parser_expect(parser, DI_TOKEN_LPAREN, "'('");
            expr = parse_call_expr(parser, call_expr->as.call.callee);
            expr->as.call.generic_args = call_expr->as.call.generic_args;
            expr->as.call.generic_arg_count = call_expr->as.call.generic_arg_count;
            free(call_expr);
            continue;
        }
        if (parser_match(parser, DI_TOKEN_LBRACKET)) {
            DiAstExpr *index_expr = di_ast_expr_new(DI_AST_INDEX_EXPR);
            if (index_expr == NULL) {
                return expr;
            }
            index_expr->as.index.base = expr;
            index_expr->as.index.index = parse_expr(parser);
            parser_expect(parser, DI_TOKEN_RBRACKET, "']'");
            expr = index_expr;
            continue;
        }
        if (parser_match(parser, DI_TOKEN_LPAREN)) {
            expr = parse_call_expr(parser, expr);
            continue;
        }
        break;
    }
    return expr;
}

static DiAstExpr *parse_primary(DiParser *parser) {
    DiAstExpr *expr;
    char *name;

    if (parser->current.kind == DI_TOKEN_INT_LIT) {
        char *literal_text;
        expr = di_ast_expr_new(DI_AST_INT_EXPR);
        if (expr == NULL) return NULL;
        literal_text = parser_take_text(parser);
        expr->as.int_value = strtol(literal_text, NULL, 10);
        free(literal_text);
        parser_advance(parser);
        return expr;
    }

    if (parser->current.kind == DI_TOKEN_TRUE || parser->current.kind == DI_TOKEN_FALSE) {
        expr = di_ast_expr_new(DI_AST_BOOL_EXPR);
        if (expr == NULL) return NULL;
        expr->as.bool_value = parser->current.kind == DI_TOKEN_TRUE;
        parser_advance(parser);
        return expr;
    }

    if (parser->current.kind == DI_TOKEN_STRING_LIT) {
        expr = di_ast_expr_new(DI_AST_STRING_EXPR);
        if (expr == NULL) return NULL;
        expr->as.string_value = di_ast_strdup_range(parser->current.lexeme + 1, parser->current.length - 2);
        parser_advance(parser);
        return expr;
    }

    if (parser_match(parser, DI_TOKEN_BANG)) {
        expr = di_ast_expr_new(DI_AST_UNARY_EXPR);
        if (expr == NULL) return NULL;
        expr->as.unary.op = DI_UNARY_NOT;
        expr->as.unary.operand = parse_primary(parser);
        return expr;
    }

    if (parser_match(parser, DI_TOKEN_LBRACKET)) {
        expr = di_ast_expr_new(DI_AST_ARRAY_INIT_EXPR);
        if (expr == NULL) return NULL;
        while (parser->current.kind != DI_TOKEN_RBRACKET && parser->current.kind != DI_TOKEN_EOF) {
            DiAstExpr *item = parse_expr(parser);
            if (item == NULL || !di_ast_array_add_item(expr, item)) {
                parser->had_error = 1;
                return expr;
            }
            if (!parser_match(parser, DI_TOKEN_COMMA)) {
                break;
            }
        }
        parser_expect(parser, DI_TOKEN_RBRACKET, "']'");
        return parse_postfix(parser, expr);
    }

    if (parser->current.kind == DI_TOKEN_IDENT) {
        name = parser_take_text(parser);
        parser_advance(parser);
        if (parser_looks_like_struct_init(parser)) {
            expr = di_ast_expr_new(DI_AST_STRUCT_INIT_EXPR);
            if (expr == NULL) return NULL;
            expr->as.struct_init.type_name = name;
            parser_advance(parser);
            while (parser->current.kind != DI_TOKEN_RBRACE && parser->current.kind != DI_TOKEN_EOF) {
                DiAstInitField field;
                if (parser->current.kind != DI_TOKEN_IDENT) {
                    di_error("expected struct field name");
                    parser->had_error = 1;
                    return expr;
                }
                field.name = parser_take_text(parser);
                parser_advance(parser);
                parser_expect(parser, DI_TOKEN_COLON, "':'");
                field.value = parse_expr(parser);
                if (!di_ast_struct_init_add_field(expr, field)) {
                    parser->had_error = 1;
                    return expr;
                }
                if (!parser_match(parser, DI_TOKEN_COMMA)) {
                    break;
                }
            }
            parser_expect(parser, DI_TOKEN_RBRACE, "'}'");
            return parse_postfix(parser, expr);
        }

        expr = di_ast_expr_new(DI_AST_IDENT_EXPR);
        if (expr == NULL) return NULL;
        expr->as.ident_name = name;
        return parse_postfix(parser, expr);
    }

    if (parser_match(parser, DI_TOKEN_LPAREN)) {
        expr = parse_expr(parser);
        parser_expect(parser, DI_TOKEN_RPAREN, "')'");
        return parse_postfix(parser, expr);
    }

    di_error("unexpected token in expression at %d:%d: %s",
               parser->current.line,
               parser->current.column,
               di_token_kind_name(parser->current.kind));
    parser->had_error = 1;
    return NULL;
}

static DiAstExpr *parse_factor(DiParser *parser) {
    DiAstExpr *expr = parse_primary(parser);
    while (parser->current.kind == DI_TOKEN_STAR || parser->current.kind == DI_TOKEN_SLASH) {
        DiTokenKind op = parser->current.kind;
        DiAstExpr *right;
        parser_advance(parser);
        right = parse_primary(parser);
        expr = make_binary_expr(token_to_binary_op(op), expr, right);
    }
    return expr;
}

static DiAstExpr *parse_term(DiParser *parser) {
    DiAstExpr *expr = parse_factor(parser);
    while (parser->current.kind == DI_TOKEN_PLUS || parser->current.kind == DI_TOKEN_MINUS) {
        DiTokenKind op = parser->current.kind;
        DiAstExpr *right;
        parser_advance(parser);
        right = parse_factor(parser);
        expr = make_binary_expr(token_to_binary_op(op), expr, right);
    }
    return expr;
}

static DiAstExpr *parse_comparison(DiParser *parser) {
    DiAstExpr *expr = parse_term(parser);
    while (parser->current.kind == DI_TOKEN_LT ||
           parser->current.kind == DI_TOKEN_GT ||
           parser->current.kind == DI_TOKEN_LE ||
           parser->current.kind == DI_TOKEN_GE) {
        DiTokenKind op = parser->current.kind;
        DiAstExpr *right;
        parser_advance(parser);
        right = parse_term(parser);
        expr = make_binary_expr(token_to_binary_op(op), expr, right);
    }
    return expr;
}

static DiAstExpr *parse_equality(DiParser *parser) {
    DiAstExpr *expr = parse_comparison(parser);
    while (parser->current.kind == DI_TOKEN_EQEQ || parser->current.kind == DI_TOKEN_BANGEQ) {
        DiTokenKind op = parser->current.kind;
        DiAstExpr *right;
        parser_advance(parser);
        right = parse_comparison(parser);
        expr = make_binary_expr(token_to_binary_op(op), expr, right);
    }
    return expr;
}

static DiAstExpr *parse_and(DiParser *parser) {
    DiAstExpr *expr = parse_equality(parser);
    while (parser->current.kind == DI_TOKEN_AMP) {
        DiTokenKind op = parser->current.kind;
        DiAstExpr *right;
        parser_advance(parser);
        right = parse_equality(parser);
        expr = make_binary_expr(token_to_binary_op(op), expr, right);
    }
    return expr;
}

static DiAstExpr *parse_or(DiParser *parser) {
    DiAstExpr *expr = parse_and(parser);
    while (parser->current.kind == DI_TOKEN_PIPE) {
        DiTokenKind op = parser->current.kind;
        DiAstExpr *right;
        parser_advance(parser);
        right = parse_and(parser);
        expr = make_binary_expr(token_to_binary_op(op), expr, right);
    }
    return expr;
}

static DiAstExpr *parse_range(DiParser *parser) {
    DiAstExpr *expr = parse_or(parser);
    if (parser_match(parser, DI_TOKEN_DOTDOT)) {
        DiAstExpr *range_expr = di_ast_expr_new(DI_AST_RANGE_EXPR);
        if (range_expr == NULL) {
            return expr;
        }
        range_expr->as.range.start = expr;
        range_expr->as.range.end = parse_or(parser);
        return range_expr;
    }
    return expr;
}

static DiAstExpr *parse_expr(DiParser *parser) {
    return parse_range(parser);
}

static int parse_block(DiParser *parser, DiAstBlock *block) {
    parser_expect(parser, DI_TOKEN_LBRACE, "'{'");
    while (parser->current.kind != DI_TOKEN_RBRACE && parser->current.kind != DI_TOKEN_EOF) {
        DiAstStmt *stmt = parse_stmt(parser);
        if (stmt == NULL || !di_ast_block_add_stmt(block, stmt)) {
            parser->had_error = 1;
            return 0;
        }
    }
    parser_expect(parser, DI_TOKEN_RBRACE, "'}'");
    return 1;
}

static DiAstStmt *make_assign_from_target(DiParser *parser, DiAstExpr *target, DiAstExpr *value) {
    DiAstStmt *stmt;

    if (target != NULL && target->kind == DI_AST_IDENT_EXPR) {
        stmt = di_ast_stmt_new(DI_AST_ASSIGN_STMT);
        if (stmt == NULL) return NULL;
        stmt->as.assign_stmt.name = target->as.ident_name;
        target->as.ident_name = NULL;
        free(target);
        stmt->as.assign_stmt.value = value;
        return stmt;
    }
    if (target != NULL && target->kind == DI_AST_FIELD_EXPR) {
        stmt = di_ast_stmt_new(DI_AST_FIELD_ASSIGN_STMT);
        if (stmt == NULL) return NULL;
        stmt->as.field_assign_stmt.target = target;
        stmt->as.field_assign_stmt.value = value;
        return stmt;
    }
    if (target != NULL && target->kind == DI_AST_INDEX_EXPR) {
        stmt = di_ast_stmt_new(DI_AST_INDEX_ASSIGN_STMT);
        if (stmt == NULL) return NULL;
        stmt->as.index_assign_stmt.target = target;
        stmt->as.index_assign_stmt.value = value;
        return stmt;
    }
    di_error("invalid assignment target");
    parser->had_error = 1;
    return NULL;
}

static DiAstStmt *parse_var_stmt(DiParser *parser, int require_semi) {
    DiAstStmt *stmt = di_ast_stmt_new(DI_AST_VAR_STMT);
    if (stmt == NULL) return NULL;
    if (!(parser_match(parser, DI_TOKEN_VAR) || parser_match(parser, DI_TOKEN_LET))) {
        di_error("expected 'var' or 'let' at %d:%d", parser->current.line, parser->current.column);
        parser->had_error = 1;
        return stmt;
    }
    if (parser->current.kind != DI_TOKEN_IDENT) {
        di_error("expected identifier after var");
        parser->had_error = 1;
        return stmt;
    }
    stmt->as.var_stmt.name = parser_take_text(parser);
    parser_advance(parser);
    if (parser_match(parser, DI_TOKEN_DOUBLECOLON) || parser_match(parser, DI_TOKEN_COLON)) {
        stmt->as.var_stmt.type = parse_type(parser);
        stmt->as.var_stmt.has_explicit_type = 1;
    }
    parser_expect(parser, DI_TOKEN_EQUAL, "'='");
    stmt->as.var_stmt.value = parse_expr(parser);
    if (require_semi) {
        parser_maybe_semi(parser);
    }
    return stmt;
}

static DiAstStmt *parse_simple_stmt(DiParser *parser, int require_semi) {
    DiAstStmt *stmt;
    DiAstExpr *target;

    if (parser->current.kind == DI_TOKEN_VAR || parser->current.kind == DI_TOKEN_LET) {
        return parse_var_stmt(parser, require_semi);
    }

    if (parser_match(parser, DI_TOKEN_RETURN)) {
        stmt = di_ast_stmt_new(DI_AST_RETURN_STMT);
        if (stmt == NULL) return NULL;
        stmt->as.return_stmt.value = parse_expr(parser);
        if (require_semi) {
            parser_maybe_semi(parser);
        }
        return stmt;
    }

    target = parse_expr(parser);
    if (parser_match(parser, DI_TOKEN_EQUAL)) {
        stmt = make_assign_from_target(parser, target, parse_expr(parser));
        if (require_semi) {
            parser_maybe_semi(parser);
        }
        return stmt;
    }

    stmt = di_ast_stmt_new(DI_AST_EXPR_STMT);
    if (stmt == NULL) return NULL;
    stmt->as.expr_stmt.expr = target;
    if (require_semi) {
        parser_maybe_semi(parser);
    }
    return stmt;
}

static DiAstStmt *parse_stmt(DiParser *parser) {
    DiAstStmt *stmt;

    if (parser_match(parser, DI_TOKEN_IF)) {
        stmt = di_ast_stmt_new(DI_AST_IF_STMT);
        if (stmt == NULL) return NULL;
        stmt->as.if_stmt.condition = parse_expr(parser);
        parse_block(parser, &stmt->as.if_stmt.then_block);
        if (parser_match(parser, DI_TOKEN_ELSE)) {
            parse_block(parser, &stmt->as.if_stmt.else_block);
        }
        return stmt;
    }

    if (parser_match(parser, DI_TOKEN_WHILE)) {
        stmt = di_ast_stmt_new(DI_AST_WHILE_STMT);
        if (stmt == NULL) return NULL;
        stmt->as.while_stmt.condition = parse_expr(parser);
        if (parser_match(parser, DI_TOKEN_FATARROW)) {
            stmt->as.while_stmt.update = parse_simple_stmt(parser, 0);
        }
        parse_block(parser, &stmt->as.while_stmt.body);
        return stmt;
    }

    if (parser_match(parser, DI_TOKEN_FLUX)) {
        stmt = di_ast_stmt_new(DI_AST_FLUX_STMT);
        if (stmt == NULL) return NULL;
        if (parser->current.kind != DI_TOKEN_IDENT) {
            di_error("expected iterator name after flux");
            parser->had_error = 1;
            return stmt;
        }
        stmt->as.flux_stmt.name = parser_take_text(parser);
        parser_advance(parser);
        parser_expect(parser, DI_TOKEN_IN, "'in'");
        stmt->as.flux_stmt.iterable = parse_expr(parser);
        parse_block(parser, &stmt->as.flux_stmt.body);
        return stmt;
    }

    return parse_simple_stmt(parser, 1);
}

static void parse_param_list(DiParser *parser, DiAstDecl *decl) {
    while (parser->current.kind != DI_TOKEN_RPAREN && parser->current.kind != DI_TOKEN_EOF) {
        DiAstParam param;
        if (parser->current.kind != DI_TOKEN_IDENT) {
            di_error("expected parameter name at %d:%d", parser->current.line, parser->current.column);
            parser->had_error = 1;
            return;
        }
        param.name = parser_take_text(parser);
        parser_advance(parser);
        parser_expect(parser, DI_TOKEN_COLON, "':'");
        param.type = parse_type(parser);
        if (!di_ast_decl_add_param(decl, param)) {
            parser->had_error = 1;
            return;
        }
        if (!parser_match(parser, DI_TOKEN_COMMA)) {
            break;
        }
    }
}

static DiAstDecl *parse_function_decl(DiParser *parser, int is_extern, const char *owner_type) {
    DiAstDecl *decl;
    char *name;

    parser_expect(parser, DI_TOKEN_FUNC, "'func'");
    if (parser->current.kind != DI_TOKEN_IDENT) {
        di_error("expected function name at %d:%d", parser->current.line, parser->current.column);
        parser->had_error = 1;
        return NULL;
    }

    name = parser_take_text(parser);
    parser_advance(parser);
    decl = di_ast_decl_new(is_extern ? DI_AST_EXTERN_FUNCTION : DI_AST_FUNCTION, name);
    if (decl == NULL) {
        return NULL;
    }
    if (owner_type != NULL) {
        decl->owner_type = copy_text(owner_type);
    }

    parse_generic_param_list(parser, decl);

    parser_expect(parser, DI_TOKEN_LPAREN, "'('");
    if (owner_type != NULL) {
        DiAstParam self_param;
        self_param.name = copy_text("self");
        self_param.type.name = copy_text(owner_type);
        if (!di_ast_decl_add_param(decl, self_param)) {
            parser->had_error = 1;
            return decl;
        }
    }
    parse_param_list(parser, decl);
    parser_expect(parser, DI_TOKEN_RPAREN, "')'");
    parser_expect(parser, DI_TOKEN_COLON, "':'");
    decl->return_type = parse_type(parser);

    if (is_extern) {
        parser_maybe_semi(parser);
        return decl;
    }

    parser_expect(parser, DI_TOKEN_LBRACE, "'{'");
    while (parser->current.kind != DI_TOKEN_RBRACE && parser->current.kind != DI_TOKEN_EOF) {
        DiAstStmt *stmt = parse_stmt(parser);
        if (stmt == NULL || !di_ast_decl_add_stmt(decl, stmt)) {
            parser->had_error = 1;
            return decl;
        }
    }
    parser_expect(parser, DI_TOKEN_RBRACE, "'}'");
    return decl;
}

static int parse_trait_decl(DiParser *parser, DiAstProgram *program) {
    DiAstDecl *trait_decl;
    char *name;

    parser_expect(parser, DI_TOKEN_TRAIT, "'trait'");
    if (parser->current.kind != DI_TOKEN_IDENT) {
        di_error("expected trait name");
        parser->had_error = 1;
        return 0;
    }

    name = parser_take_text(parser);
    parser_advance(parser);
    trait_decl = di_ast_decl_new(DI_AST_TRAIT_DECL, name);
    if (trait_decl == NULL) {
        free(name);
        return 0;
    }

    parser_expect(parser, DI_TOKEN_LBRACE, "'{'");
    while (parser->current.kind != DI_TOKEN_RBRACE && parser->current.kind != DI_TOKEN_EOF) {
        DiAstDecl *method = parse_function_decl(parser, 1, NULL);
        if (method == NULL || !di_ast_decl_add_trait_method(trait_decl, method)) {
            parser->had_error = 1;
            return 0;
        }
        parser_maybe_semi(parser);
    }
    parser_expect(parser, DI_TOKEN_RBRACE, "'}'");
    return di_ast_program_add_decl(program, trait_decl);
}

static int parse_impl_decl(DiParser *parser, DiAstProgram *program) {
    DiAstDecl *impl_decl;
    char *trait_name;
    char *type_name;

    parser_expect(parser, DI_TOKEN_IMPL, "'impl'");
    if (parser->current.kind != DI_TOKEN_IDENT) {
        di_error("expected trait name after impl");
        parser->had_error = 1;
        return 0;
    }
    trait_name = parser_take_text(parser);
    parser_advance(parser);
    parser_expect(parser, DI_TOKEN_FOR, "'for'");
    if (parser->current.kind != DI_TOKEN_IDENT) {
        di_error("expected type name after 'for'");
        free(trait_name);
        parser->had_error = 1;
        return 0;
    }
    type_name = parser_take_text(parser);
    parser_advance(parser);
    parser_maybe_semi(parser);

    impl_decl = di_ast_decl_new(DI_AST_IMPL_DECL, trait_name);
    if (impl_decl == NULL) {
        free(trait_name);
        free(type_name);
        return 0;
    }
    impl_decl->owner_type = type_name;
    return di_ast_program_add_decl(program, impl_decl);
}

static int parse_class_decl(DiParser *parser, DiAstProgram *program, int is_struct_style) {
    DiAstDecl *struct_decl;
    char *class_name;

    if (is_struct_style) {
        parser_expect(parser, DI_TOKEN_STRUCT, "'struct'");
    } else {
        parser_expect(parser, DI_TOKEN_CLASS, "'class'");
    }
    if (parser->current.kind != DI_TOKEN_IDENT) {
        di_error("expected class name");
        parser->had_error = 1;
        return 0;
    }

    class_name = parser_take_text(parser);
    parser_advance(parser);
    struct_decl = di_ast_decl_new(DI_AST_STRUCT_DECL, copy_text(class_name));
    if (struct_decl == NULL) {
        free(class_name);
        return 0;
    }

    parser_expect(parser, DI_TOKEN_LBRACE, "'{'");
    while (parser->current.kind != DI_TOKEN_RBRACE && parser->current.kind != DI_TOKEN_EOF) {
        if (parser->current.kind == DI_TOKEN_VAR || parser->current.kind == DI_TOKEN_IDENT) {
            DiAstField field;
            if (parser->current.kind == DI_TOKEN_VAR) {
                parser_advance(parser);
            }
            if (parser->current.kind != DI_TOKEN_IDENT) {
                di_error("expected field name in class");
                parser->had_error = 1;
                free(class_name);
                return 0;
            }
            field.name = parser_take_text(parser);
            parser_advance(parser);
            if (!(parser_match(parser, DI_TOKEN_DOUBLECOLON) || parser_match(parser, DI_TOKEN_COLON))) {
                di_error("expected '::' or ':' after field name");
                parser->had_error = 1;
                free(class_name);
                return 0;
            }
            field.type = parse_type(parser);
            parser_maybe_semi(parser);
            if (!di_ast_decl_add_field(struct_decl, field)) {
                parser->had_error = 1;
                free(class_name);
                return 0;
            }
            continue;
        }

        if (parser->current.kind == DI_TOKEN_FUNC) {
            DiAstDecl *method = parse_function_decl(parser, 0, class_name);
            if (method == NULL || !di_ast_program_add_decl(program, method)) {
                parser->had_error = 1;
                free(class_name);
                return 0;
            }
            continue;
        }

        di_error("expected field or method in class %s", class_name);
        parser->had_error = 1;
        free(class_name);
        return 0;
    }

    parser_expect(parser, DI_TOKEN_RBRACE, "'}'");
    if (!di_ast_program_add_decl(program, struct_decl)) {
        free(class_name);
        return 0;
    }
    free(class_name);
    return 1;
}

DiAstProgram *di_parse_file(const char *source, const char *source_path) {
    DiParser parser;
    DiAstProgram *program = di_ast_program_new();

    if (program == NULL) {
        return NULL;
    }

    di_lexer_init(&parser.lexer, source);
    parser.had_error = 0;
    if (source_path != NULL) {
        program->source_path = copy_text(source_path);
    }
    parser_advance(&parser);

    if (parser.current.kind == DI_TOKEN_EOF) {
        di_error("empty input");
        program->had_error = 1;
        return program;
    }

    if (!parse_package_decl(&parser, program)) {
        program->had_error = 1;
        return program;
    }

    while (parser.current.kind != DI_TOKEN_EOF) {
        DiAstDecl *decl;
        if (parse_import_decl(&parser, program)) {
            if (parser.had_error) {
                break;
            }
            continue;
        }
        int is_extern = parser_match(&parser, DI_TOKEN_EXTERN);

        if (!is_extern && (parser.current.kind == DI_TOKEN_CLASS || parser.current.kind == DI_TOKEN_STRUCT)) {
            if (!parse_class_decl(&parser, program, parser.current.kind == DI_TOKEN_STRUCT)) {
                parser.had_error = 1;
                break;
            }
            continue;
        }

        if (!is_extern && parser.current.kind == DI_TOKEN_TRAIT) {
            if (!parse_trait_decl(&parser, program)) {
                parser.had_error = 1;
                break;
            }
            continue;
        }

        if (!is_extern && parser.current.kind == DI_TOKEN_IMPL) {
            if (!parse_impl_decl(&parser, program)) {
                parser.had_error = 1;
                break;
            }
            continue;
        }

        if (parser.current.kind != DI_TOKEN_FUNC) {
            di_error("expected declaration at %d:%d", parser.current.line, parser.current.column);
            parser.had_error = 1;
            break;
        }

        decl = parse_function_decl(&parser, is_extern, NULL);
        if (decl == NULL || !di_ast_program_add_decl(program, decl)) {
            parser.had_error = 1;
            break;
        }
    }

    program->had_error = parser.had_error;
    return program;
}

DiAstProgram *di_parse_program(const char *source) {
    return di_parse_file(source, NULL);
}

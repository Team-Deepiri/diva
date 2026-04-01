#include "parser.h"

#include "diag.h"
#include "lexer.h"
#include "token.h"

#include <stdlib.h>
#include <string.h>

typedef struct {
    DiriLexer lexer;
    DiriToken current;
    int had_error;
} DiriParser;

static DiriTokenKind parser_peek_kind(DiriParser *parser) {
    DiriLexer copy = parser->lexer;
    DiriToken next = diri_lexer_next(&copy);
    return next.kind;
}

static void parser_advance(DiriParser *parser) {
    parser->current = diri_lexer_next(&parser->lexer);
    if (parser->current.kind == DIRI_TOKEN_INVALID) {
        diri_error("invalid token at %d:%d", parser->current.line, parser->current.column);
        parser->had_error = 1;
    }
}

static int parser_match(DiriParser *parser, DiriTokenKind kind) {
    if (parser->current.kind != kind) {
        return 0;
    }
    parser_advance(parser);
    return 1;
}

static void parser_expect(DiriParser *parser, DiriTokenKind kind, const char *what) {
    if (!parser_match(parser, kind)) {
        diri_error("expected %s at %d:%d, got %s",
                   what,
                   parser->current.line,
                   parser->current.column,
                   diri_token_kind_name(parser->current.kind));
        parser->had_error = 1;
    }
}

static char *parser_take_text(DiriParser *parser) {
    return diri_ast_strdup_range(parser->current.lexeme, parser->current.length);
}

static DiriAstType parse_type(DiriParser *parser) {
    DiriAstType type;
    char buffer[128];
    size_t len;
    type.name = NULL;
    if (parser->current.kind != DIRI_TOKEN_IDENT) {
        diri_error("expected type name at %d:%d", parser->current.line, parser->current.column);
        parser->had_error = 1;
        type.name = diri_ast_strdup_range("error", 5);
        return type;
    }
    type.name = parser_take_text(parser);
    parser_advance(parser);
    if (parser_match(parser, DIRI_TOKEN_LBRACKET)) {
        parser_expect(parser, DIRI_TOKEN_RBRACKET, "']'");
        len = strlen(type.name);
        if (len + 3 < sizeof(buffer)) {
            memcpy(buffer, type.name, len);
            buffer[len] = '[';
            buffer[len + 1] = ']';
            buffer[len + 2] = '\0';
            free((char *)type.name);
            type.name = diri_ast_strdup_range(buffer, (int)(len + 2));
        }
    }
    return type;
}

static DiriAstExpr *parse_expr(DiriParser *parser);
static DiriAstStmt *parse_stmt(DiriParser *parser);
static int parse_block(DiriParser *parser, DiriAstBlock *block);

static DiriBinaryOp token_to_binary_op(DiriTokenKind kind) {
    switch (kind) {
        case DIRI_TOKEN_PLUS: return DIRI_BIN_ADD;
        case DIRI_TOKEN_MINUS: return DIRI_BIN_SUB;
        case DIRI_TOKEN_STAR: return DIRI_BIN_MUL;
        case DIRI_TOKEN_SLASH: return DIRI_BIN_DIV;
        case DIRI_TOKEN_EQEQ: return DIRI_BIN_EQ;
        case DIRI_TOKEN_BANGEQ: return DIRI_BIN_NE;
        case DIRI_TOKEN_LT: return DIRI_BIN_LT;
        case DIRI_TOKEN_GT: return DIRI_BIN_GT;
        case DIRI_TOKEN_LE: return DIRI_BIN_LE;
        case DIRI_TOKEN_GE: return DIRI_BIN_GE;
        default: return DIRI_BIN_ADD;
    }
}

static DiriAstExpr *make_binary_expr(DiriBinaryOp op, DiriAstExpr *left, DiriAstExpr *right) {
    DiriAstExpr *expr;

    expr = diri_ast_expr_new(DIRI_AST_BINARY_EXPR);
    if (expr == NULL) {
        return NULL;
    }
    expr->as.binary.op = op;
    expr->as.binary.left = left;
    expr->as.binary.right = right;
    return expr;
}

static DiriAstExpr *parse_postfix(DiriParser *parser, DiriAstExpr *expr) {
    for (;;) {
        if (parser_match(parser, DIRI_TOKEN_DOT)) {
            DiriAstExpr *field_expr = diri_ast_expr_new(DIRI_AST_FIELD_EXPR);
            if (field_expr == NULL) {
                return expr;
            }
            if (parser->current.kind != DIRI_TOKEN_IDENT) {
                diri_error("expected field name after '.'");
                parser->had_error = 1;
                return field_expr;
            }
            field_expr->as.field.base = expr;
            field_expr->as.field.field_name = parser_take_text(parser);
            parser_advance(parser);
            expr = field_expr;
            continue;
        }
        if (parser_match(parser, DIRI_TOKEN_LBRACKET)) {
            DiriAstExpr *index_expr = diri_ast_expr_new(DIRI_AST_INDEX_EXPR);
            if (index_expr == NULL) {
                return expr;
            }
            index_expr->as.index.base = expr;
            index_expr->as.index.index = parse_expr(parser);
            parser_expect(parser, DIRI_TOKEN_RBRACKET, "']'");
            expr = index_expr;
            continue;
        }
        break;
    }
    return expr;
}

static DiriAstExpr *parse_primary(DiriParser *parser) {
    DiriAstExpr *expr;
    char *name;

    if (parser->current.kind == DIRI_TOKEN_INT_LIT) {
        char *literal_text;
        expr = diri_ast_expr_new(DIRI_AST_INT_EXPR);
        if (expr == NULL) return NULL;
        literal_text = parser_take_text(parser);
        if (literal_text == NULL) {
            return NULL;
        }
        expr->as.int_value = strtol(literal_text, NULL, 10);
        free(literal_text);
        parser_advance(parser);
        return expr;
    }

    if (parser->current.kind == DIRI_TOKEN_TRUE || parser->current.kind == DIRI_TOKEN_FALSE) {
        expr = diri_ast_expr_new(DIRI_AST_BOOL_EXPR);
        if (expr == NULL) return NULL;
        expr->as.bool_value = parser->current.kind == DIRI_TOKEN_TRUE;
        parser_advance(parser);
        return expr;
    }

    if (parser->current.kind == DIRI_TOKEN_STRING_LIT) {
        expr = diri_ast_expr_new(DIRI_AST_STRING_EXPR);
        if (expr == NULL) return NULL;
        expr->as.string_value = diri_ast_strdup_range(parser->current.lexeme + 1, parser->current.length - 2);
        parser_advance(parser);
        return expr;
    }

    if (parser_match(parser, DIRI_TOKEN_LBRACKET)) {
        expr = diri_ast_expr_new(DIRI_AST_ARRAY_INIT_EXPR);
        if (expr == NULL) return NULL;
        while (parser->current.kind != DIRI_TOKEN_RBRACKET && parser->current.kind != DIRI_TOKEN_EOF) {
            DiriAstExpr *item = parse_expr(parser);
            if (item == NULL || !diri_ast_array_add_item(expr, item)) {
                parser->had_error = 1;
                return expr;
            }
            if (!parser_match(parser, DIRI_TOKEN_COMMA)) {
                break;
            }
        }
        parser_expect(parser, DIRI_TOKEN_RBRACKET, "']'");
        return parse_postfix(parser, expr);
    }

    if (parser->current.kind == DIRI_TOKEN_IDENT) {
        name = parser_take_text(parser);
        parser_advance(parser);
        if (parser->current.kind == DIRI_TOKEN_LBRACE &&
            (parser_peek_kind(parser) == DIRI_TOKEN_IDENT ||
             parser_peek_kind(parser) == DIRI_TOKEN_RBRACE)) {
            parser_advance(parser);
            expr = diri_ast_expr_new(DIRI_AST_STRUCT_INIT_EXPR);
            if (expr == NULL) return NULL;
            expr->as.struct_init.type_name = name;
            while (parser->current.kind != DIRI_TOKEN_RBRACE && parser->current.kind != DIRI_TOKEN_EOF) {
                DiriAstInitField field;
                if (parser->current.kind != DIRI_TOKEN_IDENT) {
                    diri_error("expected struct field name");
                    parser->had_error = 1;
                    return expr;
                }
                field.name = parser_take_text(parser);
                parser_advance(parser);
                parser_expect(parser, DIRI_TOKEN_COLON, "':'");
                field.value = parse_expr(parser);
                if (!diri_ast_struct_init_add_field(expr, field)) {
                    parser->had_error = 1;
                    return expr;
                }
                if (!parser_match(parser, DIRI_TOKEN_COMMA)) {
                    break;
                }
            }
            parser_expect(parser, DIRI_TOKEN_RBRACE, "'}'");
            return parse_postfix(parser, expr);
        }
        if (parser_match(parser, DIRI_TOKEN_LPAREN)) {
            expr = diri_ast_expr_new(DIRI_AST_CALL_EXPR);
            if (expr == NULL) return NULL;
            expr->as.call.callee = name;
            while (parser->current.kind != DIRI_TOKEN_RPAREN && parser->current.kind != DIRI_TOKEN_EOF) {
                DiriAstExpr *arg = parse_expr(parser);
                if (arg == NULL || !diri_ast_call_add_arg(expr, arg)) {
                    parser->had_error = 1;
                    return expr;
                }
                if (!parser_match(parser, DIRI_TOKEN_COMMA)) {
                    break;
                }
            }
            parser_expect(parser, DIRI_TOKEN_RPAREN, "')'");
            return parse_postfix(parser, expr);
        }

        expr = diri_ast_expr_new(DIRI_AST_IDENT_EXPR);
        if (expr == NULL) return NULL;
        expr->as.ident_name = name;
        return parse_postfix(parser, expr);
    }

    if (parser_match(parser, DIRI_TOKEN_LPAREN)) {
        expr = parse_expr(parser);
        parser_expect(parser, DIRI_TOKEN_RPAREN, "')'");
        return parse_postfix(parser, expr);
    }

    diri_error("unexpected token in expression at %d:%d: %s",
               parser->current.line,
               parser->current.column,
               diri_token_kind_name(parser->current.kind));
    parser->had_error = 1;
    return NULL;
}

static DiriAstExpr *parse_factor(DiriParser *parser) {
    DiriAstExpr *expr = parse_primary(parser);

    while (parser->current.kind == DIRI_TOKEN_STAR || parser->current.kind == DIRI_TOKEN_SLASH) {
        DiriTokenKind op = parser->current.kind;
        DiriAstExpr *right;
        parser_advance(parser);
        right = parse_primary(parser);
        expr = make_binary_expr(token_to_binary_op(op), expr, right);
    }

    return expr;
}

static DiriAstExpr *parse_term(DiriParser *parser) {
    DiriAstExpr *expr = parse_factor(parser);

    while (parser->current.kind == DIRI_TOKEN_PLUS || parser->current.kind == DIRI_TOKEN_MINUS) {
        DiriTokenKind op = parser->current.kind;
        DiriAstExpr *right;
        parser_advance(parser);
        right = parse_factor(parser);
        expr = make_binary_expr(token_to_binary_op(op), expr, right);
    }

    return expr;
}

static DiriAstExpr *parse_comparison(DiriParser *parser) {
    DiriAstExpr *expr = parse_term(parser);

    while (parser->current.kind == DIRI_TOKEN_LT ||
           parser->current.kind == DIRI_TOKEN_GT ||
           parser->current.kind == DIRI_TOKEN_LE ||
           parser->current.kind == DIRI_TOKEN_GE) {
        DiriTokenKind op = parser->current.kind;
        DiriAstExpr *right;
        parser_advance(parser);
        right = parse_term(parser);
        expr = make_binary_expr(token_to_binary_op(op), expr, right);
    }

    return expr;
}

static DiriAstExpr *parse_equality(DiriParser *parser) {
    DiriAstExpr *expr = parse_comparison(parser);

    while (parser->current.kind == DIRI_TOKEN_EQEQ || parser->current.kind == DIRI_TOKEN_BANGEQ) {
        DiriTokenKind op = parser->current.kind;
        DiriAstExpr *right;
        parser_advance(parser);
        right = parse_comparison(parser);
        expr = make_binary_expr(token_to_binary_op(op), expr, right);
    }

    return expr;
}

static DiriAstExpr *parse_expr(DiriParser *parser) {
    return parse_equality(parser);
}

static int parse_block(DiriParser *parser, DiriAstBlock *block) {
    parser_expect(parser, DIRI_TOKEN_LBRACE, "'{'");
    while (parser->current.kind != DIRI_TOKEN_RBRACE && parser->current.kind != DIRI_TOKEN_EOF) {
        DiriAstStmt *stmt = parse_stmt(parser);
        if (stmt == NULL || !diri_ast_block_add_stmt(block, stmt)) {
            parser->had_error = 1;
            return 0;
        }
    }
    parser_expect(parser, DIRI_TOKEN_RBRACE, "'}'");
    return 1;
}

static DiriAstStmt *parse_stmt(DiriParser *parser) {
    DiriAstStmt *stmt;

    if (parser_match(parser, DIRI_TOKEN_LET)) {
        stmt = diri_ast_stmt_new(DIRI_AST_LET_STMT);
        if (stmt == NULL) return NULL;
        if (parser->current.kind != DIRI_TOKEN_IDENT) {
            diri_error("expected identifier after let");
            parser->had_error = 1;
            return stmt;
        }
        stmt->as.let_stmt.name = parser_take_text(parser);
        parser_advance(parser);
        parser_expect(parser, DIRI_TOKEN_COLON, "':'");
        stmt->as.let_stmt.type = parse_type(parser);
        parser_expect(parser, DIRI_TOKEN_EQUAL, "'='");
        stmt->as.let_stmt.value = parse_expr(parser);
        parser_expect(parser, DIRI_TOKEN_SEMI, "';'");
        return stmt;
    }

    if (parser_match(parser, DIRI_TOKEN_RETURN)) {
        stmt = diri_ast_stmt_new(DIRI_AST_RETURN_STMT);
        if (stmt == NULL) return NULL;
        stmt->as.return_stmt.value = parse_expr(parser);
        parser_expect(parser, DIRI_TOKEN_SEMI, "';'");
        return stmt;
    }

    if (parser_match(parser, DIRI_TOKEN_IF)) {
        stmt = diri_ast_stmt_new(DIRI_AST_IF_STMT);
        if (stmt == NULL) return NULL;
        stmt->as.if_stmt.condition = parse_expr(parser);
        if (!parse_block(parser, &stmt->as.if_stmt.then_block)) {
            return stmt;
        }
        if (parser_match(parser, DIRI_TOKEN_ELSE)) {
            if (!parse_block(parser, &stmt->as.if_stmt.else_block)) {
                return stmt;
            }
        }
        return stmt;
    }

    if (parser_match(parser, DIRI_TOKEN_WHILE)) {
        stmt = diri_ast_stmt_new(DIRI_AST_WHILE_STMT);
        if (stmt == NULL) return NULL;
        stmt->as.while_stmt.condition = parse_expr(parser);
        parse_block(parser, &stmt->as.while_stmt.body);
        return stmt;
    }

    if (parser->current.kind == DIRI_TOKEN_IDENT) {
        DiriAstExpr *target = parse_expr(parser);
        if (parser_match(parser, DIRI_TOKEN_EQUAL)) {
            if (target != NULL && target->kind == DIRI_AST_IDENT_EXPR) {
                stmt = diri_ast_stmt_new(DIRI_AST_ASSIGN_STMT);
                if (stmt == NULL) return NULL;
                stmt->as.assign_stmt.name = target->as.ident_name;
                target->as.ident_name = NULL;
                free(target);
                stmt->as.assign_stmt.value = parse_expr(parser);
                parser_expect(parser, DIRI_TOKEN_SEMI, "';'");
                return stmt;
            }
            if (target != NULL && target->kind == DIRI_AST_FIELD_EXPR) {
                stmt = diri_ast_stmt_new(DIRI_AST_FIELD_ASSIGN_STMT);
                if (stmt == NULL) return NULL;
                stmt->as.field_assign_stmt.target = target;
                stmt->as.field_assign_stmt.value = parse_expr(parser);
                parser_expect(parser, DIRI_TOKEN_SEMI, "';'");
                return stmt;
            }
            diri_error("invalid assignment target");
            parser->had_error = 1;
            return NULL;
        }
        stmt = diri_ast_stmt_new(DIRI_AST_EXPR_STMT);
        if (stmt == NULL) return NULL;
        stmt->as.expr_stmt.expr = target;
        parser_expect(parser, DIRI_TOKEN_SEMI, "';'");
        return stmt;
    }

    stmt = diri_ast_stmt_new(DIRI_AST_EXPR_STMT);
    if (stmt == NULL) return NULL;
    stmt->as.expr_stmt.expr = parse_expr(parser);
    parser_expect(parser, DIRI_TOKEN_SEMI, "';'");
    return stmt;
}

static void parse_param_list(DiriParser *parser, DiriAstDecl *decl) {
    while (parser->current.kind != DIRI_TOKEN_RPAREN && parser->current.kind != DIRI_TOKEN_EOF) {
        DiriAstParam param;
        if (parser->current.kind != DIRI_TOKEN_IDENT) {
            diri_error("expected parameter name at %d:%d", parser->current.line, parser->current.column);
            parser->had_error = 1;
            return;
        }
        param.name = parser_take_text(parser);
        parser_advance(parser);
        parser_expect(parser, DIRI_TOKEN_COLON, "':'");
        param.type = parse_type(parser);
        if (!diri_ast_decl_add_param(decl, param)) {
            parser->had_error = 1;
            return;
        }
        if (!parser_match(parser, DIRI_TOKEN_COMMA)) {
            break;
        }
    }
}

static DiriAstDecl *parse_struct_decl(DiriParser *parser) {
    DiriAstDecl *decl;
    char *name;

    parser_expect(parser, DIRI_TOKEN_STRUCT, "'struct'");
    if (parser->current.kind != DIRI_TOKEN_IDENT) {
        diri_error("expected struct name");
        parser->had_error = 1;
        return NULL;
    }
    name = parser_take_text(parser);
    parser_advance(parser);
    decl = diri_ast_decl_new(DIRI_AST_STRUCT_DECL, name);
    if (decl == NULL) {
        return NULL;
    }
    parser_expect(parser, DIRI_TOKEN_LBRACE, "'{'");
    while (parser->current.kind != DIRI_TOKEN_RBRACE && parser->current.kind != DIRI_TOKEN_EOF) {
        DiriAstField field;
        if (parser->current.kind != DIRI_TOKEN_IDENT) {
            diri_error("expected field name in struct");
            parser->had_error = 1;
            return decl;
        }
        field.name = parser_take_text(parser);
        parser_advance(parser);
        parser_expect(parser, DIRI_TOKEN_COLON, "':'");
        field.type = parse_type(parser);
        parser_expect(parser, DIRI_TOKEN_SEMI, "';'");
        if (!diri_ast_decl_add_field(decl, field)) {
            parser->had_error = 1;
            return decl;
        }
    }
    parser_expect(parser, DIRI_TOKEN_RBRACE, "'}'");
    return decl;
}

static DiriAstDecl *parse_function(DiriParser *parser, int is_extern) {
    DiriAstDecl *decl;
    char *name;

    parser_expect(parser, DIRI_TOKEN_FUNC, "'func'");
    if (parser->current.kind != DIRI_TOKEN_IDENT) {
        diri_error("expected function name at %d:%d", parser->current.line, parser->current.column);
        parser->had_error = 1;
        return NULL;
    }

    name = parser_take_text(parser);
    parser_advance(parser);
    decl = diri_ast_decl_new(is_extern ? DIRI_AST_EXTERN_FUNCTION : DIRI_AST_FUNCTION, name);
    if (decl == NULL) {
        return NULL;
    }

    parser_expect(parser, DIRI_TOKEN_LPAREN, "'('");
    parse_param_list(parser, decl);
    parser_expect(parser, DIRI_TOKEN_RPAREN, "')'");
    parser_expect(parser, DIRI_TOKEN_COLON, "':'");
    decl->return_type = parse_type(parser);

    if (is_extern) {
        parser_expect(parser, DIRI_TOKEN_SEMI, "';'");
        return decl;
    }

    parser_expect(parser, DIRI_TOKEN_LBRACE, "'{'");
    while (parser->current.kind != DIRI_TOKEN_RBRACE && parser->current.kind != DIRI_TOKEN_EOF) {
        DiriAstStmt *stmt = parse_stmt(parser);
        if (stmt == NULL || !diri_ast_decl_add_stmt(decl, stmt)) {
            parser->had_error = 1;
            return decl;
        }
    }
    parser_expect(parser, DIRI_TOKEN_RBRACE, "'}'");
    return decl;
}

DiriAstProgram *diri_parse_program(const char *source) {
    DiriParser parser;
    DiriAstProgram *program = diri_ast_program_new();

    if (program == NULL) {
        return NULL;
    }

    diri_lexer_init(&parser.lexer, source);
    parser.had_error = 0;
    parser_advance(&parser);

    if (parser.current.kind == DIRI_TOKEN_EOF) {
        diri_error("empty input");
        program->had_error = 1;
        return program;
    }

    while (parser.current.kind != DIRI_TOKEN_EOF) {
        DiriAstDecl *decl;
        int is_extern = parser_match(&parser, DIRI_TOKEN_EXTERN);

        if (!is_extern && parser.current.kind == DIRI_TOKEN_STRUCT) {
            decl = parse_struct_decl(&parser);
            if (decl == NULL || !diri_ast_program_add_decl(program, decl)) {
                parser.had_error = 1;
                break;
            }
            continue;
        }

        if (parser.current.kind != DIRI_TOKEN_FUNC) {
            diri_error("expected declaration at %d:%d", parser.current.line, parser.current.column);
            parser.had_error = 1;
            break;
        }

        decl = parse_function(&parser, is_extern);
        if (decl == NULL || !diri_ast_program_add_decl(program, decl)) {
            parser.had_error = 1;
            break;
        }
    }

    program->had_error = parser.had_error;
    return program;
}

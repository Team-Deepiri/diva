#include "lexer.h"

#include <ctype.h>
#include <string.h>

static DiToken make_token(DiLexer *lexer, DiTokenKind kind, const char *start, int length, int line, int column) {
    DiToken token;
    token.kind = kind;
    token.lexeme = start;
    token.length = length;
    token.line = line;
    token.column = column;
    return token;
}

static int is_ident_start(char c) {
    return isalpha((unsigned char)c) || c == '_';
}

static int is_ident_continue(char c) {
    return isalnum((unsigned char)c) || c == '_';
}

static DiTokenKind keyword_kind(const char *start, int length) {
    if (length == 4 && strncmp(start, "func", 4) == 0) return DI_TOKEN_FUNC;
    if (length == 6 && strncmp(start, "extern", 6) == 0) return DI_TOKEN_EXTERN;
    if (length == 6 && strncmp(start, "struct", 6) == 0) return DI_TOKEN_STRUCT;
    if (length == 5 && strncmp(start, "class", 5) == 0) return DI_TOKEN_CLASS;
    if (length == 3 && strncmp(start, "let", 3) == 0) return DI_TOKEN_LET;
    if (length == 3 && strncmp(start, "var", 3) == 0) return DI_TOKEN_VAR;
    if (length == 6 && strncmp(start, "return", 6) == 0) return DI_TOKEN_RETURN;
    if (length == 2 && strncmp(start, "if", 2) == 0) return DI_TOKEN_IF;
    if (length == 4 && strncmp(start, "else", 4) == 0) return DI_TOKEN_ELSE;
    if (length == 5 && strncmp(start, "while", 5) == 0) return DI_TOKEN_WHILE;
    if (length == 4 && strncmp(start, "flux", 4) == 0) return DI_TOKEN_FLUX;
    if (length == 2 && strncmp(start, "in", 2) == 0) return DI_TOKEN_IN;
    if (length == 4 && strncmp(start, "true", 4) == 0) return DI_TOKEN_TRUE;
    if (length == 5 && strncmp(start, "false", 5) == 0) return DI_TOKEN_FALSE;
    if (length == 7 && strncmp(start, "package", 7) == 0) return DI_TOKEN_PACKAGE;
    if (length == 6 && strncmp(start, "import", 6) == 0) return DI_TOKEN_IMPORT;
    return DI_TOKEN_IDENT;
}

void di_lexer_init(DiLexer *lexer, const char *source) {
    lexer->source = source;
    lexer->cursor = source;
    lexer->line = 1;
    lexer->column = 1;
}

DiToken di_lexer_next(DiLexer *lexer) {
    while (*lexer->cursor != '\0') {
        const char *start = lexer->cursor;
        int line = lexer->line;
        int column = lexer->column;
        char c = *lexer->cursor;

        if (c == ' ' || c == '\t' || c == '\r') {
            lexer->cursor++;
            lexer->column++;
            continue;
        }

        if (c == '\n') {
            lexer->cursor++;
            lexer->line++;
            lexer->column = 1;
            continue;
        }

        if (c == '/' && lexer->cursor[1] == '/') {
            lexer->cursor += 2;
            lexer->column += 2;
            while (*lexer->cursor != '\0' && *lexer->cursor != '\n') {
                lexer->cursor++;
                lexer->column++;
            }
            continue;
        }

        if (is_ident_start(c)) {
            lexer->cursor++;
            lexer->column++;
            while (is_ident_continue(*lexer->cursor)) {
                lexer->cursor++;
                lexer->column++;
            }
            return make_token(lexer, keyword_kind(start, (int)(lexer->cursor - start)), start, (int)(lexer->cursor - start), line, column);
        }

        if (isdigit((unsigned char)c)) {
            lexer->cursor++;
            lexer->column++;
            while (isdigit((unsigned char)*lexer->cursor)) {
                lexer->cursor++;
                lexer->column++;
            }
            return make_token(lexer, DI_TOKEN_INT_LIT, start, (int)(lexer->cursor - start), line, column);
        }

        if (c == '"') {
            lexer->cursor++;
            lexer->column++;
            while (*lexer->cursor != '\0' && *lexer->cursor != '"') {
                if (*lexer->cursor == '\n') {
                    lexer->line++;
                    lexer->column = 1;
                    lexer->cursor++;
                    continue;
                }
                lexer->cursor++;
                lexer->column++;
            }
            if (*lexer->cursor == '"') {
                lexer->cursor++;
                lexer->column++;
                return make_token(lexer, DI_TOKEN_STRING_LIT, start, (int)(lexer->cursor - start), line, column);
            }
            return make_token(lexer, DI_TOKEN_INVALID, start, (int)(lexer->cursor - start), line, column);
        }

        lexer->cursor++;
        lexer->column++;
        switch (c) {
            case '(': return make_token(lexer, DI_TOKEN_LPAREN, start, 1, line, column);
            case ')': return make_token(lexer, DI_TOKEN_RPAREN, start, 1, line, column);
            case '[': return make_token(lexer, DI_TOKEN_LBRACKET, start, 1, line, column);
            case ']': return make_token(lexer, DI_TOKEN_RBRACKET, start, 1, line, column);
            case '{': return make_token(lexer, DI_TOKEN_LBRACE, start, 1, line, column);
            case '}': return make_token(lexer, DI_TOKEN_RBRACE, start, 1, line, column);
            case '.':
                if (*lexer->cursor == '.') {
                    lexer->cursor++;
                    lexer->column++;
                    return make_token(lexer, DI_TOKEN_DOTDOT, start, 2, line, column);
                }
                return make_token(lexer, DI_TOKEN_DOT, start, 1, line, column);
            case ':':
                if (*lexer->cursor == ':') {
                    lexer->cursor++;
                    lexer->column++;
                    return make_token(lexer, DI_TOKEN_DOUBLECOLON, start, 2, line, column);
                }
                return make_token(lexer, DI_TOKEN_COLON, start, 1, line, column);
            case ';': return make_token(lexer, DI_TOKEN_SEMI, start, 1, line, column);
            case ',': return make_token(lexer, DI_TOKEN_COMMA, start, 1, line, column);
            case '+': return make_token(lexer, DI_TOKEN_PLUS, start, 1, line, column);
            case '-': return make_token(lexer, DI_TOKEN_MINUS, start, 1, line, column);
            case '*': return make_token(lexer, DI_TOKEN_STAR, start, 1, line, column);
            case '/': return make_token(lexer, DI_TOKEN_SLASH, start, 1, line, column);
            case '!':
                if (*lexer->cursor == '=') {
                    lexer->cursor++;
                    lexer->column++;
                    return make_token(lexer, DI_TOKEN_BANGEQ, start, 2, line, column);
                }
                return make_token(lexer, DI_TOKEN_BANG, start, 1, line, column);
            case '&': return make_token(lexer, DI_TOKEN_AMP, start, 1, line, column);
            case '|': return make_token(lexer, DI_TOKEN_PIPE, start, 1, line, column);
            case '<':
                if (*lexer->cursor == '=') {
                    lexer->cursor++;
                    lexer->column++;
                    return make_token(lexer, DI_TOKEN_LE, start, 2, line, column);
                }
                return make_token(lexer, DI_TOKEN_LT, start, 1, line, column);
            case '>':
                if (*lexer->cursor == '=') {
                    lexer->cursor++;
                    lexer->column++;
                    return make_token(lexer, DI_TOKEN_GE, start, 2, line, column);
                }
                return make_token(lexer, DI_TOKEN_GT, start, 1, line, column);
            case '=':
                if (*lexer->cursor == '=') {
                    lexer->cursor++;
                    lexer->column++;
                    return make_token(lexer, DI_TOKEN_EQEQ, start, 2, line, column);
                }
                if (*lexer->cursor == '>') {
                    lexer->cursor++;
                    lexer->column++;
                    return make_token(lexer, DI_TOKEN_FATARROW, start, 2, line, column);
                }
                return make_token(lexer, DI_TOKEN_EQUAL, start, 1, line, column);
            default:
                break;
        }

        return make_token(lexer, DI_TOKEN_INVALID, start, 1, line, column);
    }

    return make_token(lexer, DI_TOKEN_EOF, lexer->cursor, 0, lexer->line, lexer->column);
}

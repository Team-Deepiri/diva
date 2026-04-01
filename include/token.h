#ifndef DIRI_TOKEN_H
#define DIRI_TOKEN_H

typedef enum {
    DIRI_TOKEN_EOF = 0,
    DIRI_TOKEN_INVALID,
    DIRI_TOKEN_IDENT,
    DIRI_TOKEN_INT_LIT,
    DIRI_TOKEN_STRING_LIT,
    DIRI_TOKEN_FUNC,
    DIRI_TOKEN_STRUCT,
    DIRI_TOKEN_EXTERN,
    DIRI_TOKEN_LET,
    DIRI_TOKEN_RETURN,
    DIRI_TOKEN_IF,
    DIRI_TOKEN_ELSE,
    DIRI_TOKEN_WHILE,
    DIRI_TOKEN_TRUE,
    DIRI_TOKEN_FALSE,
    DIRI_TOKEN_LPAREN,
    DIRI_TOKEN_RPAREN,
    DIRI_TOKEN_LBRACKET,
    DIRI_TOKEN_RBRACKET,
    DIRI_TOKEN_LBRACE,
    DIRI_TOKEN_RBRACE,
    DIRI_TOKEN_DOT,
    DIRI_TOKEN_COLON,
    DIRI_TOKEN_SEMI,
    DIRI_TOKEN_COMMA,
    DIRI_TOKEN_EQUAL,
    DIRI_TOKEN_ARROW,
    DIRI_TOKEN_PLUS,
    DIRI_TOKEN_MINUS,
    DIRI_TOKEN_STAR,
    DIRI_TOKEN_SLASH,
    DIRI_TOKEN_EQEQ,
    DIRI_TOKEN_BANGEQ,
    DIRI_TOKEN_LT,
    DIRI_TOKEN_GT,
    DIRI_TOKEN_LE,
    DIRI_TOKEN_GE
} DiriTokenKind;

typedef struct {
    DiriTokenKind kind;
    const char *lexeme;
    int length;
    int line;
    int column;
} DiriToken;

const char *diri_token_kind_name(DiriTokenKind kind);

#endif

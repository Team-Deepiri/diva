#ifndef DI_TOKEN_H
#define DI_TOKEN_H

typedef enum {
    DI_TOKEN_EOF = 0,
    DI_TOKEN_INVALID,
    DI_TOKEN_IDENT,
    DI_TOKEN_INT_LIT,
    DI_TOKEN_STRING_LIT,
    DI_TOKEN_FUNC,
    DI_TOKEN_EXTERN,
    DI_TOKEN_STRUCT,
    DI_TOKEN_CLASS,
    DI_TOKEN_LET,
    DI_TOKEN_VAR,
    DI_TOKEN_RETURN,
    DI_TOKEN_IF,
    DI_TOKEN_ELSE,
    DI_TOKEN_WHILE,
    DI_TOKEN_FLUX,
    DI_TOKEN_IN,
    DI_TOKEN_TRUE,
    DI_TOKEN_FALSE,
    DI_TOKEN_PACKAGE,
    DI_TOKEN_IMPORT,
    DI_TOKEN_LPAREN,
    DI_TOKEN_RPAREN,
    DI_TOKEN_LBRACKET,
    DI_TOKEN_RBRACKET,
    DI_TOKEN_LBRACE,
    DI_TOKEN_RBRACE,
    DI_TOKEN_DOT,
    DI_TOKEN_DOTDOT,
    DI_TOKEN_COLON,
    DI_TOKEN_DOUBLECOLON,
    DI_TOKEN_SEMI,
    DI_TOKEN_COMMA,
    DI_TOKEN_EQUAL,
    DI_TOKEN_FATARROW,
    DI_TOKEN_PLUS,
    DI_TOKEN_MINUS,
    DI_TOKEN_STAR,
    DI_TOKEN_SLASH,
    DI_TOKEN_BANG,
    DI_TOKEN_AMP,
    DI_TOKEN_PIPE,
    DI_TOKEN_EQEQ,
    DI_TOKEN_BANGEQ,
    DI_TOKEN_LT,
    DI_TOKEN_GT,
    DI_TOKEN_LE,
    DI_TOKEN_GE
} DiTokenKind;

typedef struct {
    DiTokenKind kind;
    const char *lexeme;
    int length;
    int line;
    int column;
} DiToken;

const char *di_token_kind_name(DiTokenKind kind);

#endif

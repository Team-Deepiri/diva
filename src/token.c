#include "token.h"

const char *di_token_kind_name(DiTokenKind kind) {
    switch (kind) {
        case DI_TOKEN_EOF: return "eof";
        case DI_TOKEN_INVALID: return "invalid";
        case DI_TOKEN_IDENT: return "identifier";
        case DI_TOKEN_INT_LIT: return "int_lit";
        case DI_TOKEN_STRING_LIT: return "string_lit";
        case DI_TOKEN_FUNC: return "func";
        case DI_TOKEN_EXTERN: return "extern";
        case DI_TOKEN_STRUCT: return "struct";
        case DI_TOKEN_CLASS: return "class";
        case DI_TOKEN_LET: return "let";
        case DI_TOKEN_VAR: return "var";
        case DI_TOKEN_RETURN: return "return";
        case DI_TOKEN_IF: return "if";
        case DI_TOKEN_ELSE: return "else";
        case DI_TOKEN_WHILE: return "while";
        case DI_TOKEN_FLUX: return "flux";
        case DI_TOKEN_IN: return "in";
        case DI_TOKEN_TRUE: return "true";
        case DI_TOKEN_FALSE: return "false";
        case DI_TOKEN_IMPORT: return "import";
        case DI_TOKEN_LPAREN: return "(";
        case DI_TOKEN_RPAREN: return ")";
        case DI_TOKEN_LBRACKET: return "[";
        case DI_TOKEN_RBRACKET: return "]";
        case DI_TOKEN_LBRACE: return "{";
        case DI_TOKEN_RBRACE: return "}";
        case DI_TOKEN_DOT: return ".";
        case DI_TOKEN_DOTDOT: return "..";
        case DI_TOKEN_COLON: return ":";
        case DI_TOKEN_DOUBLECOLON: return "::";
        case DI_TOKEN_SEMI: return ";";
        case DI_TOKEN_COMMA: return ",";
        case DI_TOKEN_EQUAL: return "=";
        case DI_TOKEN_FATARROW: return "=>";
        case DI_TOKEN_PLUS: return "+";
        case DI_TOKEN_MINUS: return "-";
        case DI_TOKEN_STAR: return "*";
        case DI_TOKEN_SLASH: return "/";
        case DI_TOKEN_BANG: return "!";
        case DI_TOKEN_AMP: return "&";
        case DI_TOKEN_PIPE: return "|";
        case DI_TOKEN_EQEQ: return "==";
        case DI_TOKEN_BANGEQ: return "!=";
        case DI_TOKEN_LT: return "<";
        case DI_TOKEN_GT: return ">";
        case DI_TOKEN_LE: return "<=";
        case DI_TOKEN_GE: return ">=";
        default: return "unknown";
    }
}

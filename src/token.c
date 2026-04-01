#include "token.h"

const char *diri_token_kind_name(DiriTokenKind kind) {
    switch (kind) {
        case DIRI_TOKEN_EOF: return "eof";
        case DIRI_TOKEN_INVALID: return "invalid";
        case DIRI_TOKEN_IDENT: return "identifier";
        case DIRI_TOKEN_INT_LIT: return "int_lit";
        case DIRI_TOKEN_STRING_LIT: return "string_lit";
        case DIRI_TOKEN_FUNC: return "func";
        case DIRI_TOKEN_STRUCT: return "struct";
        case DIRI_TOKEN_EXTERN: return "extern";
        case DIRI_TOKEN_LET: return "let";
        case DIRI_TOKEN_RETURN: return "return";
        case DIRI_TOKEN_IF: return "if";
        case DIRI_TOKEN_ELSE: return "else";
        case DIRI_TOKEN_WHILE: return "while";
        case DIRI_TOKEN_TRUE: return "true";
        case DIRI_TOKEN_FALSE: return "false";
        case DIRI_TOKEN_LPAREN: return "(";
        case DIRI_TOKEN_RPAREN: return ")";
        case DIRI_TOKEN_LBRACKET: return "[";
        case DIRI_TOKEN_RBRACKET: return "]";
        case DIRI_TOKEN_LBRACE: return "{";
        case DIRI_TOKEN_RBRACE: return "}";
        case DIRI_TOKEN_DOT: return ".";
        case DIRI_TOKEN_COLON: return ":";
        case DIRI_TOKEN_SEMI: return ";";
        case DIRI_TOKEN_COMMA: return ",";
        case DIRI_TOKEN_EQUAL: return "=";
        case DIRI_TOKEN_ARROW: return "->";
        case DIRI_TOKEN_PLUS: return "+";
        case DIRI_TOKEN_MINUS: return "-";
        case DIRI_TOKEN_STAR: return "*";
        case DIRI_TOKEN_SLASH: return "/";
        case DIRI_TOKEN_EQEQ: return "==";
        case DIRI_TOKEN_BANGEQ: return "!=";
        case DIRI_TOKEN_LT: return "<";
        case DIRI_TOKEN_GT: return ">";
        case DIRI_TOKEN_LE: return "<=";
        case DIRI_TOKEN_GE: return ">=";
        default: return "unknown";
    }
}

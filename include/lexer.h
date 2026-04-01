#ifndef DIRI_LEXER_H
#define DIRI_LEXER_H

#include "token.h"

typedef struct {
    const char *source;
    const char *cursor;
    int line;
    int column;
} DiriLexer;

void diri_lexer_init(DiriLexer *lexer, const char *source);
DiriToken diri_lexer_next(DiriLexer *lexer);

#endif

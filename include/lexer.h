#ifndef DI_LEXER_H
#define DI_LEXER_H

#include "token.h"

typedef struct {
    const char *source;
    const char *cursor;
    int line;
    int column;
} DiLexer;

void di_lexer_init(DiLexer *lexer, const char *source);
DiToken di_lexer_next(DiLexer *lexer);

#endif

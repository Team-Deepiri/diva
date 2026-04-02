import "std/host.di"
import "std/vec.di"

extern func print_str(x: str): void

class LexerState {
    source: str
    cursor: int
    line: int
    column: int
    tok_start: int
    tok_len: int
    tok_line: int
    tok_col: int
}

func is_ident_start(c: int): int {
    if c < 0 {
        return 0
    }
    if c == 95 {
        return 1
    }
    if c >= 97 & c <= 122 {
        return 1
    }
    if c >= 65 & c <= 90 {
        return 1
    }
    return 0
}

func is_ident_continue(c: int): int {
    if is_ident_start(c) == 1 {
        return 1
    }
    if c >= 48 & c <= 57 {
        return 1
    }
    return 0
}

func keyword_kind(word: str): int {
    if str_eq(word, "func") == 1 {
        return 5
    }
    if str_eq(word, "extern") == 1 {
        return 6
    }
    if str_eq(word, "struct") == 1 {
        return 7
    }
    if str_eq(word, "class") == 1 {
        return 8
    }
    if str_eq(word, "let") == 1 {
        return 9
    }
    if str_eq(word, "var") == 1 {
        return 10
    }
    if str_eq(word, "return") == 1 {
        return 11
    }
    if str_eq(word, "if") == 1 {
        return 12
    }
    if str_eq(word, "else") == 1 {
        return 13
    }
    if str_eq(word, "while") == 1 {
        return 14
    }
    if str_eq(word, "flux") == 1 {
        return 15
    }
    if str_eq(word, "in") == 1 {
        return 16
    }
    if str_eq(word, "true") == 1 {
        return 17
    }
    if str_eq(word, "false") == 1 {
        return 18
    }
    if str_eq(word, "package") == 1 {
        return 19
    }
    if str_eq(word, "import") == 1 {
        return 20
    }
    if str_eq(word, "trait") == 1 {
        return 21
    }
    if str_eq(word, "impl") == 1 {
        return 22
    }
    if str_eq(word, "for") == 1 {
        return 23
    }
    return 2
}

func kind_name(kind: int): str {
    if kind == 0 {
        return "eof"
    }
    if kind == 1 {
        return "invalid"
    }
    if kind == 2 {
        return "identifier"
    }
    if kind == 3 {
        return "int_lit"
    }
    if kind == 4 {
        return "string_lit"
    }
    if kind == 5 {
        return "func"
    }
    if kind == 6 {
        return "extern"
    }
    if kind == 7 {
        return "struct"
    }
    if kind == 8 {
        return "class"
    }
    if kind == 9 {
        return "let"
    }
    if kind == 10 {
        return "var"
    }
    if kind == 11 {
        return "return"
    }
    if kind == 12 {
        return "if"
    }
    if kind == 13 {
        return "else"
    }
    if kind == 14 {
        return "while"
    }
    if kind == 15 {
        return "flux"
    }
    if kind == 16 {
        return "in"
    }
    if kind == 17 {
        return "true"
    }
    if kind == 18 {
        return "false"
    }
    if kind == 19 {
        return "package"
    }
    if kind == 20 {
        return "import"
    }
    if kind == 21 {
        return "trait"
    }
    if kind == 22 {
        return "impl"
    }
    if kind == 23 {
        return "for"
    }
    if kind == 24 {
        return "("
    }
    if kind == 25 {
        return ")"
    }
    if kind == 26 {
        return "["
    }
    if kind == 27 {
        return "]"
    }
    if kind == 28 {
        return "{"
    }
    if kind == 29 {
        return "}"
    }
    if kind == 30 {
        return "."
    }
    if kind == 31 {
        return ".."
    }
    if kind == 32 {
        return ":"
    }
    if kind == 33 {
        return "::"
    }
    if kind == 34 {
        return ";"
    }
    if kind == 35 {
        return ","
    }
    if kind == 36 {
        return "="
    }
    if kind == 37 {
        return "=>"
    }
    if kind == 38 {
        return "+"
    }
    if kind == 39 {
        return "-"
    }
    if kind == 40 {
        return "*"
    }
    if kind == 41 {
        return "/"
    }
    if kind == 42 {
        return "!"
    }
    if kind == 43 {
        return "&"
    }
    if kind == 44 {
        return "|"
    }
    if kind == 45 {
        return "=="
    }
    if kind == 46 {
        return "!="
    }
    if kind == 47 {
        return "<"
    }
    if kind == 48 {
        return ">"
    }
    if kind == 49 {
        return "<="
    }
    if kind == 50 {
        return ">="
    }
    return "unknown"
}

func pad_kind_name(sb: int, name: str): void {
    str_builder_append(sb, name)
    var n = str_len(name)
    while n < 12 {
        str_builder_append(sb, " ")
        n = n + 1
    }
}

func dump_token_line(source: str, kind: int, tok_start: int, tok_len: int, line: int, col: int): void {
    var b = str_builder_new()
    str_builder_append(b, "token ")
    pad_kind_name(b, kind_name(kind))
    str_builder_append(b, " '")
    str_builder_append(b, str_slice(source, tok_start, tok_len))
    str_builder_append(b, "' @ ")
    str_builder_append(b, int_to_str(line))
    str_builder_append(b, ":")
    str_builder_append(b, int_to_str(col))
    print_str(str_builder_to_str(b))
    str_builder_free(b)
}

func lexer_next(state: LexerState): int {
    var slen = str_len(state.source)
    var done_skip = 0

    while done_skip == 0 & state.cursor < slen {
        var c = str_byte(state.source, state.cursor)
        if c == 32 | c == 9 | c == 13 {
            state.cursor = state.cursor + 1
            state.column = state.column + 1
        } else {
            if c == 10 {
                state.cursor = state.cursor + 1
                state.line = state.line + 1
                state.column = 1
            } else {
                if c == 47 & state.cursor + 1 < slen & str_byte(state.source, state.cursor + 1) == 47 {
                    state.cursor = state.cursor + 2
                    state.column = state.column + 2
                    while state.cursor < slen & str_byte(state.source, state.cursor) != 10 {
                        state.cursor = state.cursor + 1
                        state.column = state.column + 1
                    }
                } else {
                    done_skip = 1
                }
            }
        }
    }

    if state.cursor >= slen {
        state.tok_start = state.cursor
        state.tok_len = 0
        state.tok_line = state.line
        state.tok_col = state.column
        return 0
    }

    var c2 = str_byte(state.source, state.cursor)
    var line0 = state.line
    var col0 = state.column
    var start0 = state.cursor

    if is_ident_start(c2) == 1 {
        state.cursor = state.cursor + 1
        state.column = state.column + 1
        while state.cursor < slen & is_ident_continue(str_byte(state.source, state.cursor)) == 1 {
            state.cursor = state.cursor + 1
            state.column = state.column + 1
        }
        state.tok_start = start0
        state.tok_len = state.cursor - start0
        state.tok_line = line0
        state.tok_col = col0
        return keyword_kind(str_slice(state.source, start0, state.cursor - start0))
    }

    if c2 >= 48 & c2 <= 57 {
        state.cursor = state.cursor + 1
        state.column = state.column + 1
        var still_num = 1
        while state.cursor < slen & still_num == 1 {
            var d = str_byte(state.source, state.cursor)
            if d >= 48 & d <= 57 {
                state.cursor = state.cursor + 1
                state.column = state.column + 1
            } else {
                still_num = 0
            }
        }
        state.tok_start = start0
        state.tok_len = state.cursor - start0
        state.tok_line = line0
        state.tok_col = col0
        return 3
    }

    if c2 == 34 {
        state.cursor = state.cursor + 1
        state.column = state.column + 1
        while state.cursor < slen {
            var ch = str_byte(state.source, state.cursor)
            if ch == 34 {
                state.cursor = state.cursor + 1
                state.column = state.column + 1
                state.tok_start = start0
                state.tok_len = state.cursor - start0
                state.tok_line = line0
                state.tok_col = col0
                return 4
            } else {
                if ch == 10 {
                    state.cursor = state.cursor + 1
                    state.line = state.line + 1
                    state.column = 1
                } else {
                    state.cursor = state.cursor + 1
                    state.column = state.column + 1
                }
            }
        }
        state.tok_start = start0
        state.tok_len = state.cursor - start0
        state.tok_line = line0
        state.tok_col = col0
        return 1
    }

    state.cursor = state.cursor + 1
    state.column = state.column + 1

    if c2 == 40 {
        state.tok_start = start0
        state.tok_len = 1
        state.tok_line = line0
        state.tok_col = col0
        return 24
    }
    if c2 == 41 {
        state.tok_start = start0
        state.tok_len = 1
        state.tok_line = line0
        state.tok_col = col0
        return 25
    }
    if c2 == 91 {
        state.tok_start = start0
        state.tok_len = 1
        state.tok_line = line0
        state.tok_col = col0
        return 26
    }
    if c2 == 93 {
        state.tok_start = start0
        state.tok_len = 1
        state.tok_line = line0
        state.tok_col = col0
        return 27
    }
    if c2 == 123 {
        state.tok_start = start0
        state.tok_len = 1
        state.tok_line = line0
        state.tok_col = col0
        return 28
    }
    if c2 == 125 {
        state.tok_start = start0
        state.tok_len = 1
        state.tok_line = line0
        state.tok_col = col0
        return 29
    }
    if c2 == 46 {
        if state.cursor < slen & str_byte(state.source, state.cursor) == 46 {
            state.cursor = state.cursor + 1
            state.column = state.column + 1
            state.tok_start = start0
            state.tok_len = 2
            state.tok_line = line0
            state.tok_col = col0
            return 31
        }
        state.tok_start = start0
        state.tok_len = 1
        state.tok_line = line0
        state.tok_col = col0
        return 30
    }
    if c2 == 58 {
        if state.cursor < slen & str_byte(state.source, state.cursor) == 58 {
            state.cursor = state.cursor + 1
            state.column = state.column + 1
            state.tok_start = start0
            state.tok_len = 2
            state.tok_line = line0
            state.tok_col = col0
            return 33
        }
        state.tok_start = start0
        state.tok_len = 1
        state.tok_line = line0
        state.tok_col = col0
        return 32
    }
    if c2 == 59 {
        state.tok_start = start0
        state.tok_len = 1
        state.tok_line = line0
        state.tok_col = col0
        return 34
    }
    if c2 == 44 {
        state.tok_start = start0
        state.tok_len = 1
        state.tok_line = line0
        state.tok_col = col0
        return 35
    }
    if c2 == 43 {
        state.tok_start = start0
        state.tok_len = 1
        state.tok_line = line0
        state.tok_col = col0
        return 38
    }
    if c2 == 45 {
        state.tok_start = start0
        state.tok_len = 1
        state.tok_line = line0
        state.tok_col = col0
        return 39
    }
    if c2 == 42 {
        state.tok_start = start0
        state.tok_len = 1
        state.tok_line = line0
        state.tok_col = col0
        return 40
    }
    if c2 == 47 {
        state.tok_start = start0
        state.tok_len = 1
        state.tok_line = line0
        state.tok_col = col0
        return 41
    }
    if c2 == 33 {
        if state.cursor < slen & str_byte(state.source, state.cursor) == 61 {
            state.cursor = state.cursor + 1
            state.column = state.column + 1
            state.tok_start = start0
            state.tok_len = 2
            state.tok_line = line0
            state.tok_col = col0
            return 46
        }
        state.tok_start = start0
        state.tok_len = 1
        state.tok_line = line0
        state.tok_col = col0
        return 42
    }
    if c2 == 38 {
        state.tok_start = start0
        state.tok_len = 1
        state.tok_line = line0
        state.tok_col = col0
        return 43
    }
    if c2 == 124 {
        state.tok_start = start0
        state.tok_len = 1
        state.tok_line = line0
        state.tok_col = col0
        return 44
    }
    if c2 == 60 {
        if state.cursor < slen & str_byte(state.source, state.cursor) == 61 {
            state.cursor = state.cursor + 1
            state.column = state.column + 1
            state.tok_start = start0
            state.tok_len = 2
            state.tok_line = line0
            state.tok_col = col0
            return 49
        }
        state.tok_start = start0
        state.tok_len = 1
        state.tok_line = line0
        state.tok_col = col0
        return 47
    }
    if c2 == 62 {
        if state.cursor < slen & str_byte(state.source, state.cursor) == 61 {
            state.cursor = state.cursor + 1
            state.column = state.column + 1
            state.tok_start = start0
            state.tok_len = 2
            state.tok_line = line0
            state.tok_col = col0
            return 50
        }
        state.tok_start = start0
        state.tok_len = 1
        state.tok_line = line0
        state.tok_col = col0
        return 48
    }
    if c2 == 61 {
        if state.cursor < slen & str_byte(state.source, state.cursor) == 61 {
            state.cursor = state.cursor + 1
            state.column = state.column + 1
            state.tok_start = start0
            state.tok_len = 2
            state.tok_line = line0
            state.tok_col = col0
            return 45
        }
        if state.cursor < slen & str_byte(state.source, state.cursor) == 62 {
            state.cursor = state.cursor + 1
            state.column = state.column + 1
            state.tok_start = start0
            state.tok_len = 2
            state.tok_line = line0
            state.tok_col = col0
            return 37
        }
        state.tok_start = start0
        state.tok_len = 1
        state.tok_line = line0
        state.tok_col = col0
        return 36
    }

    state.tok_start = start0
    state.tok_len = 1
    state.tok_line = line0
    state.tok_col = col0
    return 1
}

func run_lexer_on_source(source: str): void {
    var state = LexerState { source: source, cursor: 0, line: 1, column: 1, tok_start: 0, tok_len: 0, tok_line: 1, tok_col: 1 }
    var more = 1
    while more == 1 {
        var k = lexer_next(state)
        dump_token_line(source, k, state.tok_start, state.tok_len, state.tok_line, state.tok_col)
        if k == 0 {
            more = 0
        } else {
            if k == 1 {
                more = 0
            } else {
                more = 1
            }
        }
    }
}


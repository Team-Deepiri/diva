import "std/host.di"
import "std/vec.di"

extern func print_str(x: str): void

class LexStep {
    kind: int
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

func lexer_step(source: str, cursor: int, line: int, column: int): LexStep {
    var cur = cursor
    var ln = line
    var co = column
    var slen = str_len(source)
    var ts = 0
    var tl = 0
    var tln = 0
    var tco = 0
    var done_skip = 0

    while done_skip == 0 & cur < slen {
        var c = str_byte(source, cur)
        if c == 32 | c == 9 | c == 13 {
            cur = cur + 1
            co = co + 1
        } else {
            if c == 10 {
                cur = cur + 1
                ln = ln + 1
                co = 1
            } else {
                if c == 47 & cur + 1 < slen & str_byte(source, cur + 1) == 47 {
                    cur = cur + 2
                    co = co + 2
                    while cur < slen & str_byte(source, cur) != 10 {
                        cur = cur + 1
                        co = co + 1
                    }
                } else {
                    done_skip = 1
                }
            }
        }
    }

    if cur >= slen {
        ts = cur
        tl = 0
        tln = ln
        tco = co
        return LexStep { kind: 0, cursor: cur, line: ln, column: co, tok_start: ts, tok_len: tl, tok_line: tln, tok_col: tco }
    }

    var c2 = str_byte(source, cur)
    var line0 = ln
    var col0 = co
    var start0 = cur

    if is_ident_start(c2) == 1 {
        cur = cur + 1
        co = co + 1
        while cur < slen & is_ident_continue(str_byte(source, cur)) == 1 {
            cur = cur + 1
            co = co + 1
        }
        ts = start0
        tl = cur - start0
        tln = line0
        tco = col0
        var kw = keyword_kind(str_slice(source, start0, cur - start0))
        return LexStep { kind: kw, cursor: cur, line: ln, column: co, tok_start: ts, tok_len: tl, tok_line: tln, tok_col: tco }
    }

    if c2 >= 48 & c2 <= 57 {
        cur = cur + 1
        co = co + 1
        var still_num = 1
        while cur < slen & still_num == 1 {
            var d = str_byte(source, cur)
            if d >= 48 & d <= 57 {
                cur = cur + 1
                co = co + 1
            } else {
                still_num = 0
            }
        }
        ts = start0
        tl = cur - start0
        tln = line0
        tco = col0
        return LexStep { kind: 3, cursor: cur, line: ln, column: co, tok_start: ts, tok_len: tl, tok_line: tln, tok_col: tco }
    }

    if c2 == 34 {
        cur = cur + 1
        co = co + 1
        while cur < slen {
            var ch = str_byte(source, cur)
            if ch == 34 {
                cur = cur + 1
                co = co + 1
                ts = start0
                tl = cur - start0
                tln = line0
                tco = col0
                return LexStep { kind: 4, cursor: cur, line: ln, column: co, tok_start: ts, tok_len: tl, tok_line: tln, tok_col: tco }
            } else {
                if ch == 10 {
                    cur = cur + 1
                    ln = ln + 1
                    co = 1
                } else {
                    cur = cur + 1
                    co = co + 1
                }
            }
        }
        ts = start0
        tl = cur - start0
        tln = line0
        tco = col0
        return LexStep { kind: 1, cursor: cur, line: ln, column: co, tok_start: ts, tok_len: tl, tok_line: tln, tok_col: tco }
    }

    cur = cur + 1
    co = co + 1

    if c2 == 40 {
        ts = start0
        tl = 1
        tln = line0
        tco = col0
        return LexStep { kind: 24, cursor: cur, line: ln, column: co, tok_start: ts, tok_len: tl, tok_line: tln, tok_col: tco }
    }
    if c2 == 41 {
        ts = start0
        tl = 1
        tln = line0
        tco = col0
        return LexStep { kind: 25, cursor: cur, line: ln, column: co, tok_start: ts, tok_len: tl, tok_line: tln, tok_col: tco }
    }
    if c2 == 91 {
        ts = start0
        tl = 1
        tln = line0
        tco = col0
        return LexStep { kind: 26, cursor: cur, line: ln, column: co, tok_start: ts, tok_len: tl, tok_line: tln, tok_col: tco }
    }
    if c2 == 93 {
        ts = start0
        tl = 1
        tln = line0
        tco = col0
        return LexStep { kind: 27, cursor: cur, line: ln, column: co, tok_start: ts, tok_len: tl, tok_line: tln, tok_col: tco }
    }
    if c2 == 123 {
        ts = start0
        tl = 1
        tln = line0
        tco = col0
        return LexStep { kind: 28, cursor: cur, line: ln, column: co, tok_start: ts, tok_len: tl, tok_line: tln, tok_col: tco }
    }
    if c2 == 125 {
        ts = start0
        tl = 1
        tln = line0
        tco = col0
        return LexStep { kind: 29, cursor: cur, line: ln, column: co, tok_start: ts, tok_len: tl, tok_line: tln, tok_col: tco }
    }
    if c2 == 46 {
        if cur < slen & str_byte(source, cur) == 46 {
            cur = cur + 1
            co = co + 1
            ts = start0
            tl = 2
            tln = line0
            tco = col0
        return LexStep { kind: 31, cursor: cur, line: ln, column: co, tok_start: ts, tok_len: tl, tok_line: tln, tok_col: tco }
        }
        ts = start0
        tl = 1
        tln = line0
        tco = col0
        return LexStep { kind: 30, cursor: cur, line: ln, column: co, tok_start: ts, tok_len: tl, tok_line: tln, tok_col: tco }
    }
    if c2 == 58 {
        if cur < slen & str_byte(source, cur) == 58 {
            cur = cur + 1
            co = co + 1
            ts = start0
            tl = 2
            tln = line0
            tco = col0
        return LexStep { kind: 33, cursor: cur, line: ln, column: co, tok_start: ts, tok_len: tl, tok_line: tln, tok_col: tco }
        }
        ts = start0
        tl = 1
        tln = line0
        tco = col0
        return LexStep { kind: 32, cursor: cur, line: ln, column: co, tok_start: ts, tok_len: tl, tok_line: tln, tok_col: tco }
    }
    if c2 == 59 {
        ts = start0
        tl = 1
        tln = line0
        tco = col0
        return LexStep { kind: 34, cursor: cur, line: ln, column: co, tok_start: ts, tok_len: tl, tok_line: tln, tok_col: tco }
    }
    if c2 == 44 {
        ts = start0
        tl = 1
        tln = line0
        tco = col0
        return LexStep { kind: 35, cursor: cur, line: ln, column: co, tok_start: ts, tok_len: tl, tok_line: tln, tok_col: tco }
    }
    if c2 == 43 {
        ts = start0
        tl = 1
        tln = line0
        tco = col0
        return LexStep { kind: 38, cursor: cur, line: ln, column: co, tok_start: ts, tok_len: tl, tok_line: tln, tok_col: tco }
    }
    if c2 == 45 {
        ts = start0
        tl = 1
        tln = line0
        tco = col0
        return LexStep { kind: 39, cursor: cur, line: ln, column: co, tok_start: ts, tok_len: tl, tok_line: tln, tok_col: tco }
    }
    if c2 == 42 {
        ts = start0
        tl = 1
        tln = line0
        tco = col0
        return LexStep { kind: 40, cursor: cur, line: ln, column: co, tok_start: ts, tok_len: tl, tok_line: tln, tok_col: tco }
    }
    if c2 == 47 {
        ts = start0
        tl = 1
        tln = line0
        tco = col0
        return LexStep { kind: 41, cursor: cur, line: ln, column: co, tok_start: ts, tok_len: tl, tok_line: tln, tok_col: tco }
    }
    if c2 == 33 {
        if cur < slen & str_byte(source, cur) == 61 {
            cur = cur + 1
            co = co + 1
            ts = start0
            tl = 2
            tln = line0
            tco = col0
        return LexStep { kind: 46, cursor: cur, line: ln, column: co, tok_start: ts, tok_len: tl, tok_line: tln, tok_col: tco }
        }
        ts = start0
        tl = 1
        tln = line0
        tco = col0
        return LexStep { kind: 42, cursor: cur, line: ln, column: co, tok_start: ts, tok_len: tl, tok_line: tln, tok_col: tco }
    }
    if c2 == 38 {
        ts = start0
        tl = 1
        tln = line0
        tco = col0
        return LexStep { kind: 43, cursor: cur, line: ln, column: co, tok_start: ts, tok_len: tl, tok_line: tln, tok_col: tco }
    }
    if c2 == 124 {
        ts = start0
        tl = 1
        tln = line0
        tco = col0
        return LexStep { kind: 44, cursor: cur, line: ln, column: co, tok_start: ts, tok_len: tl, tok_line: tln, tok_col: tco }
    }
    if c2 == 60 {
        if cur < slen & str_byte(source, cur) == 61 {
            cur = cur + 1
            co = co + 1
            ts = start0
            tl = 2
            tln = line0
            tco = col0
        return LexStep { kind: 49, cursor: cur, line: ln, column: co, tok_start: ts, tok_len: tl, tok_line: tln, tok_col: tco }
        }
        ts = start0
        tl = 1
        tln = line0
        tco = col0
        return LexStep { kind: 47, cursor: cur, line: ln, column: co, tok_start: ts, tok_len: tl, tok_line: tln, tok_col: tco }
    }
    if c2 == 62 {
        if cur < slen & str_byte(source, cur) == 61 {
            cur = cur + 1
            co = co + 1
            ts = start0
            tl = 2
            tln = line0
            tco = col0
        return LexStep { kind: 50, cursor: cur, line: ln, column: co, tok_start: ts, tok_len: tl, tok_line: tln, tok_col: tco }
        }
        ts = start0
        tl = 1
        tln = line0
        tco = col0
        return LexStep { kind: 48, cursor: cur, line: ln, column: co, tok_start: ts, tok_len: tl, tok_line: tln, tok_col: tco }
    }
    if c2 == 61 {
        if cur < slen & str_byte(source, cur) == 61 {
            cur = cur + 1
            co = co + 1
            ts = start0
            tl = 2
            tln = line0
            tco = col0
        return LexStep { kind: 45, cursor: cur, line: ln, column: co, tok_start: ts, tok_len: tl, tok_line: tln, tok_col: tco }
        }
        if cur < slen & str_byte(source, cur) == 62 {
            cur = cur + 1
            co = co + 1
            ts = start0
            tl = 2
            tln = line0
            tco = col0
        return LexStep { kind: 37, cursor: cur, line: ln, column: co, tok_start: ts, tok_len: tl, tok_line: tln, tok_col: tco }
        }
        ts = start0
        tl = 1
        tln = line0
        tco = col0
        return LexStep { kind: 36, cursor: cur, line: ln, column: co, tok_start: ts, tok_len: tl, tok_line: tln, tok_col: tco }
    }

    ts = start0
    tl = 1
    tln = line0
    tco = col0
    return LexStep { kind: 1, cursor: cur, line: ln, column: co, tok_start: ts, tok_len: tl, tok_line: tln, tok_col: tco }
}

func run_lexer_on_source(source: str): void {
    var cur = 0
    var ln = 1
    var co = 1
    var more = 1
    while more == 1 {
        var st = lexer_step(source, cur, ln, co)
        dump_token_line(source, st.kind, st.tok_start, st.tok_len, st.tok_line, st.tok_col)
        cur = st.cursor
        ln = st.line
        co = st.column
        if st.kind == 0 {
            more = 0
        } else {
            if st.kind == 1 {
                more = 0
            } else {
                more = 1
            }
        }
    }
}


#!/usr/bin/env python3
"""
Wrap if/while conditions in parentheses when they use raw relational operators
and do not already start with '(' — required for seed diva-linux-amd64 parsing.
See diri-lang development notes / seed parser quirk.
"""
from __future__ import annotations

import re
import sys
from pathlib import Path

# Relational ops; avoid matching !=, ==, <=, >= via lookarounds where possible.
REL_TOK = re.compile(r"(?<![=!])<=(?![=])|(?<![=!])>=(?![=])|(?<!=)<(?![=])|(?<!=)>(?![=])")


def needs_wrap(cond: str) -> bool:
    c = cond.strip()
    if not c or c.startswith("("):
        return False
    return REL_TOK.search(c) is not None


def wrap_stmt_keyword_line(body: str, kw: str) -> str | None:
    """If body is `indent+kw+cond+{`, return rewritten line."""
    m = re.match(rf"^(\s*){kw}\s+(.+?)\s*\{{\s*$", body)
    if not m:
        return None
    indent, cond = m.group(1), m.group(2)
    if not needs_wrap(cond):
        return None
    return f"{indent}{kw} ({cond}) {{"


def fix_embedded_while_if(line: str) -> str:
    """Handle `... while cond {` and `... if cond {` mid-line (e.g. after var)."""
    out = []
    i = 0
    n = len(line)
    while i < n:
        hit = None
        for kw in ("while", "if"):
            for j in range(i, n - len(kw) - 1):
                if line[j : j + len(kw)] != kw:
                    continue
                if kw == "while" and j > 0 and (line[j - 1].isalnum() or line[j - 1] == "_"):
                    continue
                if kw == "if" and j > 0 and (line[j - 1].isalnum() or line[j - 1] == "_"):
                    continue
                if j > 0 and line[j - 1] not in " \t\n;}{":
                    continue
                after = j + len(kw)
                if after >= n or line[after] not in " \t":
                    continue
                k = after + 1
                while k < n and line[k] in " \t":
                    k += 1
                if k < n and line[k] == "(":
                    break
                brace = line.find("{", k)
                if brace < 0:
                    break
                cond = line[k:brace].strip()
                if not needs_wrap(cond):
                    break
                hit = (j, brace + 1, cond, kw)
                break
            if hit:
                break
        if not hit:
            out.append(line[i])
            i += 1
            continue
        j, br_end, cond, kw = hit
        out.append(line[i:j])
        out.append(kw)
        out.append(" (")
        out.append(cond)
        out.append(") ")
        out.append("{")
        i = br_end
    return "".join(out)


def process_line(line: str) -> str:
    newline = "\n" if line.endswith("\n") else ""
    body = line[:-1] if newline else line

    for kw in ("if", "while"):
        wrapped = wrap_stmt_keyword_line(body, kw)
        if wrapped is not None:
            return wrapped + newline

    body2 = fix_embedded_while_if(body)
    return body2 + newline if body2 != body or newline else line


def process_file(path: Path) -> bool:
    text = path.read_text(encoding="utf-8")
    lines = text.splitlines(keepends=True)
    new_lines = [process_line(ln) for ln in lines]
    new_text = "".join(new_lines)
    if new_text != text:
        path.write_text(new_text, encoding="utf-8")
        return True
    return False


def main() -> int:
    root = Path(__file__).resolve().parents[1]
    changed = 0
    for path in sorted(root.rglob("*.diva")):
        if process_file(path):
            print(path.relative_to(root))
            changed += 1
    print(f"updated {changed} files", file=sys.stderr)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

#!/usr/bin/env python3
"""Emit merged compiler sources in the same dependency order as compiler/src/loader.diva."""
from __future__ import annotations

import os
import re
import sys


def path_join_dir(base: str, rel: str) -> str:
    if not base:
        return rel
    return base + rel if base.endswith("/") else base + "/" + rel


def dirname_of_file(path: str) -> str:
    i = len(path) - 1
    while i >= 0:
        if path[i] == "/":
            return "/" if i == 0 else path[:i]
        i -= 1
    return "."


def resolve_import_path(cur_file: str, imp: str, stdroot: str) -> str:
    if imp.startswith("std/"):
        return path_join_dir(stdroot, imp)
    return path_join_dir(dirname_of_file(cur_file), imp)


def list_resolved_imports(src: str, cur_abs: str, stdroot: str) -> list[str]:
    out: list[str] = []
    for line in src.split("\n"):
        m = re.match(r'^\s*import\s+"([^"]+)"\s*$', line)
        if m:
            out.append(resolve_import_path(cur_abs, m.group(1), stdroot))
    return out


def merge_emit_file(abs_path: str, done: set[str], stack: set[str], stdroot: str, out_parts: list[str]) -> set[str]:
    if abs_path in done:
        return done
    if abs_path in stack:
        raise RuntimeError("import cycle at " + abs_path)
    if not os.path.isfile(abs_path):
        raise RuntimeError("cannot read " + abs_path)
    with open(abs_path, encoding="utf-8") as f:
        src = f.read()
    stack2 = set(stack)
    stack2.add(abs_path)
    done2 = set(done)
    for dep in list_resolved_imports(src, abs_path, stdroot):
        if dep:
            done2 = merge_emit_file(dep, done2, stack2, stdroot, out_parts)
    out_parts.append(src + "\n")
    done2.add(abs_path)
    return done2


def main() -> int:
    root = os.environ.get("ROOT_DIR")
    if not root:
        root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    stdroot = os.environ.get("DI_STDLIB_DIR", os.path.join(root, "stdlib"))
    pkg = os.path.join(root, "compiler")
    ent = os.path.join(pkg, "package.diva")
    if not os.path.isfile(ent):
        print("merge_compiler_package: missing " + ent, file=sys.stderr)
        return 1
    # package_entry_relative: read entry= from package.diva
    text = open(ent, encoding="utf-8").read()
    entry_rel = ""
    for raw in text.split("\n"):
        line = raw.strip()
        if line.startswith("entry"):
            m = re.search(r'entry\s*=\s*"([^"]+)"', line)
            if m:
                entry_rel = m.group(1)
                break
    if not entry_rel:
        print("merge_compiler_package: no entry= in package.diva", file=sys.stderr)
        return 1
    ep = path_join_dir(pkg, entry_rel)
    parts: list[str] = []
    merge_emit_file(ep, set(), set(), stdroot, parts)
    sys.stdout.write("".join(parts))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

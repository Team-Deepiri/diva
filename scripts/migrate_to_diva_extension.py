#!/usr/bin/env python3
"""
Rename Di sources from *.di to *.diva and update text references.

Preserves SDK install paths like ~/.di/bin (directory stays ~/.di).

Run from repository root:
  python3 scripts/migrate_to_diva_extension.py
"""
from __future__ import annotations

import os
import re
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent

SKIP_DIR_NAMES = {".git", "__pycache__", ".cursor", "node_modules", "build"}
SKIP_FILE_NAMES: set[str] = set()
TEXT_SUFFIXES = {
    "",
    ".md",
    ".sh",
    ".yml",
    ".yaml",
    ".json",
    ".mod",
    ".diva",
    ".di",
    ".txt",
    ".xml",
    ".ps1",
    ".c",
    ".h",
}
BINARY_SUFFIXES = {".png", ".jpg", ".jpeg", ".gif", ".webp", ".ico", ".o", ".a", ".so", ".dylib"}


def is_probably_text(path: Path) -> bool:
    suf = path.suffix.lower()
    if suf in BINARY_SUFFIXES:
        return False
    if suf in TEXT_SUFFIXES or path.name in {"Makefile", "LICENSE", "Dockerfile"}:
        return True
    return False


def protect_paths(s: str) -> tuple[str, list[str]]:
    tokens: list[str] = []

    def stash(i: list[int], fragment: str) -> str:
        tokens.append(fragment)
        return f"\x00__DI_SDK_{i[0]}__\x00"

    i = [0]
    out = s
    patterns = [
        "${HOME}/.di/",
        "${HOME}\\.di\\",
        "~/.di/",
        "~/.di\\",
        "%USERPROFILE%\\.di\\",
        '".di\\',  # PowerShell Join-Path $HOME ".di\bin"
        '".di/',  # join ".di/bin" variants
    ]
    for p in patterns:
        while p in out:
            t = stash(i, p)
            out = out.replace(p, t, 1)
    return out, tokens


def restore_paths(s: str, tokens: list[str]) -> str:
    out = s
    for idx, tok in enumerate(tokens):
        out = out.replace(f"\x00__DI_SDK_{idx}__\x00", tok)
    return out


def migrate_content(raw: str) -> str:
    protected, tokens = protect_paths(raw)
    # .di -> .diva but not inside .diva or .dir etc.
    migrated = re.sub(r"\.di(?!va)(?![a-zA-Z0-9_])", ".diva", protected)
    return restore_paths(migrated, tokens)


def collect_di_files(root: Path) -> list[Path]:
    found: list[Path] = []
    for dirpath, dirnames, filenames in os.walk(root):
        dpath = Path(dirpath)
        if ".git" in dpath.parts:
            continue
        dirnames[:] = [d for d in dirnames if d not in SKIP_DIR_NAMES]
        for name in filenames:
            if name.endswith(".di") and not name.endswith(".diva"):
                found.append(dpath / name)
    return sorted(found, key=lambda p: (-len(str(p))))


def main() -> int:
    os.chdir(REPO_ROOT)
    di_files = collect_di_files(REPO_ROOT)
    print(f"Renaming {len(di_files)} *.di -> *.diva")
    for old in di_files:
        new = old.with_suffix(".diva")
        if new.exists():
            print(f"skip (exists): {new}", file=sys.stderr)
            continue
        old.rename(new)
        print(f"  {old.relative_to(REPO_ROOT)} -> {new.name}")

    touched = 0
    for dirpath, dirnames, filenames in os.walk(REPO_ROOT):
        if ".git" in Path(dirpath).parts:
            continue
        dirnames[:] = [d for d in dirnames if d not in SKIP_DIR_NAMES]
        for name in filenames:
            path = Path(dirpath) / name
            if path.name in SKIP_FILE_NAMES:
                continue
            if not is_probably_text(path):
                continue
            try:
                text = path.read_text(encoding="utf-8")
            except (UnicodeDecodeError, OSError):
                continue
            new_text = migrate_content(text)
            if new_text != text:
                path.write_text(new_text, encoding="utf-8")
                touched += 1
                print(f"updated: {path.relative_to(REPO_ROOT)}")

    print(f"Done. Updated {touched} text files.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

#!/usr/bin/env python3
"""
Gas allows one definition per global. `diva asm` on a merged package can emit the same
std/io + std/str helper labels twice; `cc` then fails with "symbol X is already defined".
Keep the first .globl block for each symbol and drop later duplicates.
"""
import sys


def main() -> int:
    if len(sys.argv) != 3:
        print("usage: dedupe_merged_gas.py <in.s> <out.s>", file=sys.stderr)
        return 2
    in_path, out_path = sys.argv[1], sys.argv[2]
    with open(in_path, "r", encoding="utf-8", errors="replace") as f:
        lines = f.readlines()
    seen: set[str] = set()
    out: list[str] = []
    i = 0
    GLOB_PREFIX = "    .globl "
    while i < len(lines):
        line = lines[i]
        if line.startswith(GLOB_PREFIX):
            sym = line[len(GLOB_PREFIX) :].split()[0]
            if sym in seen:
                i += 1
                while i < len(lines) and not lines[i].startswith(GLOB_PREFIX):
                    i += 1
                continue
            seen.add(sym)
        out.append(line)
        i += 1
    with open(out_path, "w", encoding="utf-8") as f:
        f.writelines(out)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

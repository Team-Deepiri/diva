# Native DWARF line tables

`diva build <source> --debug-info` emits DWARF v4 debug sections directly from
the self-hosted compiler's pure-ELF emitter. The flag is off by default, so a
normal build produces the same sectionless ELF as before. When enabled, the
driver prints `[native] DWARF line tables enabled (--debug-info)` on stderr.

## Sections

The debug build adds these non-allocated sections after the load image:

- `.debug_abbrev` — one `DW_TAG_compile_unit` abbreviation.
- `.debug_info` — one compile unit with `DW_AT_name`, `DW_AT_stmt_list`,
  `DW_AT_low_pc`, and `DW_AT_high_pc`.
- `.debug_line` — DWARF v4 line-number program.
- `.shstrtab` — section-header string table.
- `.text` — section header for the executable load segment.

The debug sections and `.shstrtab` have `sh_addralign = 1`; `.text` has
`sh_addralign = 16`. Section headers are 64 bytes each and the header table is
8-byte aligned.

DWARF v4 stores the source file name in the line-program header and in
`.debug_info`; no `.debug_line_str` section is needed. A future move to DWARF v5
would need to add `.debug_line_str` and the v5 directory/file table format.

## Line table scope

The line table contains one sequence covering the emitted machine-code range
from `0x1000` to the end of the generated code. It maps that range to the line
containing `func main` (or `func kmain` for freestanding programs) in the
original source file. The file table contains one entry for that source file.

This is the foundation for issue #114. Full DIE coverage is deferred: there are
no variable or parameter DIEs, no type DIEs, no location expressions, and no
`DW_TAG_inlined_subroutine` entries yet. The existing `diva build -g` path still
uses `scripts/embed-dwarf-debug.py`; `--debug-info` uses the native emitter and
takes precedence when both flags are supplied.

## Verification

`tests/dwarf.sh` builds a tiny program with `--debug-info`, checks the stderr
note, runs the binary, and uses `readelf -S` plus
`readelf --debug-dump=decodedline` to verify that the `.debug_line` section
exists and maps the entry address to the expected source line. If `readelf` is
not installed, the test falls back to a raw section-name check.

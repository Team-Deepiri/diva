# DWARF `-g` (Issue #63)

`diva build <src> -g` builds the usual pure ELF, then runs
`scripts/embed-dwarf-debug.py` to append:

| Section | Role |
|---------|------|
| `.debug_abbrev` | One `DW_TAG_compile_unit` abbrev |
| `.debug_info` | CU covering RX text (`low_pc` / `high_pc`) |
| `.debug_line` | Line program → source path + entry line (`func main` / `func kmain`) |

Requires **python3** on the host (same class of tooling as other bootstrap scripts).

Default builds (no `-g`) are unchanged: **no section headers**, same loadable image.

## Usage

```sh
diva build examples/hello.diva -g
addr2line -e build/diva-native-exe 0x1000
# → examples/hello.diva:<line of func main>
```

Mapping is coarse (whole text → entry line) for MVP; finer rows can land later in-tree.

## Smoke

`tests/run-dwarf-smoke.sh`

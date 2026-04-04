# Diva compiler package (`diva_compiler`)

Installable **app** package (`diva.mod`): builds the **`diva` driver** you get on `PATH` after `./scripts/install.sh`.

## What runs on your machine

| Part | Source | Role |
|------|--------|------|
| **Driver** | `src/main.diva` + `src/lexer.diva` | **Diva-authored** executable: `diva lex <file>` runs the in-Diva lexer; all other subcommands forward to the seed via `host_system`. |
| **Seed** | `bootstrap/diva-linux-amd64` (binary, not C in-tree) | Full pipeline today: parse, sema, codegen, link. Copied to `$XDG_DATA_HOME/diva/bootstrap/` at install. |
| **Wrapper** | emitted by `scripts/install.sh` | Sets `DIVA_BOOTSTRAP` / `DI_BOOTSTRAP` and `exec`s the driver from `$XDG_DATA_HOME/diva/libexec/diva-driver`. Also installs `di` → `diva`. |

There are **no C/C++ sources** in this repository; the seed is a pinned executable. Rebuilding it requires checking out an older commit that still had the C compiler (see `bootstrap/README.md`).

## Subpackages

| Path | Role |
|------|------|
| [`frontend/`](frontend/) | `diva check` entry points at shared [`src/lexer.diva`](../src/lexer.diva). |
| [`mir/`](mir/) | MIR/LIR scaffolding. |
| [`backend/`](backend/) | ELF x86_64 notes and hooks. |

## Commands

- `diva lex path/to/file.diva` — tokenize with the **Diva** lexer (stdout, one line per token via `print_str`).
- `diva compiler-version` — short banner.
- Everything else (`build`, `run`, `check`, …) — forwarded to the seed.

See also: [`docs/selfhost-bootstrap.md`](../docs/selfhost-bootstrap.md), [`docs/frontend-parity-roadmap.md`](../docs/frontend-parity-roadmap.md).

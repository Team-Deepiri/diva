# Diva compiler package (`diva_compiler`)

Installable **app** package (`package.diva`): builds the **`diva` driver** on `PATH` after `./scripts/install.sh`.

## What runs on your machine

| Part | Source | Role |
|------|--------|------|
| **Driver** | `src/main.diva` + pipeline modules | **Diva-authored** executable: `lex`, `parse`, `ir`, `asm`, `emit-ir`, `build`, `run`, `check`, `new` (app/lib) run natively. **`build`/`run`** use pure in-process ELF only (no external linker for user programs). |
| **Seed** | `bootstrap/diva-linux-amd64` (binary only) | Trust root and tooling for promotion and any workflow you run on the seed directly. Copied to `$XDG_DATA_HOME/diva/bootstrap/` at install. |
| **Wrapper** | emitted by `scripts/install.sh` | Sets `DIVA_BOOTSTRAP` / `DI_BOOTSTRAP` and `exec`s `$XDG_DATA_HOME/diva/libexec/diva-driver`. Symlink `di` → `diva`. |

There are **no C/C++ sources** in this repository.

## Pipeline modules (`compiler/src/`)

- `tokens.diva`, `lexer.diva` — token stream  
- `ast.diva`, `parser.diva` — AST  
- `ir.diva`, `ir_builder.diva`, `ir_dump.diva` — Diva IR  
- `codegen_x86.diva` — AT&T assembly text  
- `cell.diva` — mutable cell helper (seed-compatible; no module-level `var`)

## Commands (native in Diva)

- `diva lex <file>` — tokenizer  
- `diva parse <file>` — parse summary  
- `diva ir <file>` — Diva IR dump  
- `diva asm <file>` — x86_64 assembly  
- `diva compiler-version` — banner  
- `diva pipeline` — pipeline description  

Kernel packages (`kind = "kernel"`, entry `kmain`) are supported for `check` / `emit-ir` / `build` / `run` / `watch` — see `docs/kernel-packages.md`.

See: [`docs/selfhost-bootstrap.md`](../docs/selfhost-bootstrap.md), [`docs/source-language-policy.md`](../docs/source-language-policy.md).

# Di compiler package (bootstrap driver)

This package builds to a small hosted executable that forwards CLI invocations to the **seed** compiler binary (`DI_BOOTSTRAP`, default `bootstrap/di-linux-amd64`) via `host_system`.

That gives a **Di-authored** `di` on `PATH` while the real toolchain remains the checked-in bootstrap binary—a practical self-host step until the full compiler is implemented in Di (lexer, parser, sema, IR, codegen).

`tests/run.sh` builds this package with the seed compiler, installs the result as `di`, re-runs the suite (**selfhost**), rebuilds with that `di` (**stage3**), then runs `scripts/verify-no-clang.sh`.

## Subpackages (incremental integration)

| Path | Role |
|------|------|
| [`frontend/`](frontend/) | Token / lexer parity stubs |
| [`mir/`](mir/) | MIR/LIR scaffolding |
| [`backend/`](backend/) | ELF x86_64 backend constants and hooks |

See also: [`docs/frontend-parity-roadmap.md`](../docs/frontend-parity-roadmap.md), [`docs/mir-lir-layer.md`](../docs/mir-lir-layer.md), [`docs/backend-elf64-roadmap.md`](../docs/backend-elf64-roadmap.md).

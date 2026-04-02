# Frontend / semantic parity roadmap

The seed compiler (bootstrap binary) defines the reference behavior exercised by [`tests/run.sh`](../tests/run.sh).

Parity work tracks:

- Lexer/token stream vs [`compiler/frontend/`](../compiler/frontend/)
- Parser + AST vs future `compiler/parser/`
- Semantic analysis vs future `compiler/sema/`
- Diagnostics text and exit codes must match `tests/cases/fail/*` expectations

Gate: `di check` / `di build` on the full example tree using only the Di compiler pipeline (no seed subprocess).

Current repo state: the app entry [`compiler/src/main.di`](../compiler/src/main.di) remains the bootstrap driver; library stubs under `compiler/frontend/`, `compiler/mir/`, and `compiler/backend/` compile independently via `di check <path>` for incremental integration.

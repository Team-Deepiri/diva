# Di compiler package (bootstrap driver)

This package builds to a small hosted executable that forwards CLI invocations to the **seed** compiler binary (`DI_BOOTSTRAP`, default `bootstrap/di-linux-amd64`) via `host_system`.

That gives a **Di-authored** `di` on `PATH` while the real toolchain remains the checked-in bootstrap binary—a practical self-host step until the full compiler is implemented in Di (lexer, parser, sema, IR, codegen).

`tests/run.sh` builds this package with the seed compiler, installs the result as `di`, and re-runs the integration suite.

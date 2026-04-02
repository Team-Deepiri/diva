# Di Tests

Current test coverage lives in `tests/run.sh`.

It currently checks:

- example program integration runs
- AST smoke output for a simple program
- semantic failure cases with expected diagnostics
- generated-project SDK workflow through `di new`

## Run

From the repository root:

```sh
sh tests/run.sh
```

## Test Layout

- `tests/run.sh`: installs `di` into a temporary home and runs the full smoke suite
- `tests/cases/fail/`: negative compilation cases that should fail with known diagnostics

## Next Useful Additions

- token snapshot tests
- richer AST snapshot coverage
- emitted LLVM IR shape checks
- Windows-side install and SDK tests

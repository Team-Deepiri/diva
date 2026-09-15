# Diva Tests

Current coverage:

- `tests/run.sh` — install + integration smoke (examples, scaffolding, fail needles)
- `tests/run-native-broad.sh` — broad native build/run + locked negatives + watch smoke
- `tests/run-negative.sh` — curated fail suite from `tests/negative.list` (Issue #61)
- `tests/run-watch-smoke.sh` — `diva watch` poll + rebuild cycle (Issue #60)
- `tests/run-dwarf-smoke.sh` — `diva build -g` + `addr2line` (Issue #63)
- `tests/run-strict-pure.sh` — strict pure-ELF example list

## Run

From the repository root:

```sh
sh tests/run.sh
sh tests/run-native-broad.sh
sh tests/run-negative.sh
DIVA=bootstrap/diva-linux-amd64 sh tests/run-watch-smoke.sh
DIVA=bootstrap/diva-linux-amd64 sh tests/run-dwarf-smoke.sh
```

## Test Layout

- `tests/cases/fail/`: negative compilation / runtime-abort cases (see `tests/cases/fail/README.md`)
- `tests/negative.list`: path + expected stderr needle + kind (`fail_build` / `runtime_abort`)
- `tests/manual/`: historical scratch programs (not gated)

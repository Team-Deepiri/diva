# `diva watch` — Issue #60

Dependency-aware rebuild loop in the native driver (`compiler/src/main.diva`).

## Behavior

1. Resolve the watch root (`.diva` file or package dir).
2. Collect absolute paths via `collect_watch_files` (transitive `import` graph + `package.diva`).
3. Build once (`native_build_path`).
4. Poll every ~1s (`host_system("sleep 1")`); fingerprint each file (`size` + content hash).
5. On change: debounce one more poll second, rebuild, print errors, **do not exit**.
6. Optional: `DIVA_WATCH_MAX_ITERS=N` stops after N poll cycles (used by `tests/run-watch-smoke.sh`).

## Limits

- Polling, not inotify.
- Stdlib imports are included in the watch set (editing `stdlib/` retriggers).
- Output path follows `diva build` rules (`DIVA_NATIVE_EXE_OUT` / `build/diva-native-exe`).

# Module graph phase 1 (Issue #24)

## Landed in this slice

- **Dep aliases:** inside a package, `import "pkg/math_lib"` (or bare `import "math_lib"`)
  resolves through the enclosing `package.diva` entry `dep.math_lib = "..."`. If the target
  is a package directory, the loader uses that package's `entry=` file.
- Unknown `pkg/<name>` prints `loader: unknown package dependency '…'`.
- Existing path imports (`../x.diva`, `std/...`) unchanged.
- Example: `examples/packages/app_with_dep` uses `import "pkg/math_lib"`.

## Phase 2 (this PR)

- **Package identity:** `name = "…"` in `package.diva` keys cache entries and module-graph edges.
- **Module graph trace:** `DIVA_MODULE_GRAPH=1` prints `module-graph: <from> -> <to>` for each
  `dep.*` edge (see `tests/run-module-cache.sh`).
- **Merge cache:** merged package sources are stored under `.diva/cache/<name>/<fp>.merged`
  (override root with `DIVA_CACHE_DIR`). Fingerprint `fp` hashes manifest + transitive `.diva`
  sources in merge order. Disable with `DIVA_PKG_CACHE=0`. Trace hits/stores with
  `DIVA_PKG_CACHE_TRACE=1`.
- **Visibility (documented):** cross-package access is only via declared `dep.*` + `import "pkg/…"`;
  symbols from dependency packages are merged into the consumer compilation unit (flatten model
  until a multi-module IR graph lands).

## Still deferred

- Replacing source-flatten merge with a true multi-module IR graph
- Per-symbol `pub` visibility enforcement in sema
- Incremental rebuild of cached IR artifacts (today caches merged **source** only)

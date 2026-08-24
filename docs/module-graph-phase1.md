# Module graph phase 1 (Issue #24)

## Landed in this slice

- **Dep aliases:** inside a package, `import "pkg/math_lib"` (or bare `import "math_lib"`)
  resolves through the enclosing `package.diva` entry `dep.math_lib = "..."`. If the target
  is a package directory, the loader uses that package's `entry=` file.
- Unknown `pkg/<name>` prints `loader: unknown package dependency '…'`.
- Existing path imports (`../x.diva`, `std/...`) unchanged.
- Example: `examples/packages/app_with_dep` uses `import "pkg/math_lib"`.

## Still deferred

- Package identity / visibility namespaces
- Compiled package artifact cache and reuse
- Replacing source-flatten merge with a true multi-module IR graph

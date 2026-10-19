# diva test — built-in Diva test runner

`tools/test/diva_test.diva` is a test runner written in Diva (issue #137). It
discovers Diva test files, builds each one with the compiler driver, runs the
resulting native binary, and reports one `OK`/`FAIL` line per file plus a final
summary. It is itself a normal Diva program: no shell harness, no JSON, no
external tooling beyond `find`/`sort` for directory discovery.

## Build

```sh
export DI_STDLIB_DIR="$PWD/stdlib"
export DIVA_NO_EXTERNAL=1
export DI_RUNTIME_O="$PWD/bootstrap/runtime-linux-amd64.o"
build/diva-compiler-pure-elf build tools/test/diva_test.diva "$PWD/diva-test"
```

The runner inherits its environment when it invokes the driver, so
`DI_STDLIB_DIR` / `DIVA_NO_EXTERNAL` / `DI_RUNTIME_O` must be set in the
environment that runs `diva-test` (as above) for test builds to produce native
ELF binaries.

## Usage

```sh
diva-test <path>...                 # run a file or a directory (or several)
diva-test tools/test/examples       # run the checked-in example tests
diva-test --list tests              # discover only
diva-test --filter str --list .     # narrow discovery
```

| Flag | Meaning |
| --- | --- |
| `--driver <path>` | Compiler driver to invoke. Default `build/diva-compiler-pure-elf`, resolved relative to the current directory. |
| `--filter <substr>` | Only run test files whose path contains `<substr>`. |
| `--list` | Discover and print matching test files (one absolute-or-as-given path per line) without building or running them. |
| `--verbose` | Print the exact build/run shell commands and build output. Diagnostics go to **stderr**; stdout stays the machine-readable stream. |
| `--help` | Print usage. |

Flags may appear before or after paths. Paths beginning with `--` are treated as
flags, so prefix such a path with `./`.

## Discovery rules

* A **directory** argument is searched **recursively** for regular files whose
  basename matches either `*_test.diva` **or** `test_*.diva`. `.git` directories
  are pruned; results are sorted and de-duplicated.
* A **file** argument is always run, even if its name matches neither pattern.
* A non-existent path is a usage error (exit 2).
* Discovery is implemented with `find`/`sort` because Diva has no `readdir`
  builtin; the result is written to a temporary list file and read back with
  `read_file`.

## Output

For every file the runner prints a `--- <path>` header, then the test binary's
stdout+stderr, then a result line:

```
--- tools/test/examples/math_test.diva
  test abs ... ok
  ...

4 tests, 4 passed, 0 failed
OK tools/test/examples/math_test.diva
```

A failing file prints the failure text and a `FAIL` line with the child's exit
status (`(exit N)` for a failed run, `(build exit N)` when the driver could not
build the file). After all files:

```
3 passed, 1 failed, 4 files
```

`passed + failed == files`; `--list` prints only paths (no summary). Build
errors, `--verbose` diagnostics and usage messages go to stderr.

## Exit codes

| Code | Meaning |
| --- | --- |
| `0` | Every test file passed (also `--list` / `--help`). |
| `1` | At least one test file failed (build or run). |
| `2` | Usage error: unknown flag, missing flag value, no paths, or a path that does not exist. |

## How child exit codes are captured

`host_system(cmd)` returns the raw `wait(2)` status of the `/bin/sh` it spawns,
not a clean exit code, and for a compound command it returns the status of the
**last** command in the chain. Measured on this platform:

| Command | `host_system` return |
| --- | --- |
| `exit 3` | `768` (`3 << 8`) |
| `false` | `256` (`1 << 8`) |
| `sh -c 'kill -ABRT $$'` | `34304` (`134 << 8`) |

Because the runner also has to redirect the child's output (there is no
output-capture builtin — output would otherwise stream straight through to the
runner's stdout), it does **not** interpret `host_system`'s return value. Each
build and each run is executed as:

```sh
ulimit -c 0 2>/dev/null; { <cmd> ; } > <workdir>/x.out 2>&1; echo $? > <workdir>/x.rc
```

The integer in the sentinel `x.rc` file is then read back with `read_file()` and
parsed. `echo $?` yields the shell's own exit status for `<cmd>` — uniformly,
including `128 + signal` for a signal death — and the group redirect captures
the child's stdout, stderr and the shell's `Aborted (core dumped)` job message.
`ulimit -c 0` disables core dumps so a crashing test cannot litter the working
directory.

Temporary build/run files live in `${TMPDIR:-/tmp}/diva-test.$$.d` (removed on
exit); the runner's shell PID is handed back through a small pointer file,
`${TMPDIR:-/tmp}/diva-test-workdir`, because Diva has no `getpid` builtin.

## Writing a test

A test file is an ordinary Diva program with a `main` that returns `0` on
success and non-zero on failure. `std/testing.diva` provides the harness:

```diva
import "std/io.diva"
import "std/testing.diva"

func main(): int {
    test_begin("addition")
    assert_eq_int(2 + 2, 4, "2+2 should be 4")
    test_ok()

    return test_summary()   // 0 when nothing failed, 1 otherwise
}
```

`assert_*` abort the process on failure, and `test_summary()` returns non-zero
if any `test_fail` was recorded. Either way the runner sees a non-zero exit and
marks the file `FAIL`. See `tools/test/examples/` (`math_test.diva`,
`str_test.diva`, `path_test.diva`) for working examples.

## Integration test

`tools/test/diva_test_test.sh` builds the runner, generates passing, failing,
nested, `test_*`-named, non-test and unbuildable fixtures, and asserts
discovery, `--list`, `--filter`, summary counts and exit codes:

```sh
sh tools/test/diva_test_test.sh
# ...
# [diva-test] total=27 failed=0
```

## CI integration

```yaml
name: diva-test
on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Configure
        run: |
          echo "DI_STDLIB_DIR=$PWD/stdlib"       >> "$GITHUB_ENV"
          echo "DIVA_NO_EXTERNAL=1"              >> "$GITHUB_ENV"
          echo "DI_RUNTIME_O=$PWD/bootstrap/runtime-linux-amd64.o" >> "$GITHUB_ENV"
      - name: Build runner
        run: build/diva-compiler-pure-elf build tools/test/diva_test.diva "$PWD/diva-test"
      - name: Run test suite
        run: ./diva-test tools/test/examples
      - name: Runner self-test
        run: sh tools/test/diva_test_test.sh
```

Any Diva repo can drop in the runner the same way; point it at a directory of
`*_test.diva` files.

## Limitations

* Discovery shells out to `find` and `sort` (no `readdir` builtin); simple POSIX
  `find` is required.
* Paths are single-quoted through `sh_quote` (double quotes) — paths containing
  `"` or `$` are not supported.
* Only one `diva-test` process should run per `${TMPDIR}` at a time: the work
  directory pointer file (`diva-test-workdir`) has a fixed name.
* There is no per-test timeout; a hanging test file will hang the runner. Wrap
  the invocation (e.g. with `timeout`) in CI if needed.

# Diva standard library additions (Issue #127)

This document covers the hosted standard-library modules added by issue #127.
All APIs live in `stdlib/std/` and are usable with `import "std/<name>.diva"`.

## `sync.diva`

```diva
lock_init(lock: *int): void
lock_acquire(lock: *int): void
lock_release(lock: *int): void
```

A spinlock is one caller-owned 64-bit word. `lock_init` stores 0,
`lock_acquire` loops on `atomic_cas(lock, 0, 1)`, and `lock_release` stores 0.
The `unsafe` blocks are contained in the module.

**Limitations:** Diva has no thread scheduler yet. These functions are tested
for single-threaded acquire/release sequences; `lock_acquire` spins forever if
the word is already held by a thread that cannot make progress. There is no
fairness, recursion, timeout, condvar, or deadlock detection. Pass the same
word to every call; copying it while held does not transfer ownership.

## `time.diva`

```diva
now_ns(): int
sleep_ms(ms: int): int
sleep_seconds(seconds: int): int
```

`now_ns` returns `CLOCK_MONOTONIC` nanoseconds as a 64-bit int. `sleep_ms`
returns 0 on success and -1 on syscall error; non-positive `ms` returns 0.
`EINTR` is retried with the original request.

**Runtime dependency:** `now_ns` / `sleep_ms` wrap the extern builtins
`host_now_ns()` and `host_sleep_ms()`. The self-hosted x86-64 ELF backend
implements them directly with `clock_gettime` (syscall 228) and `nanosleep`
(syscall 35) in `compiler/src/pure_elf_builtins.diva` (ids 44 and 45), so
`DIVA_NO_EXTERNAL=1` builds need no libc. Other backends must supply those
symbols or the build reports an unresolved extern. The monotonic clock is
Linux-specific; wall-clock conversion and calendar dates are deferred.

## `fs.diva`

```diva
file_read(path: str): str
file_write(path: str, data: str): int
```

Thin, consistently named wrappers over the existing hosted helpers `read_file`
and `write_text_file`. `file_write` truncates and returns 0 on success / 1 on
failure; `file_read` returns `""` when the file cannot be read. Existing
`fs_read_text` / `write_text_str` / `file_len` / `exists` names are unchanged.

**Gaps:** text bytes only (embedded NUL is not representable), no append mode,
no directory iteration, no atomic rename, and no structured error values.

## `process.diva`

```diva
getenv(name: str): str
process_exit(code: int): void
```

`getenv` returns `""` for an unset variable. `process_exit` wraps the `exit`
builtin; `exit(code)` itself is declared in `std/io.diva`, so it is not
re-declared here (a second declaration would collide when both modules are
imported). Existing `getenv_or`, `require_env`, `exit_with`, `exec`, and `argv`
helpers are unchanged.

**Gaps:** no `setenv`, no argument-vector mutation, no child-process object;
`exec` still uses the hosted `system` wrapper.

## `fmt.diva`

```diva
itoa(n: int): str
concat(a: str, b: str): str
format(template: str, value: str): str
```

`itoa` is decimal integer conversion. `concat` joins two strings. `format`
replaces every `{}` placeholder in `template` with the same `value`; unmatched
braces and text are copied verbatim.

**Gaps:** no format specs, escaping, positional/named placeholders, or
multi-value formatting — use repeated `concat` / `format` calls for now.
Existing `fmt_int` / `fmt_str` / `fmt_bool` / `join` / `pad_left` / `pad_right`
names are unchanged.

## Tests

```sh
sh tests/stdlib.sh
```

The suite builds a fresh driver from the pinned bootstrap seed unless
`DIVA_PURE_DRIVER` is set, then checks spinlock sequencing, itoa/concat/format,
file write+read, getenv and process exit, clock/sleep behavior, and all five
modules imported together.

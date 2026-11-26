# Minimal HTTP/1.1 server in pure Diva (issue #126)

This is a **foundation**, not a production-grade server. It proves an end-to-end
HTTP/1.1 request/response round-trip using only Diva source and Linux syscalls.

## What is implemented

- `stdlib/std/net.diva`: thin Linux x86-64 wrappers over a raw-syscall host
  builtin — `socket` (41), `bind` (49), `listen` (50), `accept` (43), `recv` (45,
  `recvfrom` with a null peer), `send` (44, `sendto` with a null peer), `close`
  (3), plus `getsockname` (51) for ephemeral-port discovery. Helpers build and
  read `sockaddr_in` via `mem_alloc`/`mem_get`/`mem_set`, and `recv_text` stores
  a received byte buffer in a text descriptor usable by `text_len`/`text_byte`.
- `stdlib/std/http.diva`: request parser exposing method, path, and header byte
  ranges (`http_parse`, `http_method_is`, `http_path_is`, `http_header_is`), and
  a response builder with `HTTP/1.1 200 OK`, `Content-Length`, `Content-Type`,
  and `Connection: close` (`http_ok`, `http_not_found`).
- `examples/http_server.diva`: accepts connections sequentially and returns a
  fixed `200` body for `/` and `/hello`, and `404` for other paths. `HTTP_PORT`
  selects the listen port (`0` = kernel-assigned, printed on stdout as the
  first line) and `HTTP_MAX_REQUESTS` bounds the loop for tests.
- `tests/http.sh`: builds the compiler + example, starts the server on an
  ephemeral port, sends requests with curl (or bash `/dev/tcp`), checks status
  and body for 200 and 404, then waits for shutdown. All external operations
  use `timeout`.
- New pure-ELF   builtin `host_syscall(nr, a1, a2, a3, a4)` (id 46 in
  `compiler/src/pure_elf_builtins.diva`, declared in `stdlib/std/net.diva`).
  It emits 17 inline bytes: `mov %rdi,%rax; mov %rsi,%rdi; mov %rdx,%rsi;
  mov %rcx,%rdx; mov %r8,%r10; syscall`. Pointers may be passed as `int`
  arguments. There is no C/C++ source and no libc call on this path.

## Build and run

```sh
DI_STDLIB_DIR=$PWD/stdlib DIVA_NO_EXTERNAL=1 \
DI_RUNTIME_O=$PWD/bootstrap/runtime-linux-amd64.o \
./bootstrap/diva-linux-amd64 build "$PWD/compiler" /tmp/opencode/drv-http

DI_STDLIB_DIR=$PWD/stdlib DIVA_NO_EXTERNAL=1 \
DI_RUNTIME_O=$PWD/bootstrap/runtime-linux-amd64.o \
/tmp/opencode/drv-http build "$PWD/examples/http_server.diva" /tmp/opencode/http-server

HTTP_PORT=0 HTTP_MAX_REQUESTS=2 /tmp/opencode/http-server
```

Then connect to the port printed on the first stdout line. Run the end-to-end
test with `DIVA_PURE_DRIVER=/tmp/opencode/drv-http bash tests/http.sh`.

## Limitations (explicitly deferred)

- Single-threaded: one `accept`/`recv`/`send`/`close` cycle at a time, no
  worker pool or event loop.
- One request per connection; `Connection: close` is sent but the server does
  not support keep-alive or pipelining.
- No TLS, no HTTP/2, no chunked transfer encoding, no request-body decoding.
- Header matching is case-sensitive and only exact header values are exposed;
  no folding, duplicates policy, or cookie parsing.
- A response is sent with a single `send`; partial writes are not retried.
- No accept/read/write timeouts, no graceful drain, and no backpressure.
- The text descriptor used for received bytes has no UTF-8 validation; bytes
  are treated as ASCII/raw octets for method/path/header comparisons.
- Only Linux x86-64 raw syscall numbers are implemented.

These gaps are why this foundation must not be described as production-ready.

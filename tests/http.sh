#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "${ROOT_DIR}"

WORK=$(mktemp -d "${TMPDIR:-/tmp}/diva-http-XXXXXX")
SERVER_PID=""
cleanup() {
    if [ -n "${SERVER_PID}" ]; then
        kill "${SERVER_PID}" 2>/dev/null || true
        wait "${SERVER_PID}" 2>/dev/null || true
    fi
    rm -rf "${WORK}"
}
trap cleanup EXIT INT TERM

fail() {
    printf '[http] FAIL %s\n' "$1" >&2
    exit 1
}

if ! command -v timeout >/dev/null 2>&1; then
    fail "timeout is required so CI cannot hang"
fi

DRIVER="${DIVA_PURE_DRIVER:-}"
if [ -z "${DRIVER}" ] || [ ! -x "${DRIVER}" ]; then
    DRIVER="${WORK}/driver"
    printf '[http] building driver from bootstrap seed\n'
    if ! ROOT_DIR="${ROOT_DIR}" DI_STDLIB_DIR="${ROOT_DIR}/stdlib" DIVA_NO_EXTERNAL=1 \
         DI_RUNTIME_O="${ROOT_DIR}/bootstrap/runtime-linux-amd64.o" \
         timeout 1800 "${ROOT_DIR}/bootstrap/diva-linux-amd64" build "${ROOT_DIR}/compiler" "${DRIVER}" \
         >"${WORK}/driver-build.log" 2>&1; then
        sed -n '1,60p' "${WORK}/driver-build.log" >&2
        fail "driver build failed"
    fi
fi

if ! DI_STDLIB_DIR="${ROOT_DIR}/stdlib" DIVA_NO_EXTERNAL=1 \
     DI_RUNTIME_O="${ROOT_DIR}/bootstrap/runtime-linux-amd64.o" DIVA_NO_CACHE=1 \
     timeout 300 "${DRIVER}" build "${ROOT_DIR}/examples/http_server.diva" "${WORK}/http-server" \
     >"${WORK}/server-build.log" 2>&1; then
    sed -n '1,60p' "${WORK}/server-build.log" >&2
    fail "http_server build failed"
fi

: >"${WORK}/server.out"
HTTP_PORT=0 HTTP_MAX_REQUESTS=2 timeout 25 "${WORK}/http-server" >"${WORK}/server.out" 2>&1 &
SERVER_PID=$!

PORT=""
for _ in $(seq 1 60); do
    PORT=$(grep -E '^[0-9]+$' "${WORK}/server.out" | head -n 1 || true)
    if [ -n "${PORT}" ]; then
        break
    fi
    if ! kill -0 "${SERVER_PID}" 2>/dev/null; then
        break
    fi
    sleep 0.1
done
if [ -z "${PORT}" ]; then
    sed -n '1,60p' "${WORK}/server.out" >&2
    fail "server did not report an ephemeral port"
fi
printf '[http] server port=%s\n' "${PORT}"

request() {
    _path=$1
    _out=$2
    if command -v curl >/dev/null 2>&1; then
        timeout 10 curl --noproxy '*' -sS -i --max-time 5 \
            "http://127.0.0.1:${PORT}${_path}" >"${_out}"
    else
        timeout 10 bash -c '
            exec 3<>/dev/tcp/127.0.0.1/"$1"
            printf "GET %s HTTP/1.1\r\nHost: localhost\r\nConnection: close\r\n\r\n" "$2" >&3
            timeout 5 cat <&3
        ' _ "${PORT}" "${_path}" >"${_out}"
    fi
}

check_response() {
    _path=$1
    _status=$2
    _body=$3
    _file="${WORK}/response-${RANDOM}.txt"
    request "${_path}" "${_file}"
    tr -d '\r' <"${_file}" >"${_file}.clean"
    grep -Fq "${_status}" "${_file}.clean" || fail "${_path}: missing status ${_status}"
    grep -Fq 'Content-Length:' "${_file}.clean" || fail "${_path}: missing Content-Length"
    grep -Fq 'Content-Type: text/plain; charset=utf-8' "${_file}.clean" || fail "${_path}: missing Content-Type"
    grep -Fq 'Connection: close' "${_file}.clean" || fail "${_path}: missing Connection: close"
    grep -Fxq "${_body}" "${_file}.clean" || fail "${_path}: unexpected body"
}

check_response '/hello' 'HTTP/1.1 200 OK' 'hello from diva'
check_response '/nope' 'HTTP/1.1 404 Not Found' '404 not found'

for _ in $(seq 1 100); do
    if ! kill -0 "${SERVER_PID}" 2>/dev/null; then
        break
    fi
    sleep 0.1
done
set +e
wait "${SERVER_PID}"
_server_rc=$?
set -e
if [ "${_server_rc}" -ne 0 ]; then
    sed -n '1,60p' "${WORK}/server.out" >&2
    fail "server exited with ${_server_rc}"
fi
SERVER_PID=""

printf '[http] all HTTP checks passed\n'

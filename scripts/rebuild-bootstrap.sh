#!/usr/bin/env sh
# Maintainer-only: rebuild bootstrap/di-linux-amd64 when you have a C reference compiler
# checkout (not stored in this repository). Requires gcc or clang and all .c/.h sources.
set -eu
echo "This script is a placeholder: copy the reference compiler sources from your" >&2
echo "private checkout or release tarball, then compile with:" >&2
echo "  cc -std=c11 -O2 -D_POSIX_C_SOURCE=200809L -Iinclude ... src/*.c -o bootstrap/di-linux-amd64" >&2
exit 1

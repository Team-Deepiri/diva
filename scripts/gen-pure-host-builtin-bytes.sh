#!/usr/bin/env sh
# Extract .text bytes from a gas file and print int_vec_push lines for pure_elf_builtins.diva / codegen.
# Usage (repo root):
#   sh scripts/gen-pure-host-builtin-bytes.sh compiler/res/pure_write_elf_chunk.s
set -eu

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
SRC=${1:?"usage: $0 <file.s>"}

WORKDIR=$(mktemp -d "${TMPDIR:-/tmp}/diva-builtin-bytes.XXXXXX")
trap 'rm -rf "${WORKDIR}"' EXIT

OBJ="${WORKDIR}/blob.o"
BIN="${WORKDIR}/text.bin"

if ! as --64 -o "${OBJ}" "${SRC}"; then
  echo "gen-pure-host-builtin-bytes: as failed for ${SRC}" >&2
  exit 1
fi

if ! objcopy -O binary -j .text "${OBJ}" "${BIN}"; then
  echo "gen-pure-host-builtin-bytes: objcopy failed (need a .text section)" >&2
  exit 1
fi

python3 -c '
import sys
path = sys.argv[1]
b = open(path, "rb").read()
n = len(b)
print("// .text length =", n, "bytes")
for i in range(0, n, 10):
    chunk = b[i : i + 10]
    parts = ["int_vec_push(out, " + str(x) + ")" for x in chunk]
    print("    " + " ".join(parts))
' "${BIN}"

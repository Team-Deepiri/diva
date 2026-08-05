#!/usr/bin/env sh
# Smoke-test pure handle-table int_vec grow (mremap MAYMOVE) outside the compiler.
# Assembles compiler/res/pure_int_vec_*.s with a trailing ret and pushes 200k elems.
set -eu
ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
WORKDIR=$(mktemp -d "${TMPDIR:-/tmp}/diva-grow-smoke.XXXXXX")
trap 'rm -rf "${WORKDIR}"' EXIT

for name in int_vec_new int_vec_push int_vec_len int_vec_get int_vec_free; do
  python3 - "$ROOT_DIR/compiler/res/pure_${name}.s" "$WORKDIR/${name}.s" "$name" <<'PY'
import sys
from pathlib import Path
src = Path(sys.argv[1]).read_text()
name = sys.argv[3]
src = src.replace(f"pure_{name}", f"smoke_{name}")
idx = src.rfind("\tnop\n.size")
if idx < 0:
    raise SystemExit(f"missing trailing nop in {sys.argv[1]}")
src = src[:idx] + "\tret\n.size" + src[idx + len("\tnop\n.size") :]
Path(sys.argv[2]).write_text(src)
PY
  as --64 -o "${WORKDIR}/smoke_${name}.o" "${WORKDIR}/${name}.s"
done

cat >"${WORKDIR}/main.c" <<'EOF'
#include <stdio.h>
#include <stdint.h>
extern int64_t smoke_int_vec_new(void);
extern int64_t smoke_int_vec_push(int64_t h, int64_t v);
extern int64_t smoke_int_vec_len(int64_t h);
extern int64_t smoke_int_vec_get(int64_t h, int64_t i);
extern void smoke_int_vec_free(int64_t h);
int main(void) {
  int64_t h = smoke_int_vec_new();
  if (h == 0) { fprintf(stderr, "new failed\n"); return 1; }
  for (int64_t i = 0; i < 200000; i++) smoke_int_vec_push(h, i);
  if (smoke_int_vec_len(h) != 200000) return 2;
  if (smoke_int_vec_get(h, 12345) != 12345) return 3;
  smoke_int_vec_free(h);
  puts("grow_smoke_ok");
  return 0;
}
EOF

cc -o "${WORKDIR}/grow_smoke" "${WORKDIR}/main.c" "${WORKDIR}"/smoke_int_vec_*.o -no-pie
"${WORKDIR}/grow_smoke"

#!/usr/bin/env bash
# #112 tensor type

set -u

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "${ROOT_DIR}"

WORK="$(mktemp -d "${TMPDIR:-/tmp}/diva-tensor.XXXXXX")"
trap 'rm -rf "${WORK}"' EXIT

if [ -n "${DIVA_PURE_DRIVER:-}" ] && [ -x "${DIVA_PURE_DRIVER}" ]; then
  DRIVER="${DIVA_PURE_DRIVER}"
else
  DRIVER="${WORK}/driver"
  echo "[tensor] building driver from bootstrap seed"
  if ! ROOT_DIR="${ROOT_DIR}" DI_STDLIB_DIR="${ROOT_DIR}/stdlib" DIVA_NO_EXTERNAL=1 \
       DI_RUNTIME_O="${ROOT_DIR}/bootstrap/runtime-linux-amd64.o" \
       timeout 900 "${ROOT_DIR}/bootstrap/diva-linux-amd64" build compiler "${DRIVER}" \
       >"${WORK}/driver-build.log" 2>&1; then
    sed -n '1,40p' "${WORK}/driver-build.log" >&2
    echo "[tensor] driver build failed" >&2
    exit 1
  fi
fi

echo "[tensor] DRIVER=${DRIVER}"

total=0
failed=0
fail() {
  failed=$((failed + 1))
  echo "[tensor] FAIL $1" >&2
}

build() {
  if ! DI_STDLIB_DIR="${ROOT_DIR}/stdlib" DIVA_NO_EXTERNAL=1 \
       DI_RUNTIME_O="${ROOT_DIR}/bootstrap/runtime-linux-amd64.o" \
       timeout 120 "${DRIVER}" build "$1" "$2" >"${WORK}/build.log" 2>&1; then
    sed -n '1,40p' "${WORK}/build.log" >&2
    return 1
  fi
  return 0
}

check_case() {
  name=$1
  src=$2
  want=$3
  total=$((total + 1))
  exe="${WORK}/${name}.exe"
  if ! build "${src}" "${exe}"; then
    fail "${name} (build)"
    return 0
  fi
  out=$(timeout 60 "${exe}" </dev/null 2>&1) || true
  if [ "$out" != "$want" ]; then
    fail "${name} (output)"
    printf '[tensor] expected:\n%s\n[tensor] actual:\n%s\n' "$want" "$out" >&2
    return 0
  fi
  echo "[tensor] OK ${name}"
}

check_trap() {
  name=$1
  src=$2
  want=$3
  total=$((total + 1))
  exe="${WORK}/${name}.exe"
  if ! build "${src}" "${exe}"; then
    fail "${name} (build)"
    return 0
  fi
  out=$(timeout 60 "${exe}" </dev/null 2>&1)
  rc=$?
  if [ "${rc}" != 1 ]; then
    fail "${name} (expected rc=1 got=${rc})"
    return 0
  fi
  if [ "$out" != "$want" ]; then
    fail "${name} (trap message)"
    printf '[tensor] expected:\n%s\n[tensor] actual:\n%s\n' "$want" "$out" >&2
    return 0
  fi
  echo "[tensor] OK ${name}"
}

check_build_error() {
  name=$1
  src=$2
  needle=$3
  total=$((total + 1))
  if build "${src}" "${WORK}/${name}.exe"; then
    fail "${name} (expected build failure)"
    return 0
  fi
  if ! grep -F "${needle}" "${WORK}/build.log" >/dev/null; then
    fail "${name} (expected error: ${needle})"
    sed -n '1,40p' "${WORK}/build.log" >&2
    return 0
  fi
  echo "[tensor] OK ${name}"
}

cat > "${WORK}/rank1.diva" <<'DIV'
import "std/io.diva"

func main(): int {
    var t: tensor<int, 3> = tensor_fill(7, 3)
    print_int(tensor_len(t))
    print_int(tensor_rank(t))
    print_int(tensor_get(t, 0))
    tensor_set(t, 2, 9)
    print_int(tensor_get(t, 2))
    return 0
}
DIV
check_case rank1 "${WORK}/rank1.diva" $'3\n1\n7\n9'

cat > "${WORK}/rank2.diva" <<'DIV'
import "std/io.diva"

func main(): int {
    var t: tensor<int, 2, 3> = tensor_new(2, 3)
    print_int(tensor_len(t))
    print_int(tensor_rank(t))
    tensor_set(t, 0, 0, 1)
    tensor_set(t, 0, 1, 2)
    tensor_set(t, 0, 2, 3)
    tensor_set(t, 1, 0, 4)
    tensor_set(t, 1, 1, 5)
    tensor_set(t, 1, 2, 6)
    print_int(tensor_get(t, 1, 2))
    return 0
}
DIV
check_case rank2 "${WORK}/rank2.diva" $'6\n2\n6'

cat > "${WORK}/device.diva" <<'DIV'
import "std/io.diva"

func main(): int {
    var cpu: tensor<int, 2> @cpu = tensor_new(2)
    var gpu: tensor<int, 2> @gpu = tensor_new(2)
    print_int(tensor_len(cpu))
    print_int(tensor_len(gpu))
    return 0
}
DIV
check_case device "${WORK}/device.diva" $'2\n2'

cat > "${WORK}/bad_device.diva" <<'DIV'
import "std/io.diva"

func main(): int {
    var t: tensor<int, 2> @tpu = tensor_new(2)
    return 0
}
DIV
check_build_error bad_device "${WORK}/bad_device.diva" "tensor device must be cpu or gpu"

cat > "${WORK}/bad_rank.diva" <<'DIV'
import "std/io.diva"

func main(): int {
    var t: tensor<int, 2, 2> = tensor_new(2)
    return 0
}
DIV
check_build_error bad_rank "${WORK}/bad_rank.diva" "tensor shape rank mismatch in declaration of 't'"

cat > "${WORK}/bad_shape.diva" <<'DIV'
import "std/io.diva"

func main(): int {
    var t: tensor<int, 2> = tensor_new(0)
    return 0
}
DIV
check_trap bad_shape "${WORK}/bad_shape.diva" "tensor: shape dimensions must be positive"

cat > "${WORK}/bad_get.diva" <<'DIV'
import "std/io.diva"

func main(): int {
    var t: tensor<int, 2> = tensor_new(2)
    return tensor_get(t, 2)
}
DIV
check_trap bad_get "${WORK}/bad_get.diva" "tensor_get: index out of bounds"

cat > "${WORK}/bad_set.diva" <<'DIV'
import "std/io.diva"

func main(): int {
    var t: tensor<int, 2, 2> = tensor_new(2, 2)
    tensor_set(t, 2, 0, 1)
    return 0
}
DIV
check_trap bad_set "${WORK}/bad_set.diva" "tensor_set: index out of bounds"

printf '[tensor] %d/%d passed\n' "$((total - failed))" "$total"
if [ "${failed}" != 0 ]; then
  exit 1
fi

#!/usr/bin/env bash
set -u

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "${ROOT_DIR}"

WORK="$(mktemp -d "${TMPDIR:-/tmp}/diva-tensorlib.XXXXXX")"
trap 'rm -rf "${WORK}"' EXIT

if [ -n "${DIVA_PURE_DRIVER:-}" ] && [ -x "${DIVA_PURE_DRIVER}" ]; then
  DRIVER="${DIVA_PURE_DRIVER}"
else
  DRIVER="${WORK}/driver"
  echo "[tensorlib] building driver from bootstrap seed"
  if ! ROOT_DIR="${ROOT_DIR}" DI_STDLIB_DIR="${ROOT_DIR}/stdlib" DIVA_NO_EXTERNAL=1 \
       DI_RUNTIME_O="${ROOT_DIR}/bootstrap/runtime-linux-amd64.o" \
       timeout 900 "${ROOT_DIR}/bootstrap/diva-linux-amd64" build compiler "${DRIVER}" \
       >"${WORK}/driver-build.log" 2>&1; then
    sed -n '1,40p' "${WORK}/driver-build.log" >&2
    echo "[tensorlib] driver build failed" >&2
    exit 1
  fi
fi

echo "[tensorlib] DRIVER=${DRIVER}"

total=0
failed=0
fail() {
  failed=$((failed + 1))
  echo "[tensorlib] FAIL $1" >&2
}

run_env() {
  DI_STDLIB_DIR="${ROOT_DIR}/stdlib" DIVA_NO_EXTERNAL=1 \
    DI_RUNTIME_O="${ROOT_DIR}/bootstrap/runtime-linux-amd64.o" "$@"
}

build() {
  if ! run_env timeout 120 "${DRIVER}" build "$1" "$2" >"${WORK}/build.log" 2>&1; then
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
    printf '[tensorlib] expected:\n%s\n[tensorlib] actual:\n%s\n' "$want" "$out" >&2
    return 0
  fi
  echo "[tensorlib] OK ${name}"
}

check_exit() {
  name=$1
  src=$2
  want_rc=$3
  total=$((total + 1))
  exe="${WORK}/${name}.exe"
  if ! build "${src}" "${exe}"; then
    fail "${name} (build)"
    return 0
  fi
  out=$(timeout 60 "${exe}" </dev/null 2>&1)
  rc=$?
  if [ "${rc}" != "${want_rc}" ]; then
    fail "${name} (exit ${rc}, want ${want_rc})"
    return 0
  fi
  if [ -n "$out" ]; then
    fail "${name} (unexpected output: ${out})"
    return 0
  fi
  echo "[tensorlib] OK ${name} (exit ${want_rc})"
}

check_ir() {
  name=$1
  src=$2
  needle=$3
  total=$((total + 1))
  if ! run_env timeout 60 "${DRIVER}" emit-ir "${src}" >"${WORK}/${name}.ir" 2>"${WORK}/${name}.ir.err"; then
    fail "${name} (emit-ir)"
    sed -n '1,40p' "${WORK}/${name}.ir.err" >&2
    return 0
  fi
  if ! grep -F -- "${needle}" "${WORK}/${name}.ir" >/dev/null; then
    fail "${name} (missing IR '${needle}')"
    return 0
  fi
  echo "[tensorlib] OK ${name} (ir)"
}

cat > "${WORK}/constructors.diva" <<'DIV'
import "std/io.diva"
import "std/tensor.diva"

func main(): int {
    var z: tensor<int, 2, 2> = tensor_zeros(2, 2)
    print_int(tensor_get(z, 0, 0))
    print_int(tensor_get(z, 1, 1))
    var z6: tensor<int, 6> = tensor_zeros6(6)
    print_int(tensor_get(z6, 3))
    var v4: tensor<int, 4> = tensor_from_array4(1, 2, 3, 4)
    var w4: tensor<int, 4> = tensor_from_array4(10, 20, 30, 40)
    print_int(tensor_get(v4, 3))
    print_int(tensor_get(w4, 0))
    var v6: tensor<int, 6> = tensor_from_array6(1, 2, 3, 4, 5, 6)
    var w6: tensor<int, 6> = tensor_from_array6(10, 20, 30, 40, 50, 60)
    print_int(tensor_get(v6, 5))
    print_int(tensor_get(w6, 4))
    var eye: tensor<int, 2, 2> = tensor_eye(2)
    print_int(tensor_get(eye, 0, 0))
    print_int(tensor_get(eye, 0, 1))
    print_int(tensor_get(eye, 1, 0))
    print_int(tensor_get(eye, 1, 1))
    return 0
}
DIV
check_case constructors "${WORK}/constructors.diva" $'0\n0\n0\n4\n10\n6\n50\n1\n0\n0\n1'

cat > "${WORK}/transpose.diva" <<'DIV'
import "std/io.diva"
import "std/tensor.diva"

func main(): int {
    var a: tensor<int, 2, 2> = tensor_from_array2x2(1, 2, 3, 4)
    var t: tensor<int, 2, 2> = tensor_transpose(a)
    print_int(tensor_get(t, 0, 0))
    print_int(tensor_get(t, 0, 1))
    print_int(tensor_get(t, 1, 0))
    print_int(tensor_get(t, 1, 1))
    var a23: tensor<int, 2, 3> = tensor_new(2, 3)
    tensor_set(a23, 0, 0, 1)
    tensor_set(a23, 0, 1, 2)
    tensor_set(a23, 0, 2, 3)
    tensor_set(a23, 1, 0, 4)
    tensor_set(a23, 1, 1, 5)
    tensor_set(a23, 1, 2, 6)
    var t32: tensor<int, 3, 2> = tensor_transpose_2x3(a23)
    print_int(tensor_get(t32, 0, 0))
    print_int(tensor_get(t32, 0, 1))
    print_int(tensor_get(t32, 1, 0))
    print_int(tensor_get(t32, 1, 1))
    print_int(tensor_get(t32, 2, 0))
    print_int(tensor_get(t32, 2, 1))
    return 0
}
DIV
check_case transpose "${WORK}/transpose.diva" $'1\n3\n2\n4\n1\n4\n2\n5\n3\n6'

cat > "${WORK}/elementwise.diva" <<'DIV'
import "std/io.diva"
import "std/tensor.diva"

func main(): int {
    var v4: tensor<int, 4> = tensor_from_array4(1, 2, 3, 4)
    var w4: tensor<int, 4> = tensor_from_array4(10, 20, 30, 40)
    var v6: tensor<int, 6> = tensor_from_array6(1, 2, 3, 4, 5, 6)
    var w6: tensor<int, 6> = tensor_from_array6(10, 20, 30, 40, 50, 60)
    var s4: tensor<int, 4> = tensor_add4(v4, w4)
    print_int(tensor_get(s4, 0))
    print_int(tensor_get(s4, 3))
    var s6: tensor<int, 6> = tensor_add6(v6, w6)
    print_int(tensor_get(s6, 0))
    print_int(tensor_get(s6, 3))
    print_int(tensor_get(s6, 4))
    print_int(tensor_get(s6, 5))
    var d4: tensor<int, 4> = tensor_sub(w4, v4)
    print_int(tensor_get(d4, 0))
    print_int(tensor_get(d4, 3))
    var d6: tensor<int, 6> = tensor_sub6(w6, v6)
    print_int(tensor_get(d6, 0))
    print_int(tensor_get(d6, 5))
    var m4: tensor<int, 4> = tensor_mul_elementwise(v4, w4)
    print_int(tensor_get(m4, 0))
    print_int(tensor_get(m4, 3))
    var m6: tensor<int, 6> = tensor_mul_elementwise6(v6, w6)
    print_int(tensor_get(m6, 0))
    print_int(tensor_get(m6, 5))
    var a: tensor<int, 2, 2> = tensor_from_array2x2(1, 2, 3, 4)
    var b: tensor<int, 2, 2> = tensor_from_array2x2(5, 6, 7, 8)
    var aa: tensor<int, 2, 2> = tensor_add_2x2(a, b)
    var ss: tensor<int, 2, 2> = tensor_sub_2x2(b, a)
    var mm: tensor<int, 2, 2> = tensor_mul_elementwise_2x2(a, b)
    print_int(tensor_get(aa, 0, 0))
    print_int(tensor_get(aa, 1, 1))
    print_int(tensor_get(ss, 0, 0))
    print_int(tensor_get(ss, 1, 1))
    print_int(tensor_get(mm, 0, 0))
    print_int(tensor_get(mm, 1, 1))
    return 0
}
DIV
check_case elementwise "${WORK}/elementwise.diva" $'11\n44\n11\n44\n55\n66\n9\n36\n9\n54\n10\n160\n10\n360\n6\n12\n4\n4\n5\n32'
check_ir elementwise_simd "${WORK}/elementwise.diva" ' mul '
check_ir elementwise_lane_load "${WORK}/elementwise.diva" 'array.load'

cat > "${WORK}/matmul.diva" <<'DIV'
import "std/io.diva"
import "std/tensor.diva"

func main(): int {
    var a: tensor<int, 2, 2> = tensor_from_array2x2(1, 2, 3, 4)
    var b: tensor<int, 2, 2> = tensor_from_array2x2(5, 6, 7, 8)
    var p: tensor<int, 2, 2> = tensor_matmul_2x2(a, b)
    print_int(tensor_get(p, 0, 0))
    print_int(tensor_get(p, 0, 1))
    print_int(tensor_get(p, 1, 0))
    print_int(tensor_get(p, 1, 1))
    var a23: tensor<int, 2, 3> = tensor_new(2, 3)
    tensor_set(a23, 0, 0, 1)
    tensor_set(a23, 0, 1, 2)
    tensor_set(a23, 0, 2, 3)
    tensor_set(a23, 1, 0, 4)
    tensor_set(a23, 1, 1, 5)
    tensor_set(a23, 1, 2, 6)
    var b32: tensor<int, 3, 2> = tensor_new(3, 2)
    tensor_set(b32, 0, 0, 7)
    tensor_set(b32, 0, 1, 8)
    tensor_set(b32, 1, 0, 9)
    tensor_set(b32, 1, 1, 10)
    tensor_set(b32, 2, 0, 11)
    tensor_set(b32, 2, 1, 12)
    var p23: tensor<int, 2, 2> = tensor_matmul_2x3(a23, b32)
    print_int(tensor_get(p23, 0, 0))
    print_int(tensor_get(p23, 0, 1))
    print_int(tensor_get(p23, 1, 0))
    print_int(tensor_get(p23, 1, 1))
    return 0
}
DIV
check_case matmul "${WORK}/matmul.diva" $'19\n22\n43\n50\n58\n64\n139\n154'

cat > "${WORK}/reductions.diva" <<'DIV'
import "std/io.diva"
import "std/tensor.diva"

func main(): int {
    var v4: tensor<int, 4> = tensor_from_array4(1, 2, 3, 4)
    var v6: tensor<int, 6> = tensor_from_array6(1, 2, 3, 4, 5, 6)
    var m: tensor<int, 2, 2> = tensor_from_array2x2(1, 2, 3, 4)
    print_int(tensor_reduce_sum(v4))
    print_int(tensor_reduce_sum6(v6))
    print_int(tensor_reduce_sum_2x2(m))
    return 0
}
DIV
check_case reductions "${WORK}/reductions.diva" $'10\n21\n10'

cat > "${WORK}/bad_shape.diva" <<'DIV'
import "std/tensor.diva"

func main(): int {
    var z: tensor<int, 2, 2> = tensor_zeros(3, 2)
    return tensor_get(z, 0, 0)
}
DIV
check_exit bad_shape "${WORK}/bad_shape.diva" 1

cat > "${WORK}/bad_eye.diva" <<'DIV'
import "std/tensor.diva"

func main(): int {
    var e: tensor<int, 2, 2> = tensor_eye(3)
    return tensor_get(e, 0, 0)
}
DIV
check_exit bad_eye "${WORK}/bad_eye.diva" 1

cat > "${WORK}/benchmark.diva" <<'DIV'
import "std/io.diva"
import "std/tensor.diva"

func main(): int {
    var a6: tensor<int, 6> = tensor_from_array6(1, 2, 3, 4, 5, 6)
    var b6: tensor<int, 6> = tensor_from_array6(10, 20, 30, 40, 50, 60)
    var a22: tensor<int, 2, 2> = tensor_from_array2x2(1, 2, 3, 4)
    var b22: tensor<int, 2, 2> = tensor_from_array2x2(5, 6, 7, 8)
    var acc = 0
    var i = 0
    while (i < 2000) {
        var s6: tensor<int, 6> = tensor_add6(a6, b6)
        var p22: tensor<int, 2, 2> = tensor_matmul_2x2(a22, b22)
        acc = acc + tensor_reduce_sum6(s6) + tensor_reduce_sum_2x2(p22)
        i = i + 1
    }
    print_int(acc)
    return 0
}
DIV
total=$((total + 1))
if ! build "${WORK}/benchmark.diva" "${WORK}/benchmark.exe"; then
  fail "benchmark (build)"
else
  start_ns=$(date +%s%N)
  out=$(timeout 120 "${WORK}/benchmark.exe" </dev/null 2>&1)
  rc=$?
  end_ns=$(date +%s%N)
  elapsed_ms=$(((end_ns - start_ns) / 1000000))
  if [ "${rc}" != 0 ]; then
    fail "benchmark (exit ${rc})"
  elif [ "$out" != "730000" ]; then
    fail "benchmark (output ${out})"
  else
    echo "[tensorlib] OK benchmark (${elapsed_ms} ms, checksum ${out})"
  fi
fi

printf '[tensorlib] %d/%d passed\n' "$((total - failed))" "$total"
if [ "${failed}" != 0 ]; then
  exit 1
fi
echo "[tensorlib] all tests passed"

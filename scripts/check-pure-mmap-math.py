#!/usr/bin/env python3
"""Adversarial capacity invariants for pure int_vec / str_builder mmap layout."""
import re, sys
from pathlib import Path

ROOT = Path(sys.argv[1] if len(sys.argv) > 1 else ".")
src = (ROOT / "compiler/src/pure_elf_builtins.diva").read_text()

def extract_fn(name):
    pat = rf"func {name}\(out: int\): int \{{(.*?)\n    return (\d+)\n\}}"
    m = re.search(pat, src, re.S)
    if not m:
        raise SystemExit(f"missing {name}")
    body = m.group(1)
    ret = int(m.group(2))
    bs = [int(x) for x in re.findall(r"int_vec_push\(out, (\d+)\)", body)]
    return bs, ret

def u32(bs, i):
    return bs[i] | (bs[i+1]<<8) | (bs[i+2]<<16) | (bs[i+3]<<24)

S, H = 0x1000, 24  # 4 KiB page initial — many tiny AST vecs
payload = S - H
errors = []

for name, kind in [("emit_pure_int_vec_new", "qword"), ("emit_pure_str_builder_new", "byte")]:
    bs, ret = extract_fn(name)
    if len(bs) != ret:
        errors.append(f"{name}: blob len {len(bs)} != return {ret}")
    # Find movl $INIT_BYTES into esi: BE <imm32> after xor edi (31 FF)
    be = None
    for i in range(len(bs) - 5):
        if bs[i] == 0xBE and i > 0:
            # prefer the object mmap (second BE), not HT_BYTES
            imm = u32(bs, i + 1)
            if imm == S:
                be = imm
    print(f"{name}: bytes={len(bs)} init_mmap_imm={be:#x}" if be else f"{name}: bytes={len(bs)} init_mmap_imm=MISSING")
    if be != S:
        errors.append(f"{name}: INIT mmap imm {be} != {S:#x}")
    expect_cap = payload // 8 if kind == "qword" else payload
    # Cap is loaded via movl $cap, %ecx — B9 imm32; find value matching expect
    caps = []
    for i in range(len(bs) - 5):
        if bs[i] == 0xB9:
            caps.append(u32(bs, i + 1))
    if expect_cap not in caps:
        errors.append(f"{name}: expected cap {expect_cap:#x} not in movl ecx immediates { [hex(c) for c in caps] }")
    else:
        print(f"  cap ok {expect_cap:#x}")

# tok_esc_cr must be CR
tok = (ROOT / "compiler/src/tokens.diva").read_bytes()
m = re.search(br'func tok_esc_cr\(\): str \{\n    return "(.)"\n\}', tok, re.S)
if not m or m.group(1) != b"\r":
    errors.append(f"tok_esc_cr ord={m.group(1)[0] if m else None}, want 13")
else:
    print("tok_esc_cr: OK (ord=13)")

src_bytes = sum(f.stat().st_size for f in (ROOT/"compiler").rglob("*.diva"))
print(f"compiler .diva bytes={src_bytes}; initial str cap {payload}; grow required for large builds")
# Full-compiler out vec (~700KiB slots) must grow from 64KiB init — intentional.
qcap0 = payload // 8
print(f"initial qword cap={qcap0}; full codegen needs grow? {700*1024 > qcap0}")

# Size table sync
cg = (ROOT / "compiler/src/codegen_x86.diva").read_text()
expect_sizes = {
    9: extract_fn("emit_pure_int_vec_new")[1],
    10: extract_fn("emit_pure_int_vec_push")[1],
    11: extract_fn("emit_pure_int_vec_len")[1],
    12: extract_fn("emit_pure_int_vec_get")[1],
    13: extract_fn("emit_pure_int_vec_free")[1],
    14: extract_fn("emit_pure_str_builder_new")[1],
    15: extract_fn("emit_pure_str_builder_append")[1],
    16: extract_fn("emit_pure_str_builder_len")[1],
    17: extract_fn("emit_pure_str_builder_to_str")[1],
    18: extract_fn("emit_pure_str_builder_free")[1],
}
for id_, sz in expect_sizes.items():
    m = re.search(rf"if id == {id_} \{{ return (\d+) \}}", cg)
    if not m or int(m.group(1)) != sz:
        errors.append(f"pure_builtin_call_size id={id_}: want {sz}, got {m.group(1) if m else None}")
    else:
        print(f"size id {id_}: {sz} OK")

if errors:
    print("FAIL:")
    for e in errors: print(" ", e)
    sys.exit(1)
print("ALL MATH INVARIANTS OK")

#!/usr/bin/env python3
"""Adversarial capacity invariants for pure int_vec / str_builder mmap layout."""
import re, sys
from pathlib import Path

ROOT = Path(sys.argv[1] if len(sys.argv) > 1 else ".")
src = (ROOT / "compiler/src/pure_elf_builtins.diva").read_text()

def extract_fn(name):
    # pull consecutive int_vec_push bytes from _a and _b bodies
    pat = rf"func {name}_a\(out: int\): int \{{(.*?)\}}\nfunc {name}_b\(out: int\): int \{{(.*?)\}}"
    m = re.search(pat, src, re.S)
    if not m:
        raise SystemExit(f"missing {name}")
    body = m.group(1) + m.group(2)
    return [int(x) for x in re.findall(r"int_vec_push\(out, (\d+)\)", body)]

def u32(bs, i):
    return bs[i] | (bs[i+1]<<8) | (bs[i+2]<<16) | (bs[i+3]<<24)

S, H = 0x1000000, 24  # 16 MiB — codegen uses 1 int slot per machine byte
payload = S - H
errors = []

for name, kind in [("emit_pure_int_vec_new", "qword"), ("emit_pure_str_builder_new", "byte")]:
    bs = extract_fn(name)
    assert len(bs) == 96, f"{name} blob len {len(bs)} != 96"
    mmap_len = u32(bs, 3)  # after 31 FF BE
    # find B9 imm32 (mov ecx)
    b9 = bs.index(185)
    cap = u32(bs, b9+1)
    # movq [rax+16], imm — 48 C7 40 10 imm32
    i16 = None
    for i in range(len(bs)-7):
        if bs[i:i+4] == [72, 199, 64, 16]:
            i16 = u32(bs, i+4); break
    print(f"{name}: mmap={mmap_len:#x} cap={cap:#x} size@16={i16:#x} bytes={len(bs)}")
    if mmap_len != S:
        errors.append(f"{name}: mmap len {mmap_len:#x} != {S:#x}")
    if i16 != S:
        errors.append(f"{name}: munmap size@16 {i16:#x} != {S:#x}")
    if kind == "qword":
        expect = payload // 8
        if cap != expect:
            errors.append(f"{name}: qword cap {cap:#x} != {expect:#x}")
        if H + cap * 8 != S:
            errors.append(f"{name}: layout overflow H+cap*8={H+cap*8:#x}")
    else:
        expect = payload
        if cap != expect:
            errors.append(f"{name}: byte cap {cap:#x} != {expect:#x}")
        if H + cap != S:
            errors.append(f"{name}: layout overflow H+cap={H+cap:#x}")

# tok_esc_cr must be CR
tok = (ROOT / "compiler/src/tokens.diva").read_bytes()
m = re.search(br'func tok_esc_cr\(\): str \{\n    return "(.)"\n\}', tok, re.S)
if not m or m.group(1) != b"\r":
    errors.append(f"tok_esc_cr ord={m.group(1)[0] if m else None}, want 13")
else:
    print("tok_esc_cr: OK (ord=13)")

# workload fit: sources in str_builder; codegen out vec needs ~1 slot/byte of ELF
src_bytes = sum(f.stat().st_size for f in (ROOT/"compiler").rglob("*.diva"))
qcap = payload // 8
print(f"compiler .diva bytes={src_bytes}; fits str cap {payload}? {src_bytes < payload}")
print(f"qword cap={qcap}; fits ~700KiB codegen out? {700*1024 < qcap}")
if src_bytes >= payload:
    errors.append("compiler sources exceed str_builder cap")
if qcap < 700 * 1024:
    errors.append(f"qword cap {qcap} too small for full-compiler codegen out vec")

if errors:
    print("FAIL:")
    for e in errors: print(" ", e)
    sys.exit(1)
print("ALL MATH INVARIANTS OK")

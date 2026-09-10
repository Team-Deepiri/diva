#!/usr/bin/env python3
"""Adversarial capacity invariants for pure int_vec / str_builder mmap layout.

int_vec_new now carves 128-byte fixed slots from the AST bump arena (cap 13, map_bytes=0)
and falls back to a 4KiB mmap (cap 509) when the arena is exhausted. str_builder_new still
uses a plain 4KiB mmap. This script validates blob len == return, the arena slot constants,
the fallback INIT imm, and pure_builtin_call_size_* sync.
"""
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

def find(bs, seq):
    for i in range(len(bs) - len(seq) + 1):
        if bs[i:i+len(seq)] == seq:
            return i
    return -1

S, H = 0x1000, 24        # 4 KiB fallback/init object mmap
SLOT, SLOT_CAP = 0x80, 13  # AST bump arena fixed slot and its qword capacity
payload = S - H
errors = []

# int_vec_new: arena carve + fallback mmap
bs, ret = extract_fn("emit_pure_int_vec_new")
if len(bs) != ret:
    errors.append(f"emit_pure_int_vec_new: blob len {len(bs)} != return {ret}")
print(f"emit_pure_int_vec_new: bytes={len(bs)}")
# Arena slot cap: movl $SLOT_CAP, %ecx  =>  B9 0D 00 00 00
if find(bs, [0xB9, SLOT_CAP, 0, 0, 0]) < 0:
    errors.append(f"emit_pure_int_vec_new: arena slot cap {SLOT_CAP:#x} (B9 {SLOT_CAP:#x} 0 0 0) missing")
else:
    print(f"  arena slot cap ok {SLOT_CAP:#x} (slot {SLOT:#x} bytes)")
# map_bytes=0 marks arena slot: movq $0, 16(%rbx)  => 48 C7 43 10 00 00 00 00
if find(bs, [0x48, 0xC7, 0x43, 0x10, 0, 0, 0, 0]) < 0:
    errors.append("emit_pure_int_vec_new: arena map_bytes=0 store (48 C7 43 10 00 00 00 00) missing")
else:
    print("  arena slot map_bytes=0 marker ok")
# Fallback INIT mmap: movl $INIT_BYTES, %esi  => BE 00 10 00 00
be = find(bs, [0xBE, S & 0xFF, (S >> 8) & 0xFF, (S >> 16) & 0xFF, (S >> 24) & 0xFF])
if be < 0:
    errors.append(f"emit_pure_int_vec_new: fallback INIT imm {S:#x} (BE imm32) missing")
else:
    print(f"  fallback INIT mmap imm ok {S:#x}")
# Fallback cap: movl $509, %ecx  => B9 FD 01 00 00
fb_cap = payload // 8
if find(bs, [0xB9, fb_cap & 0xFF, (fb_cap >> 8) & 0xFF, (fb_cap >> 16) & 0xFF, (fb_cap >> 24) & 0xFF]) < 0:
    errors.append(f"emit_pure_int_vec_new: fallback cap {fb_cap:#x} (B9 imm32) missing")
else:
    print(f"  fallback cap ok {fb_cap:#x}")

# int_vec_push: must still contain the promote + mremap growth path
bs, ret = extract_fn("emit_pure_int_vec_push")
if len(bs) != ret:
    errors.append(f"emit_pure_int_vec_push: blob len {len(bs)} != return {ret}")
print(f"emit_pure_int_vec_push: bytes={len(bs)}")
# promote branch mmap INIT imm, cap 509, and mremap nr 25
if find(bs, [0xBE, S & 0xFF, (S >> 8) & 0xFF, (S >> 16) & 0xFF, (S >> 24) & 0xFF]) < 0:
    errors.append("emit_pure_int_vec_push: promote INIT imm 0x1000 missing")
if find(bs, [0xB9, fb_cap & 0xFF, (fb_cap >> 8) & 0xFF, (fb_cap >> 16) & 0xFF, (fb_cap >> 24) & 0xFF]) < 0:
    errors.append("emit_pure_int_vec_push: promote cap 509 missing")
if find(bs, [0xB8, 25, 0, 0, 0]) < 0:
    errors.append("emit_pure_int_vec_push: mremap syscall nr 25 missing")

# int_vec_free: must skip munmap for arena slots (map_bytes==0 test on 16(%rcx))
bs, ret = extract_fn("emit_pure_int_vec_free")
if len(bs) != ret:
    errors.append(f"emit_pure_int_vec_free: blob len {len(bs)} != return {ret}")
print(f"emit_pure_int_vec_free: bytes={len(bs)}")
# test map_bytes != 0: 48 8B 71 10 (mov 16(%rcx),%rsi) then 48 85 F6 (test %rsi,%rsi)
if find(bs, [0x48, 0x8B, 0x71, 0x10]) < 0 or find(bs, [0x48, 0x85, 0xF6]) < 0:
    errors.append("emit_pure_int_vec_free: map_bytes arena-slot check (mov 16(%rcx),%rsi / test) missing")
else:
    print("  arena-slot munmap skip check ok")

# str_builder_new: still plain 4KiB mmap (byte payload cap 4072)
bs, ret = extract_fn("emit_pure_str_builder_new")
if len(bs) != ret:
    errors.append(f"emit_pure_str_builder_new: blob len {len(bs)} != return {ret}")
be = find(bs, [0xBE, S & 0xFF, (S >> 8) & 0xFF, (S >> 16) & 0xFF, (S >> 24) & 0xFF])
if be < 0:
    errors.append(f"emit_pure_str_builder_new: INIT imm {S:#x} missing")
else:
    print(f"emit_pure_str_builder_new: bytes={len(bs)} init_mmap_imm={S:#x}")
sb_cap = payload  # byte payload: 0x1000 - 24 = 4072
caps = []
for i in range(len(bs) - 5):
    if bs[i] == 0xB9:
        caps.append(u32(bs, i + 1))
if sb_cap not in caps:
    errors.append(f"emit_pure_str_builder_new: expected cap {sb_cap:#x} not in movl ecx immediates { [hex(c) for c in caps] }")
else:
    print(f"  str_builder cap ok {sb_cap:#x}")

# tok_esc_cr must be CR
tok = (ROOT / "compiler/src/tokens.diva").read_bytes()
m = re.search(br'func tok_esc_cr\(\): str \{\n    return "(.)"\n\}', tok, re.S)
if not m or m.group(1) != b"\r":
    errors.append(f"tok_esc_cr ord={m.group(1)[0] if m else None}, want 13")
else:
    print("tok_esc_cr: OK (ord=13)")

src_bytes = sum(f.stat().st_size for f in (ROOT/"compiler").rglob("*.diva"))
print(f"compiler .diva bytes={src_bytes}; arena slot qword cap={SLOT_CAP}; fallback init cap={fb_cap}")
print(f"initial qword cap={fb_cap}; full codegen needs grow? {700*1024 > fb_cap}")

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

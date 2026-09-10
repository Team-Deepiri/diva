#!/usr/bin/env python3
"""Embed minimal DWARF .debug_line/.debug_info/.debug_abbrev into a Diva pure ELF (Issue #63).

Usage: embed-dwarf-debug.py <elf-path> <src-path>

Preserves PT_LOAD layout; appends non-loaded debug sections + section headers.
"""
from __future__ import annotations

import struct
import sys
from pathlib import Path


def u16(x: int) -> bytes:
    return struct.pack("<H", x)


def u32(x: int) -> bytes:
    return struct.pack("<I", x)


def u64(x: int) -> bytes:
    return struct.pack("<Q", x)


def guess_entry_line(src: Path) -> int:
    try:
        text = src.read_text(encoding="utf-8", errors="replace")
    except OSError:
        return 1
    line = 1
    for i, ch in enumerate(text):
        if ch == "\n":
            line += 1
        if text.startswith("func main", i) or text.startswith("func kmain", i):
            return line
    return 1


def build_debug(src_path: str, entry_line: int, code_len: int, text_vaddr: int = 0x1000) -> tuple[bytes, bytes, bytes, bytes]:
    src_name = src_path.encode() + b"\0"

    abbrev = bytearray()
    abbrev += bytes([1, 0x11, 1])
    abbrev += bytes([0x03, 0x08])
    abbrev += bytes([0x10, 0x17])
    abbrev += bytes([0x11, 0x01])
    abbrev += bytes([0x12, 0x07])
    abbrev += bytes([0, 0, 0])

    line_base = -5
    line_range = 14
    opcode_base = 13
    std_ops = bytes([0, 1, 1, 1, 1, 0, 0, 0, 1, 0, 0, 1])
    header_rest = bytearray()
    header_rest += bytes([1, 1, 1, line_base & 0xFF, line_range, opcode_base])
    header_rest += std_ops
    header_rest += bytes([0])
    header_rest += src_name + bytes([0, 0, 0, 0])

    ops = bytearray()
    ops += bytes([0, 9, 2]) + u64(text_vaddr)
    delta = max(0, entry_line - 1)
    ops += bytes([3, delta & 0x7F])  # advance_line (small non-neg)
    ops += bytes([1])  # copy
    ops += bytes([0, 9, 2]) + u64(text_vaddr + code_len)
    ops += bytes([0, 1, 1])  # end_sequence

    unit = u16(4) + u32(len(header_rest)) + header_rest + ops
    debug_line = u32(len(unit)) + unit

    info_body = bytearray()
    info_body += u16(4)
    info_body += u32(0)
    info_body += bytes([8, 1])
    info_body += src_name
    info_body += u32(0)
    info_body += u64(text_vaddr)
    info_body += u64(code_len)
    info_body += bytes([0])
    debug_info = u32(len(info_body)) + info_body

    shstr = b"\0.text\0.debug_abbrev\0.debug_info\0.debug_line\0.shstrtab\0"
    return bytes(abbrev), bytes(debug_info), bytes(debug_line), shstr


def shdr(name_off, sh_type, flags, addr, offset, size, addralign=1):
    return struct.pack(
        "<IIQQQQIIQQ",
        name_off,
        sh_type,
        flags,
        addr,
        offset,
        size,
        0,
        0,
        addralign,
        0,
    )


def embed(elf_path: Path, src_path: str) -> None:
    data = bytearray(elf_path.read_bytes())
    if data[:4] != b"\x7fELF":
        raise SystemExit("not an ELF")
    # Diva pure ELF: e_phnum=2, e_shoff=0, RX at file/vaddr 0x1000
    e_phoff = struct.unpack_from("<Q", data, 32)[0]
    e_phentsize = struct.unpack_from("<H", data, 54)[0]
    e_phnum = struct.unpack_from("<H", data, 56)[0]
    if e_phnum < 2:
        raise SystemExit("expected 2 program headers")
    # Second phdr is RX code
    ph2 = e_phoff + e_phentsize
    p_offset = struct.unpack_from("<Q", data, ph2 + 8)[0]
    p_filesz = struct.unpack_from("<Q", data, ph2 + 32)[0]
    p_memsz = struct.unpack_from("<Q", data, ph2 + 40)[0]
    align = 4096
    if p_offset != align:
        raise SystemExit(f"unexpected code offset {p_offset}")
    code_len = p_filesz
    code_size = p_memsz
    load_end = align + code_size
    if len(data) < load_end:
        raise SystemExit("ELF shorter than load image")
    # Strip any previous section table (non -g has none; re-run safe if we truncate to load_end)
    data = data[:load_end]

    entry_line = guess_entry_line(Path(src_path))
    abbrev, debug_info, debug_line, shstr = build_debug(src_path, entry_line, code_len)

    off_abbrev = load_end
    off_info = off_abbrev + len(abbrev)
    off_line = off_info + len(debug_info)
    off_shstr = off_line + len(debug_line)
    off_shdr = off_shstr + len(shstr)
    pad = (8 - (off_shdr % 8)) % 8
    off_shdr += pad

    data += abbrev
    data += debug_info
    data += debug_line
    data += shstr
    data += b"\0" * pad

    SHT_NULL, SHT_PROGBITS, SHT_STRTAB = 0, 1, 3
    SHF_ALLOC, SHF_EXECINSTR = 2, 4
    names = {".text": 1, ".debug_abbrev": 7, ".debug_info": 21, ".debug_line": 33, ".shstrtab": 45}

    data += shdr(0, SHT_NULL, 0, 0, 0, 0)
    data += shdr(names[".text"], SHT_PROGBITS, SHF_ALLOC | SHF_EXECINSTR, align, align, code_len, 16)
    data += shdr(names[".debug_abbrev"], SHT_PROGBITS, 0, 0, off_abbrev, len(abbrev))
    data += shdr(names[".debug_info"], SHT_PROGBITS, 0, 0, off_info, len(debug_info))
    data += shdr(names[".debug_line"], SHT_PROGBITS, 0, 0, off_line, len(debug_line))
    data += shdr(names[".shstrtab"], SHT_STRTAB, 0, 0, off_shstr, len(shstr))

    struct.pack_into("<Q", data, 40, off_shdr)
    struct.pack_into("<H", data, 58, 64)
    struct.pack_into("<H", data, 60, 6)
    struct.pack_into("<H", data, 62, 5)

    elf_path.write_bytes(data)


def main() -> None:
    if len(sys.argv) != 3:
        print("usage: embed-dwarf-debug.py <elf> <src-path>", file=sys.stderr)
        raise SystemExit(2)
    embed(Path(sys.argv[1]), sys.argv[2])


if __name__ == "__main__":
    main()

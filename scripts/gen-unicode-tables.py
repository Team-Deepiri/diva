#!/usr/bin/env python3
"""Generate committed Unicode data modules for the Diva stdlib.

The Diva lexer supports only the escapes \\n \\t \\r \\" \\\\, so binary data
cannot be written with \\xNN. This generator emits real bytes into the source.
All table integers are stored as three base-255 digits, little-endian, with each
digit byte written as ``digit + 1`` (so no byte is ever 0x00, which a Diva
``text`` literal cannot carry).

Outputs:
  stdlib/std/byte_table.diva
      utf8_byte_table(): text -- a 255-byte literal holding byte values 1..255
      in order (index b-1 -> byte b). Byte 0x00 is not representable as a source
      byte and is therefore absent; Diva text values cannot carry an interior
      NUL in Phase 2.

  stdlib/std/ucd.diva
      Minimal Unicode Character Database property tables (#159): full case
      mapping, simple case folding, canonical combining classes, canonical
      decomposition / composition, general-category slices (letters, marks,
      digits, upper/lower), White_Space, grapheme cluster break classes, and
      East Asian width. Data is read by std/text.diva.

Data sources (Unicode 15.0.0, matching CPython's unicodedata):
  * Python ``unicodedata``: general category, canonical combining class,
    canonical/compatibility decomposition, and per-codepoint ``str.upper`` /
    ``str.lower`` / ``str.casefold`` give full case mappings.
  * UCD text files downloaded (and cached under build/ucd-cache) for the
    properties Python does not expose: Grapheme_Cluster_Break, East_Asian_Width,
    White_Space, and Full_Composition_Exclusion.

Run from the repository root:
    python3 scripts/gen-unicode-tables.py
"""

import os
import sys
import unicodedata
import urllib.request

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
STD = os.path.join(ROOT, "stdlib", "std")
CACHE = os.path.join(ROOT, "build", "ucd-cache")

UCD_VERSION = "15.0.0"
BASE_URL = "https://www.unicode.org/Public/%s/ucd/" % UCD_VERSION

MAX_CP = 0x110000

# Escapes the Diva lexer/decoder understands.
_ESC = {
    0x0A: b"\\n",
    0x09: b"\\t",
    0x0D: b"\\r",
    0x22: b'\\"',
    0x5C: b"\\\\",
}

# General-category tag we never want in mappings.
_SURROGATE_LO = 0xD800
_SURROGATE_HI = 0xDFFF


# ---------------------------------------------------------------------------
# byte encoding
# ---------------------------------------------------------------------------

def enc3(v):
    """Encode a non-negative int < 255**3 as 3 bytes; each digit byte = d+1."""
    if v < 0 or v > 16581374:
        raise ValueError("enc3 out of range: %d" % v)
    out = bytearray()
    for _ in range(3):
        out.append((v % 255) + 1)
        v //= 255
    return bytes(out)


def encode_literal(data):
    """Render raw bytes as the inside of a Diva ``text"..."`` literal."""
    out = bytearray()
    for b in data:
        if b == 0:
            raise ValueError("interior NUL is not representable")
        out += _ESC.get(b, bytes([b]))
    return out.decode("latin-1")


def emit_blob(fh, func, data, doc=None):
    if doc:
        fh.write("// %s\n" % doc)
    fh.write("func %s(): text {\n" % func)
    fh.write('    return text"%s"\n' % encode_literal(data))
    fh.write("}\n\n")


def emit_int(fh, func, value, doc=None):
    if doc:
        fh.write("// %s\n" % doc)
    fh.write("func %s(): int {\n    return %d\n}\n\n" % (func, value))


# ---------------------------------------------------------------------------
# UCD file fetching / parsing
# ---------------------------------------------------------------------------

def fetch(rel, cached_name):
    os.makedirs(CACHE, exist_ok=True)
    path = os.path.join(CACHE, cached_name)
    if not os.path.exists(path):
        url = BASE_URL + rel
        sys.stderr.write("[gen-unicode-tables] fetching %s\n" % url)
        with urllib.request.urlopen(url, timeout=60) as r:
            data = r.read()
        with open(path, "wb") as f:
            f.write(data)
    with open(path, "r", encoding="utf-8") as f:
        return f.read()


def parse_ranges(text):
    """Parse ``XXXX..YYYY ; Value`` lines into {value: [(lo, hi), ...]}."""
    out = {}
    for line in text.splitlines():
        line = line.split("#", 1)[0].strip()
        if not line or ";" not in line:
            continue
        lhs, val = line.split(";", 1)
        val = val.strip()
        lhs = lhs.strip()
        if ".." in lhs:
            a, b = lhs.split("..")
            a, b = int(a, 16), int(b, 16)
        else:
            a = b = int(lhs, 16)
        out.setdefault(val, []).append((a, b))
    return out


def parse_all_ranges(text):
    """Same as parse_ranges but returns a flat list of (lo, hi, value)."""
    out = []
    for val, ranges in parse_ranges(text).items():
        for lo, hi in ranges:
            out.append((lo, hi, val))
    return out


def merge_ranges(pairs):
    """Merge a list of (lo, hi) into sorted disjoint ranges."""
    pairs = sorted(pairs)
    merged = []
    for lo, hi in pairs:
        if merged and lo <= merged[-1][1] + 1:
            if hi > merged[-1][1]:
                merged[-1][1] = hi
        else:
            merged.append([lo, hi])
    return [(a, b) for a, b in merged]


def ranges_from_predicate(pred):
    pairs = []
    start = None
    for cp in range(MAX_CP):
        if pred(cp):
            if start is None:
                start = cp
        else:
            if start is not None:
                pairs.append((start, cp - 1))
                start = None
    if start is not None:
        pairs.append((start, MAX_CP - 1))
    return pairs


# ---------------------------------------------------------------------------
# byte_table.diva
# ---------------------------------------------------------------------------

def emit_byte_table():
    data = bytes(range(1, 256))
    body = encode_literal(data)
    out = (
        "// GENERATED by scripts/gen-unicode-tables.py -- do not edit by hand.\n"
        "// Runtime byte -> text bridge. Index (b - 1) holds byte b for b in 1..255.\n"
        "// Byte 0x00 is not representable in source; interior NUL is out of scope\n"
        "// until a length-carrying byte constructor exists (see #154, #163).\n"
        "\n"
        "func utf8_byte_table(): text {\n"
        "    return text\"" + body + "\"\n"
        "}\n"
    )
    path = os.path.join(STD, "byte_table.diva")
    with open(path, "w", encoding="latin-1", newline="") as f:
        f.write(out)
    sys.stderr.write("[gen-unicode-tables] wrote %s\n" % os.path.relpath(path, ROOT))


# ---------------------------------------------------------------------------
# ucd.diva
# ---------------------------------------------------------------------------

# Grapheme_Cluster_Break class codes shared with std/text.diva.
GCB = {
    "Other": 0,
    "CR": 1,
    "LF": 2,
    "Control": 3,
    "Extend": 4,
    "ZWJ": 5,
    "Regional_Indicator": 6,
    "Prepend": 7,
    "SpacingMark": 8,
    "L": 9,
    "V": 10,
    "T": 11,
    "LV": 12,
    "LVT": 13,
}


def case_table(mapfn):
    records = []
    seq = bytearray()
    for cp in range(MAX_CP):
        if _SURROGATE_LO <= cp <= _SURROGATE_HI:
            continue
        ch = chr(cp)
        mapped = mapfn(ch)
        if mapped == ch or not mapped:
            continue
        offset = len(seq)
        for c in mapped:
            seq += enc3(ord(c))
        records.append((cp, offset, len(mapped)))
    return records, bytes(seq)


def emit_case(fh, name, records, seqs, note):
    blob = bytearray()
    for cp, off, ln in records:
        blob += enc3(cp) + enc3(off) + enc3(ln)
    emit_blob(fh, "ucd_%s_table" % name, bytes(blob),
              "%s: %d records (cp, seq_offset, len), %s." % (name, len(records), note))
    emit_int(fh, "ucd_%s_count" % name, len(records))
    emit_blob(fh, "ucd_%s_seqs" % name, seqs,
              "%s replacement codepoints (3 bytes each)." % name)


def emit_ranges(fh, name, ranges, note):
    blob = bytearray()
    for lo, hi in ranges:
        blob += enc3(lo) + enc3(hi)
    emit_blob(fh, "ucd_%s_ranges" % name, bytes(blob),
              "%s ranges: %d entries (start, end), sorted. %s." %
              (name, len(ranges), note))
    emit_int(fh, "ucd_%s_ranges_count" % name, len(ranges))


def emit_main():
    # ---- Python-provided properties -------------------------------------
    cat = ["Cn"] * MAX_CP
    ccc = [0] * MAX_CP
    decomp = [None] * MAX_CP
    for cp in range(MAX_CP):
        ch = chr(cp)
        cat[cp] = unicodedata.category(ch)
        ccc[cp] = unicodedata.combining(ch)
        d = unicodedata.decomposition(ch)
        if d and not d.startswith("<"):
            decomp[cp] = [int(x, 16) for x in d.split()]

    # ---- downloaded UCD files -------------------------------------------
    gcb_ranges = parse_all_ranges(
        fetch("auxiliary/GraphemeBreakProperty.txt", "GraphemeBreakProperty.txt"))
    eaw_ranges = parse_all_ranges(
        fetch("EastAsianWidth.txt", "EastAsianWidth.txt"))
    ws_ranges = parse_ranges(
        fetch("PropList.txt", "PropList.txt")).get("White_Space", [])
    fce_ranges = parse_ranges(
        fetch("DerivedNormalizationProps.txt",
              "DerivedNormalizationProps.txt")).get("Full_Composition_Exclusion", [])

    fce = set()
    for lo, hi in fce_ranges:
        for cp in range(lo, hi + 1):
            fce.add(cp)

    def gcb_of(cp):
        # Build a lookup later; for now linear over the (small) list is fine
        # because we call this once per codepoint to build ranges.
        for lo, hi, val in gcb_ranges:
            if lo <= cp <= hi:
                return GCB.get(val, 0)
        return 0

    gcb_by_cp = [0] * MAX_CP
    for lo, hi, val in gcb_ranges:
        code = GCB.get(val, 0)
        for cp in range(lo, hi + 1):
            gcb_by_cp[cp] = code

    eaw_by_cp = ["N"] * MAX_CP
    for lo, hi, val in eaw_ranges:
        for cp in range(lo, hi + 1):
            eaw_by_cp[cp] = val

    # ---- case mapping (full) --------------------------------------------
    up_rec, up_seq = case_table(lambda c: c.upper())
    lo_rec, lo_seq = case_table(lambda c: c.lower())
    cf_rec, cf_seq = case_table(lambda c: c.casefold())

    # ---- combining classes ----------------------------------------------
    ccc_pairs = bytearray()
    ccc_n = 0
    for cp in range(MAX_CP):
        if ccc[cp]:
            ccc_pairs += enc3(cp) + enc3(ccc[cp])
            ccc_n += 1

    # ---- canonical decomposition ----------------------------------------
    dec_triples = bytearray()
    dec_n = 0
    for cp in range(MAX_CP):
        d = decomp[cp]
        if not d:
            continue
        d1 = d[0]
        d2 = d[1] if len(d) > 1 else 0
        dec_triples += enc3(cp) + enc3(d1) + enc3(d2)
        dec_n += 1

    # ---- canonical composition (primary composites) ---------------------
    comp = []
    for cp in range(MAX_CP):
        d = decomp[cp]
        if not d or len(d) != 2 or cp in fce:
            continue
        comp.append((d[0], d[1], cp))
    comp.sort()
    comp_triples = bytearray()
    for a, b, c in comp:
        comp_triples += enc3(a) + enc3(b) + enc3(c)

    # ---- general-category slices ----------------------------------------
    letter_ranges = ranges_from_predicate(lambda cp: cat[cp][0] == "L")
    mark_ranges = ranges_from_predicate(lambda cp: cat[cp][0] == "M")
    digit_ranges = ranges_from_predicate(lambda cp: cat[cp] == "Nd")
    upper_ranges = ranges_from_predicate(lambda cp: cat[cp] == "Lu")
    lower_ranges = ranges_from_predicate(lambda cp: cat[cp] == "Ll")
    ws = merge_ranges(ws_ranges)

    # ---- grapheme break class ranges ------------------------------------
    gcb_out = []
    start = None
    cur = 0
    for cp in range(MAX_CP):
        cls = gcb_by_cp[cp]
        if start is None:
            start, cur = cp, cls
        elif cls != cur:
            gcb_out.append((start, cp - 1, cur))
            start, cur = cp, cls
    if start is not None:
        gcb_out.append((start, MAX_CP - 1, cur))
    gcb_blob = bytearray()
    for lo, hi, cls in gcb_out:
        gcb_blob += enc3(lo) + enc3(hi) + enc3(cls)

    # ---- wide / zero-width ----------------------------------------------
    wide = merge_ranges([(lo, hi) for lo, hi, v in eaw_ranges if v in ("W", "F")])
    zero_pairs = []
    for cp in range(MAX_CP):
        c = cat[cp]
        if c in ("Mn", "Me", "Cf", "Cc"):
            zero_pairs.append((cp, cp))
    zero = merge_ranges(zero_pairs)

    # ---- write -----------------------------------------------------------
    path = os.path.join(STD, "ucd.diva")
    with open(path, "w", encoding="latin-1", newline="") as f:
        f.write("// GENERATED by scripts/gen-unicode-tables.py -- do not edit by hand.\n")
        f.write("// Unicode Character Database property tables (#159), Unicode %s.\n" % UCD_VERSION)
        f.write("// Integers are stored as three base-255 digits, little-endian, each\n")
        f.write("// digit byte = digit + 1 (no 0x00 byte). Decoding lives in std/text.diva.\n")
        f.write("//\n")
        f.write("// This module is pure data: it declares no externs and is imported by\n")
        f.write("// std/text.diva (a value/text.diva import cycle is not supported).\n")
        f.write("\n")

        emit_int(f, "ucd_version_major", 15)
        emit_int(f, "ucd_version_minor", 0)
        emit_int(f, "ucd_version_patch", 0)

        emit_case(f, "upper", up_rec, up_seq, "full uppercase mapping")
        emit_case(f, "lower", lo_rec, lo_seq, "full lowercase mapping")
        emit_case(f, "fold", cf_rec, cf_seq, "simple/full case folding")

        emit_blob(f, "ucd_ccc_table", bytes(ccc_pairs),
                  "Combining classes: %d records (cp, ccc), sorted." % ccc_n)
        emit_int(f, "ucd_ccc_count", ccc_n)

        emit_blob(f, "ucd_decomp_table", bytes(dec_triples),
                  "Canonical decompositions: %d records (cp, d1, d2)." % dec_n)
        emit_int(f, "ucd_decomp_count", dec_n)

        emit_blob(f, "ucd_comp_table", bytes(comp_triples),
                  "Primary composites: %d records (a, b, c)." % len(comp))
        emit_int(f, "ucd_comp_count", len(comp))

        emit_ranges(f, "letter", letter_ranges, "Unicode letters (category L*)")
        emit_ranges(f, "upper", upper_ranges, "Uppercase letters (Lu)")
        emit_ranges(f, "lower", lower_ranges, "Lowercase letters (Ll)")
        emit_ranges(f, "mark", mark_ranges, "Combining marks (category M*)")
        emit_ranges(f, "digit", digit_ranges, "Decimal digits (Nd)")
        emit_ranges(f, "whitespace", ws, "Unicode White_Space")

        emit_blob(f, "ucd_gcb_table", bytes(gcb_blob),
                  "Grapheme_Cluster_Break: %d records (start, end, class)." % len(gcb_out))
        emit_int(f, "ucd_gcb_count", len(gcb_out))

        emit_ranges(f, "wide", wide, "East Asian Wide/Fullwidth")
        emit_ranges(f, "zero", zero, "Zero-width (Mn, Me, Cf, Cc)")

    sys.stderr.write("[gen-unicode-tables] wrote %s (%d bytes)\n"
                     % (os.path.relpath(path, ROOT), os.path.getsize(path)))


def main():
    emit_byte_table()
    emit_main()


if __name__ == "__main__":
    main()

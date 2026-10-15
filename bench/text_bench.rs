// #188 text benchmark baseline (Rust).
//
// Identical `decode_scan` workload and sample text as
// tests/cases/text/text_bench.diva and bench/text_bench.c: build a buffer by
// repeating a fixed codepoint sample, then repeatedly UTF-8 decode every
// codepoint summing the codepoint values. Prints the same checksum so the
// three runtimes can be compared on identical input.
//
// Decoder baseline only; no Unicode normalization tables here, so
// normalize_scan is Diva-only.
//
// Build:  rustc -O -o text_bench_rs bench/text_bench.rs
// Usage:  text_bench_rs <reps> <decode_iters>

const SAMPLE: [u32; 13] = [67, 97, 102, 233, 32, 8212, 32, 26085, 26412, 35486, 32, 127757, 10];

fn utf8_encode(cp: u32, out: &mut Vec<u8>) {
    if cp < 0x80 {
        out.push(cp as u8);
    } else if cp < 0x800 {
        out.push(0xc0 | (cp >> 6) as u8);
        out.push(0x80 | (cp & 0x3f) as u8);
    } else if cp < 0x10000 {
        out.push(0xe0 | (cp >> 12) as u8);
        out.push(0x80 | ((cp >> 6) & 0x3f) as u8);
        out.push(0x80 | (cp & 0x3f) as u8);
    } else {
        out.push(0xf0 | (cp >> 18) as u8);
        out.push(0x80 | ((cp >> 12) & 0x3f) as u8);
        out.push(0x80 | ((cp >> 6) & 0x3f) as u8);
        out.push(0x80 | (cp & 0x3f) as u8);
    }
}

fn utf8_decode(s: &[u8], off: usize) -> (u32, usize) {
    let b = s[off];
    if b < 0x80 {
        (b as u32, 1)
    } else if (b & 0xe0) == 0xc0 && off + 1 < s.len() {
        ((((b & 0x1f) as u32) << 6) | (s[off + 1] & 0x3f) as u32, 2)
    } else if (b & 0xf0) == 0xe0 && off + 2 < s.len() {
        (
            (((b & 0x0f) as u32) << 12)
                | (((s[off + 1] & 0x3f) as u32) << 6)
                | (s[off + 2] & 0x3f) as u32,
            3,
        )
    } else if (b & 0xf8) == 0xf0 && off + 3 < s.len() {
        (
            (((b & 0x07) as u32) << 18)
                | (((s[off + 1] & 0x3f) as u32) << 12)
                | (((s[off + 2] & 0x3f) as u32) << 6)
                | (s[off + 3] & 0x3f) as u32,
            4,
        )
    } else {
        (b as u32, 1)
    }
}

fn main() {
    let args: Vec<String> = std::env::args().collect();
    let reps: usize = args.get(1).and_then(|s| s.parse().ok()).unwrap_or(200);
    let iters: usize = args.get(2).and_then(|s| s.parse().ok()).unwrap_or(1000);
    let reps = if reps == 0 { 200 } else { reps };
    let iters = if iters == 0 { 1000 } else { iters };

    let mut unit: Vec<u8> = Vec::new();
    for &cp in SAMPLE.iter() {
        utf8_encode(cp, &mut unit);
    }

    let mut buf: Vec<u8> = Vec::with_capacity(unit.len() * reps);
    for _ in 0..reps {
        buf.extend_from_slice(&unit);
    }

    let mut sum: i64 = 0;
    for _ in 0..iters {
        let mut i = 0usize;
        while i < buf.len() {
            let (cp, adv) = utf8_decode(&buf, i);
            sum += cp as i64;
            i += adv;
        }
    }

    println!("BENCH bytes={}", buf.len());
    println!("BENCH decode_scan checksum={}", sum);
}

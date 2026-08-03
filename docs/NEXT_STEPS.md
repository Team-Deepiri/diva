# Next steps — pure ELF bootstrap (2026-08-03)

## Artifact rule (do not break this)

**Never** rely on `/tmp/diva-native-exe`. `/tmp` gets wiped; we already lost a good build that way.
Canonical outs: `diva build <src> <out>` (second positional), or `DIVA_NATIVE_EXE_OUT`, else `$ROOT_DIR/build/diva-native-exe`.

| Role | Persistent path |
|------|-----------------|
| Hosted stage2 (cc-link) | `build/diva-stage2-from-cc` |
| Latest pure driver (stage2 → pure) | `build/diva-compiler-pure-elf` |
| Second-stage pure (pure → pure) | `build/diva-compiler-pure-elf-stage2` |
| Promoted trust root | `bootstrap/diva-linux-amd64` |

**Promote only from the latest successful persistent binary** — prefer `build/diva-compiler-pure-elf-stage2` once that exists; until then `build/diva-compiler-pure-elf`. Always `cp -a` that file → `bootstrap/diva-linux-amd64` after verifying it.

```sh
# canonical build outs (no /tmp)
DIVA_SKIP_NATIVE_EXTERN_CHECK=1 DIVA_NO_EXTERNAL=1 \
  ./build/diva-stage2-from-cc build compiler/ "$PWD/build/diva-compiler-pure-elf"

DIVA_PURE_DRIVER="$PWD/build/diva-compiler-pure-elf" ./scripts/verify-pure-only-driver.sh
ROOT_DIR="$PWD" DI_STDLIB_DIR="$PWD/stdlib" \
  ./build/diva-compiler-pure-elf check compiler/
```

## Where we are right now

1. **Stage2 refresh** (cc-link with **16 MiB** mmap fix) — **done**
2. **Stage2 → pure ELF** (`build/diva-compiler-pure-elf`) — **done** (lex/parse + `check compiler/` green)
3. **Second stage** (pure rebuilds itself) — **blocked**: pure **`build`** SIGSEGV. Evidence: tiny `ir`/`asm` OK; **tiny `build` also SIGSEGV** (so emit/ELF-write path, not package size). Full `compiler/` dies ~100s in (long front-end then same class). See applied-math section.
4. **Promote + push** — first-stage pure is in `bootstrap/diva-linux-amd64` (`a8ac9ae` / status `70f8c28`). Re-promote **after** second-stage produces `build/diva-compiler-pure-elf-stage2`.

## Applied-math model of the crash (discovery mode)

### System (plain language)

A program turns source text into a list of machine bytes, wraps them in a file header, and writes that file. Sometimes, when asked to produce that file using only its own machinery (no outside linker), the machine jumps to address zero and dies. Reading and checking source is fine; printing an intermediate text form of the program is fine; writing the final executable is not.

### Inventory

| Kind | Items |
|------|--------|
| Entities | source bytes; token/int slots; IR ops; code-byte stream (`out`); entry trampoline; function offsets; string pool; ELF header; on-disk exe |
| Actions | lex → parse → merge → IR → **pass1 size walk** → **pass2 emit** → ELF header → `write_elf_chunk` |
| Measurables | code length (bytes); slot cap (qwords); stub size (=18); `ir_br_cond` size (=21); wall time to crash (s); RIP/RSP/[RSP]/R15 |
| Constraints | push is silent at cap; pass1 size must equal pass2 length; `call` rel32 = `main_off - 8`; never depend on `/tmp` |

### Representations

1. **Diagram:** stub(18) → funcs… → string pool → ELF hdr → write  
2. **Time series:** tiny `build` dies in **\<2s**; full `compiler/` ~**100s** then dies — consistent with “long front-end, crash at emit/write”  
3. **Hand example (entry stub):**  
   `mov r15,rsp`(3) + `call`(5) + `mov rdi,rax`(3) + `mov eax,60`(5) + `syscall`(2) = **18**. Rel32 uses `main_off - 8` because call opcode starts at offset 3. **Checks out in source.**  
4. **Hand example (`ir_br_cond`):** mov-stack→rax(7) + `testq`(3) + jcc+imm32(6) + jmp+imm32(5) = **21**. `got=0` previously meant **no bytes appended** (full int_vec), not wrong formula.

### Invariants (and break attempts)

| Candidate | Status |
|-----------|--------|
| `pass1_len == pass2_len` | Conserved when emit succeeds; **does not protect** a wrong control-flow graph that still has matching sizes |
| `stub_len == 18` | Holds in emitter; break attempt: wrong `main_off-8` → call into junk (would not usually be RIP 0 unless target is null) |
| `H + 8·cap == mmap` for int_vec | Holds at 16 MiB; **adversarial:** 4 MiB broke it (`got=0`); fit ratio now ~0.34 for ~700 KiB out |
| “lex/parse/check OK ⇒ build OK” | **Broken** — empirically false |
| “ir/asm OK ⇒ build OK” | **Broken** — tiny `ir`/`asm` **rc=0**, tiny `build` **SIGSEGV 139** (2026-08-03 probe on `build/diva-compiler-pure-elf`) |

### Symmetries / dimensionless groups

- **Scale symmetry fails for mmap** (fixed cap): dimensionless fill `φ = code_bytes / qword_cap` must stay `< 1`. At 16 MiB, `φ≈0.34` for current compiler ELF — capacity not the active killer.  
- **Path symmetry:** `ir`/`asm` vs `build` are **not** interchangeable; only `build` takes `cg_module_to_bin` + ELF write. That rules out “general frontend corruption” as the primary model.

### State variables (Markov)

Knowing “last command was check and it passed” does **not** predict build survival. Missing state: **whether the pure emit/write path runs**. Sufficient summary: phase ∈ {front-end, codegen-bin, elf-write}. Instrument to make phase observable.

### Conceptual model

Not an epidemic / not a queue — a **pipeline with a hard absorbing failure** at the binary-materialization stage. Failure mode consistent with **control transfer to null** (ret-to-0 / bad call target / clobbered return), not with capacity exhaustion (that class already observed as `size mismatch got=0`).

### Experiments before “fix” (ordered)

1. gdb/ptrace on **tiny** `build` (fast repro) — record RIP/RSP/[RSP]/R15.  
2. Binary-search: does crash happen before or after `cg_module_to_bin` returns / during `write_elf_chunk`? (stderr breadcrumbs).  
3. Compare hosted stage2 `build` of same tiny file (control).  
4. Only then re-run full `compiler/` second-stage into `build/diva-compiler-pure-elf-stage2`.

### Domain of validity

- Mmap/capacity math: validated for current ~700 KiB outs; will fail again if `φ→1` without realloc.  
- “Tiny ir green” does **not** imply self-host; only tiny+full **`build`** green does.

### Failed guesses

| Guess | Outcome |
|-------|---------|
| 4 MiB enough for self-host | False — `ir_br_cond got=0` |
| Source mmap edit without stage2 refresh updates pure runtime blobs | False — must cc-link stage2 |
| Crash is “compiler package too big / ir pipeline” | **Weakened** — tiny `build` also SIGSEGV; `ir`/`asm` tiny OK |

## Brainstorm — how to get past the SIGSEGV

### A. Confirm the crash class (use tiny `build` first)

```sh
ROOT_DIR="$PWD" DI_STDLIB_DIR="$PWD/stdlib" \
  DIVA_SKIP_NATIVE_EXTERN_CHECK=1 DIVA_NO_EXTERNAL=1 \
  gdb -batch -ex run -ex bt --args \
    ./build/diva-compiler-pure-elf build /tmp/tiny.diva "$PWD/build/diva-tiny-out"
```

Expect: classify RIP≈0 vs other. Full-package ~100s crash is likely the same emit/write failure after a long front-end.

### B. Root cause (confirmed 2026-08-03) + remaining

**Confirmed:** inlined pure `unlink` / `chmod_executable` blobs contained **`ret` (`0xc3`)**. After ELF writeout's `unlink`, `ret` popped stack garbage → RIP=`0xff` → SIGSEGV. Tiny `ir`/`asm` OK; tiny `build` dies on write path.

**Fix in tree:** `.s` + `emit_pure_*` fall-through (no `ret`); sizes unlink **33→30**, chmod **31**. Must re-cc-link stage2 (use **hosted** `SEED=build/diva-stage2-from-cc` — pure bootstrap seed cannot `asm` merged.diva: looks for `tokens.diva` beside it).

**Also fixed:** `build` now writes to CLI out path / `DIVA_NATIVE_EXE_OUT` / `$ROOT_DIR/build/diva-native-exe` (no longer hardcodes `/tmp/diva-native-exe`).
| Suspect | Status |
|---------|--------|
| **Inlined `ret` in unlink/chmod** | **Fixed in sources** — rebuild/verify in progress |
| **`write_elf_chunk` clobbers `is_first` (`r8`)** | Secondary — always O_TRUNC path; fix after self-host green |
| **Other inlined builtins with `ret`** | Audit if more SEGV after unlink fix |
| **int_vec silent full** | Mitigated at 16 MiB |

### C. Definition of “past the SIGSEGV”

```sh
./build/diva-compiler-pure-elf build compiler/ "$PWD/build/diva-compiler-pure-elf-stage2"
./build/diva-compiler-pure-elf-stage2 check compiler/
cp -a build/diva-compiler-pure-elf-stage2 bootstrap/diva-linux-amd64
```

## Do next (priority)

1. **Execute brainstorm §A–C** — land a fix for pure `build` / `ir` SIGSEGV; keep artifacts under `build/`.
2. **Second-stage → `build/diva-compiler-pure-elf-stage2`** — prove pure rebuilds pure.
3. **Promote that latest binary** to `bootstrap/diva-linux-amd64` (not an old `/tmp` copy); commit + push.
4. **Drop `DIVA_SKIP_NATIVE_EXTERN_CHECK`** when seed lists all pure externs.
5. **`DIVA_PURE_FULL=1`** verify green.
6. **Real realloc** for pure push/append.
7. Cleanup: `./scripts/cleanup-dev-artifacts.sh` (`--all` clears stale `/tmp/diva-*` leftovers only).

## Rebuild recipe (emit_* / mmap blob edits)

```sh
# 1) bake emitters into hosted stage2 (required after pure_elf_builtins.diva blob edits)
ASM_TIMEOUT_SECS=7200 ./scripts/legacy/build-compiler-cc-link.sh build/diva-stage2-from-cc

# 2) latest pure — ALWAYS under build/
DIVA_SKIP_NATIVE_EXTERN_CHECK=1 DIVA_NO_EXTERNAL=1 \
  ./build/diva-stage2-from-cc build compiler/ "$PWD/build/diva-compiler-pure-elf"

# 3) self-host gate — latest second stage under build/
DIVA_SKIP_NATIVE_EXTERN_CHECK=1 DIVA_NO_EXTERNAL=1 \
  ./build/diva-compiler-pure-elf build compiler/ "$PWD/build/diva-compiler-pure-elf-stage2"

# 4) promote the newest successful pure binary
cp -a build/diva-compiler-pure-elf-stage2 bootstrap/diva-linux-amd64
```

## Done this session

- 16 MiB exact-fit mmap caps; math check script.
- Stage2 refresh + first-stage pure; promoted to seed.
- Cleanup script; this status / brainstorm / artifact policy.

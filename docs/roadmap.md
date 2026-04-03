# Di Roadmap

This roadmap starts from the current Di MVP, not from zero.

**Status:** The numbered phases below are **direction and sequencing**, not a promise that every bullet is done. What is **actually implemented** is spelled out in `docs/language-spec.md` under **Implemented Today** and **Not Implemented Yet**, and exercised by `tests/run.sh` on Linux/WSL. Phases **2–11** are largely **future work**; do not read them as “all finished.”

Already present today:

- compiler frontend with lexer, parser, AST, and semantic analysis
- `di` CLI with `build`, `run`, `emit-ir`, `watch`, and `new`
- native build path (LLVM IR text output and hosted linking)
- install scripts, examples, tests, and a local editor extension

## Phase 0: Re-Baseline

- replace old future-tense planning with a current-state roadmap
- align docs, examples, parser, and editor support around the same Di syntax
- define clearly what Di is for: a readable compiled systems language
- document what is stable now vs experimental

## Phase 1: Stabilize The Language Core

- freeze the near-term grammar for `var`, `class`, `flux`, imports, arrays, and methods
- remove syntax drift between `var` / `let` and `class` / `struct`
- formalize the grammar in docs and tests
- improve parser and semantic diagnostics for the stable core language

## Phase 2: Real Packages And Modules

- replace single-compilation-unit import flattening with a real module graph
- add package identity, namespaces, visibility, and import rules
- design package layout conventions and package metadata
- add compiled package caching so libraries build once and are reused
- make the future stdlib package-based

## Phase 3: Compiler Architecture Upgrade

- introduce an internal IR between semantic analysis and backend codegen
- separate frontend, semantic, package, and backend stages more cleanly
- keep native glue output as a fallback/debug path while clarifying the LLVM path
- add package-aware incremental compilation
- make watch mode operate on dependency changes, not only a single file

## Phase 4: Generics

- add generic functions
- add generic classes/types
- support explicit generic parameters first
- implement semantic checking and specialization strategy
- add focused generic regression tests before stdlib expansion

## Phase 5: Traits

- add trait declarations and implementations
- support trait bounds on generic code
- start with static dispatch and constrained generics
- add coherence and ambiguity diagnostics
- evaluate trait objects later, not first

## Phase 6: Larger Standard Library

- grow stdlib only after packages and generics are usable
- build `core`, `mem`, `io`, `str`, `math`, `collections`, `iter`, and `os` layers
- keep low-level runtime hooks in native code (LLVM IR / assembly) first where needed
- move higher-level library code into Di over time
- establish stable stdlib package boundaries for SDK consumers

## Phase 7: SDK And Tooling

- define the Di SDK layout: compiler, runtime, stdlib, cache, editor support
- improve `di new` into multiple templates for apps, libraries, and system targets
- add versioning and release packaging
- strengthen editor tooling beyond syntax highlighting
- define platform support expectations across Linux, WSL, Windows, and later macOS

## Phase 8: Systems Programming Features

- add stronger foreign FFI and ABI rules
- add syscall wrappers for supported platforms
- add controlled inline assembly support
- introduce freestanding mode and custom entrypoints
- plan linker-script support and kernel-target builds

## Phase 9: Assembly, ISR, And Kernel Track

- design ISR syntax only for freestanding/kernel targets
- support startup assembly, low-level runtime hooks, and interrupt stubs
- define target-specific calling conventions and backend constraints
- keep kernel-facing work as a deliberate systems track, not accidental scope creep

## Phase 10: Runtime Research Track

- prototype compact tagged values
- evaluate NaN boxing and packed runtime representations
- test slot reuse and lifetime-based memory reuse
- explore cache-line-aware bucket layouts and SIMD-friendly layouts
- benchmark every experiment against the conservative runtime before promoting it

## Phase 11: Alternate Source Frontends

- keep `.diri` as the canonical source extension
- optionally support alternate source extensions or plain-text input modes later
- treat `.txt` compilation as a frontend/input policy decision, not a different execution model
- keep ASCII/bit-driven source experiments separate from the main language path

## Ongoing Quality Gates

- every feature updates the language spec and install/docs story
- every syntax change updates examples and the editor extension
- every compiler feature adds tests
- every runtime experiment must prove itself with benchmarks
- every major milestone should move Di closer to being installable and usable by other developers

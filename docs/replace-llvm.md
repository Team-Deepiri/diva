# Replacing LLVM In Di

This plan is the practical path to making `Di` independent from LLVM without derailing the compiler.

The core idea is:

```text
Now:   Di source -> AST -> current IR -> LLVM IR / generated C -> native build
Later: Di source -> AST -> typed IR -> Di IR -> Di backend -> assembly -> machine code
```

The strategy is to treat LLVM as a temporary backend, not as the permanent shape of the compiler.

## Why This Order

Trying to replace LLVM too early turns language work into backend work.

That is usually the wrong tradeoff for a young language. The compiler needs to first stabilize:

- syntax
- semantics
- type checking
- modules and packages
- self-hosting milestones

LLVM is useful because it removes years of backend complexity while `Di` is still deciding what the language is.

## Stage 1: Keep LLVM For Now

Goal: get `Di` self-hosting as quickly as possible.

Priorities:

- keep building the frontend and semantic pipeline
- make the compiler architecture clean enough to host itself
- use LLVM as the codegen target for native output
- keep the generated-C path as a debug and fallback backend if it remains useful

What to avoid:

- building a custom register allocator too early
- writing an optimizer before the language is stable
- coupling frontend design to backend experiments

Exit criteria:

- `Di` compiles nontrivial programs reliably
- the compiler can compile more and more of itself
- LLVM is helping progress instead of shaping language design

## Stage 2: Introduce A Real Di IR

Goal: make LLVM just one backend target.

Desired pipeline:

```text
Di source -> AST -> typed IR -> Di IR -> LLVM backend -> machine code
```

This is the architectural turning point.

`Di IR` should describe Di semantics directly instead of mirroring LLVM details. It should be:

- backend-independent
- explicit about control flow
- explicit about types and layout decisions
- simple enough to inspect and test

Start with a minimal IR that can represent:

- functions
- parameters
- locals
- constants
- loads and stores
- arithmetic
- branches
- loops
- returns
- calls
- aggregate construction

Likely intermediate layers:

1. `AST`
2. `Typed IR`
3. `Di IR`
4. backend-specific lowering

Recommended rules:

- keep LLVM-specific concepts out of frontend and semantic phases
- lower from semantic structures into `Di IR` only once types are resolved
- define stable IR data structures before adding optimization passes
- add text dump support for `Di IR` early so it can be inspected like LLVM IR today

Exit criteria:

- the frontend no longer emits LLVM-shaped structures directly
- most compiler decisions happen before backend lowering
- LLVM can be swapped without rewriting semantic analysis

## Stage 3: Build A Minimal Native Backend

Goal: replace LLVM with a narrow, correct, maintainable backend.

Initial scope:

- one architecture: `x86_64`
- one platform target at a time, preferably Linux first
- minimal optimization
- correctness over speed

Desired pipeline:

```text
Di source -> AST -> typed IR -> Di IR -> x86_64 codegen -> assembly -> object/executable
```

Implementation order:

1. stack frame layout
2. integer constants and moves
3. arithmetic on integers
4. local variable loads and stores
5. conditional branches and loops
6. function calls and returns
7. ABI-compatible argument passing
8. global data and string literals
9. object file or assembler integration

Keep the first backend deliberately simple:

- use a straightforward instruction selector
- use basic block emission
- start with a simple register strategy, even if inefficient
- spill aggressively if needed before inventing a smarter allocator

Avoid at first:

- multiple architectures
- SIMD
- advanced optimization passes
- custom linker work unless required
- trying to outperform LLVM

Exit criteria:

- `Di` can compile small real programs without LLVM
- generated binaries are correct on one supported target
- the backend is understandable enough to evolve safely

## Stage 4: Make LLVM Optional

Goal: turn LLVM from a requirement into a compatibility backend.

At this point:

- the default path can use the native Di backend
- LLVM can remain available for comparison, debugging, or unsupported targets
- backend bugs can be isolated by comparing `Di IR -> LLVM` vs `Di IR -> native`

This transition is safer than a hard cutover because it preserves a known-good reference target while the native backend matures.

## Suggested Near-Term Work In This Repo

Given the current compiler shape, the next practical steps are:

1. formalize the current internal IR story and separate AST from backend lowering more clearly
2. introduce a typed, backend-neutral IR layer before any direct LLVM replacement work
3. add an explicit `Di IR` dump mode for debugging and regression testing
4. move LLVM-specific lowering behind a backend boundary
5. only then prototype a tiny `x86_64` backend for a restricted subset of the language

## Design Principles

- self-hosting is more important than backend purity in the short term
- backend independence comes from `Di IR`, not from deleting LLVM quickly
- minimal correct codegen is better than ambitious incomplete codegen
- every new backend stage should be inspectable with dumps and tests
- LLVM should be replaced only after it has been successfully demoted to an interchangeable target

## Bottom Line

The serious path is:

1. use LLVM now
2. build a real `Di IR`
3. replace LLVM later with a narrow native backend

That sequence gives `Di` the best chance to become both self-hosting and eventually fully independent.

# Diva Strategic Direction

**Diva is an AI-native systems language.**

Not another general-purpose language. Not a Rust clone. A compiled, high-performance
language designed for the kind of systems you are already building: AI inference
pipelines, robotics controllers, sensor processing, heterogeneous compute, and
edge infrastructure.

The milestone you have already crossed: "can I build a language?" — yes. Proven.
Self-hosted compiler, native ELF output, pure Diva driver, DWARF debug info, a
growing stdlib, kernel package target. That foundation is real.

The next milestone: "why should anyone use Diva instead of Rust/C++/Zig/Go?"

The answer is: because Diva is the language you wish existed for the systems you
are actually building at Deepiri and Exovra.

---

## The thesis

Today's AI and robotics infrastructure has a data movement problem. Tensors live
on GPUs, sensor buffers live on CPUs, embeddings live in model-specific formats,
and the pipelines that connect them are hand-rolled in Python + C++ + CUDA with
no coherent language model for ownership, placement, or transfer.

Diva's long-term bet is that a systems language can make that story better:

```diva
tensor<float16> frame @gpu        // device-placed buffer
tensor<float32> embedding @cpu    // host result

embedding = model.encode(frame)   // compiler reasons about transfer + sync
```

That is not a feature you bolt onto an existing language. It requires a compiler
architecture built for it from day one.

Diva already has that architecture: source → AST → MIR → backend. The MIR is the
right insertion point for a tensor dialect and device placement analysis. MLIR is
the right substrate for lowering to LLVM, CUDA, SPIR-V, and embedded targets. The
path is clear.

---

## What Diva is for

```
                    DIVA
                     │
       ┌─────────────┼─────────────┐
       │             │             │
    Systems        AI/ML       Robotics
       │             │             │
       └─────────────┼─────────────┘
                     │
                 Diva MIR
                     │
                    MLIR
                     │
          ┌──────────┼──────────┐
          │          │          │
        LLVM       GPU/NPU    Embedded
          │          │          │
         CPU      CUDA/SPIR-V  ARM/etc.
```

Systems programming is the base. AI/ML and robotics are the vertical differentiators.
MLIR is the bridge to heterogeneous hardware.

Target platforms: Linux amd64 (today), ARM64 / Raspberry Pi / Jetson (near term),
GPU (CUDA/ROCm via MLIR), embedded (ESP32 / STM32, freestanding).

---

## Phase 1 — Language Maturity

**Goal:** make Diva a language you can write real programs in.

The current surface (funcs, classes, generics, traits, flux, arrays, basic sema)
is a strong skeleton. What is missing is the type-system depth that makes programs
safe and expressive enough to build non-trivial software.

### Type system

- Proper value types / structs with field-level mutability control
- Enums / sum types with tagged variants
- Option and Result as first-class language types (not library shims)
- Pattern matching on enums, Option, and Result with exhaustiveness checking
- Integer width types: `i8`, `i16`, `i32`, `i64`, `u8`, `u16`, `u32`, `u64`, `f32`, `f64`
- Pointer and reference types with explicit syntax (`&T`, `*T`)
- Slice types (`[T]`) as fat pointer over contiguous memory
- Type inference that covers the full expression language, not just literals

### Memory model

- Explicit ownership: every value has a single owner
- Move semantics by default; clone is explicit
- Borrow checker (or a simplified region-based equivalent for the first version)
- Stack-allocated value types; heap allocation via stdlib allocators
- `unsafe` block for raw pointer arithmetic and FFI boundary crossing

### Error handling

- `Result<T, E>` and `Option<T>` as the canonical error/null model
- `?` propagation operator
- No exceptions; no hidden control flow

### Generics and traits

- Full monomorphization for generic functions and types
- Trait bounds on generic parameters
- Associated types on traits
- Trait objects (`dyn Trait`) for dynamic dispatch where needed

### Modules

- Proper module namespacing (not file-flattening)
- Visibility: `pub` / private
- Explicit re-exports
- Clean separation of interface and implementation

### FFI

- C ABI interop with full type safety on the Diva side
- `extern "C"` linkage blocks
- Unsafe raw pointer pass-through for system calls
- `#[repr(C)]` struct layout annotation for ABI-stable types

### Diagnostics

- Every error includes file, line, column, and a human-readable explanation
- Suggestion hints for common mistakes (wrong type, missing return, etc.)
- No silent wrong behavior — unknown identifiers and type mismatches always error

---

## Phase 2 — Compiler Maturity

**Goal:** make the compiler fast, correct, and production-grade.

### MIR

- Typed, backend-neutral Diva IR (MIR) between sema and codegen
- SSA form in MIR
- Control-flow graph representation
- MIR verifier that catches codegen bugs before backend

### Optimization passes

- Constant folding and propagation
- Dead code elimination
- Inlining (small functions, generic specializations)
- Escape analysis: allocate on stack when the lifetime is local
- Loop invariant code motion

### Incremental compilation

- Hash-based module invalidation
- Per-module object caching
- Only recompile what changed

### Debug info

- Full DWARF line/variable/type information
- Working `gdb` / `lldb` breakpoints and variable inspection

### Cross compilation

- Declared target triples (`--target aarch64-linux-gnu`, etc.)
- Cross-compiling from amd64 to ARM64 for Raspberry Pi / Jetson
- Freestanding mode for bare-metal targets

### Diagnostics and tooling

- LSP server (`diva lsp`) for editor integration
- `diva fmt` formatter
- `diva check` with machine-readable JSON output for CI

---

## Phase 3 — MLIR Integration

**Goal:** unlock heterogeneous compute from Diva source.

This is Diva's long-term moat. MLIR is explicitly designed for multi-level lowering
to heterogeneous hardware. By inserting Diva MIR into the MLIR pipeline, Diva gets
GPU, NPU, and embedded targets without hand-writing a backend per device.

```
Diva source
    │
Diva AST
    │
Diva MIR (typed, SSA)
    │
Diva Tensor IR dialect  ←── tensor ops, device annotations, layouts
    │
MLIR
    │
┌───────────────────────────────┐
│  LLVM IR  │  NVVM  │  SPIR-V │
└───────────────────────────────┘
    │               │          │
  CPU (amd64)     GPU (CUDA) GPU (Vulkan)
  CPU (ARM64)     GPU (ROCm)  NPU
```

### Tensor dialect

- `tensor<T, shape>` as a first-class type with shape and element type
- `@device` annotations for placement (cpu, gpu, npu)
- Compiler-managed transfers and synchronization
- Memory layout attributes (`row_major`, `col_major`, `tiled`)
- Zero-copy views over existing buffers

### Automatic differentiation

- Forward and reverse mode AD on tensor expressions
- Gradient annotation syntax: `grad func foo(...)`
- Integration with MLIR's Linalg dialect for efficient gradient lowering

### GPU kernels

- `kernel` function kind targeting GPU execution
- Built-in thread/block index access
- Shared memory declarations
- Lowering to CUDA PTX via NVVM dialect
- Lowering to SPIR-V for Vulkan / ROCm / OpenCL

### ONNX bridge

- Import ONNX models directly as Diva functions
- Ahead-of-time compilation of ONNX graphs to native code via MLIR

---

## Phase 4 — Real Applications

**Goal:** prove the language with non-toy programs.

Benchmarking against toy programs does not answer the question that matters:
"What can I build in Diva that I couldn't build as effectively in another language?"

### Target applications (build these, in Diva)

| Application | What it proves |
|-------------|----------------|
| Diva HTTP server | stdlib networking, systems programming surface, performance |
| Diva key/value store | memory model, data structures, concurrency |
| Diva tensor library | tensor type, SIMD, memory layouts |
| Diva inference runtime | ONNX import, tensor dialect, GPU lowering |
| Diva robotics controller | ARM64 target, real-time workloads, sensor FFI |
| Diva sensor pipeline | zero-copy buffers, async I/O, device placement |
| Diva CLI toolchain | self-hosting, package system, developer UX |

Each of these doubles as a test bed for the language and a demonstration for
external contributors. Ship them. Make them fast. Make them readable.

### Performance targets

- HTTP server: competitive with Go's `net/http` for simple request/response
- Tensor ops: within 2× of numpy for CPU; competitive with cuBLAS for GPU
- Compile time: incremental rebuild under 100ms for a 10k-line project
- Binary size: no hidden runtime overhead beyond what the program needs

### Platform matrix

| Platform | Status |
|----------|--------|
| Linux amd64 | today — native ELF |
| Linux ARM64 / Raspberry Pi 5 | Phase 2 |
| NVIDIA Jetson (ARM64 + GPU) | Phase 3 |
| Bare-metal ARM (ESP32 / STM32) | Phase 2 (freestanding) |
| CUDA GPU | Phase 3 |
| Vulkan / ROCm GPU | Phase 3 |
| macOS amd64 / arm64 | Phase 2 |
| WebAssembly | deferred |

---

## What Diva is not trying to be

- A Rust replacement for general-purpose systems programming. Rust already exists
  and is excellent. Diva does not need to win that fight.
- A Python replacement for data science. NumPy and PyTorch are entrenched. Diva
  targets the infrastructure layer below them.
- A research language. Every phase ends with working software that runs on real
  hardware and solves real problems.
- A language designed by committee. One coherent vision, one consistent syntax,
  one target domain.

---

## Why now

The compiler foundation is done. The hard bootstrap problem — writing a
self-hosting compiler from scratch — is solved. The MIR scaffolding exists. The
ELF backend exists. The package system exists. The stdlib has real modules.

The window to make foundational language decisions (memory model, type system,
tensor semantics) is before there are external users depending on stability. That
window is now.

Phase 1 and Phase 2 are pure execution: implement what every real systems language
needs. Phase 3 is the differentiation: MLIR integration is a multi-year research
investment that pays off when AI infrastructure written in C++/CUDA is the
bottleneck and you have a better tool.

Build the foundation right. Then build the thing nobody else has.

---

## Tracking

Phase 1 and Phase 2 issues are tracked in this repository's GitHub issue tracker
under the `strategic-direction` milestone. Phase 3 and Phase 4 issues will be
opened as Phase 2 work matures.

See also:
- [`docs/roadmap.md`](roadmap.md) — earlier compiler roadmap
- [`docs/NEXT_STEPS.md`](NEXT_STEPS.md) — current implementation queue
- [`docs/language-spec.md`](language-spec.md) — current implemented surface
- [`docs/diva-roadmap.md`](diva-roadmap.md) — AST/IR/codegen coverage matrix

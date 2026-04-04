# Source language policy

This repository is **Diva-first**: all compiler, standard library, examples, and package manifests that define code are **`.diva`** files (manifests use **`package.diva`**).

## What is allowed in-tree

| Kind | Role |
|------|------|
| **`.diva`** | Language source — the only programming language used for Diva itself. |
| **`package.diva`** | Package metadata (not a separate “mod language”). |
| **LLVM IR** (`runtime/runtime.ll`) | Hosted runtime implementation for linking with seed-generated code — not C source; compiled with `clang -c` at install unless `NO_CLANG=1` + prebuilt `bootstrap/runtime-linux-amd64.o`. |
| **Shell** (`scripts/`, `tests/run.sh`) | Install, CI, and verification — no compiler logic. |
| **Data / config** | `.json` (e.g. editor snippets), `.md` docs, etc. |

## What is explicitly not tracked

- **C/C++ sources** (`.c`, `.h`, `.cpp`, …) — blocked by `scripts/verify-no-c-sources.sh`.
- **Legacy `.mod`** manifests — blocked by the same script.

## Bootstrap and “other languages”

- **`bootstrap/diva-linux-amd64`** is a **pinned binary** (the old implementation, not source here). It is the **trust root** until a Diva-built compiler can fully replace it for `diva build` / `diva run`.
- **Self-sustainability** means: you can develop and run the **entire Diva toolchain from `.diva` sources** using that seed plus the LLVM IR runtime; you do **not** need another language’s *source tree* inside this repo.

## Host tools (outside the language definition)

Installing and linking still use normal Unix tools: **`clang`** (optional) to compile `runtime.ll`, **`cc`** as linker driver for produced executables, **`as`/`ld`** where the native backend invokes them. Those are **tools**, not alternate language sources for Diva.

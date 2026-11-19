# Whole-program inlining (Issue #116)

Diva performs conservative IR-level inlining before the existing constant-folding /
dead-code pipeline. The pass lives in `compiler/src/ir_opt.diva` (`il_*` helpers,
called from `optimize_module`) and runs on every `build`/`run` by default.

## Eligibility

A callee is inlined into a call site only when all of these hold:

- the callee is a compiled function in the current module (not an `extern`);
- it has exactly one basic block;
- it contains no `ir_call` (leaf) and no branches, phis, traps, or synthetic ops;
- its only terminator is a final `ir_ret` / `ir_ret_void`;
- the block has at most 24 instructions;
- the call is not a self/recursive call (`caller != callee`), the callee is not
  `main`/`kmain`, and the argument count matches the parameter count.

A small function with zero call sites is left alone (no blanket function deletion).

## Transformation

For each eligible call site:

1. Fresh vregs are allocated above `opt_func_max(caller)` so the caller's frame
   and codegen stack-slot numbering stay unique.
2. Every `ir_param` slot in the callee gets a fresh slot initialized with an
   `ir_copy` from the corresponding caller argument vreg. The copy preserves
   pass-by-value even if the callee assigns to its own parameters.
3. Callee instructions are cloned, remapping result and operand vregs (including
   call-argument vectors, `ir_text_slice`/`ir_atomic_cas` extra operands, loads,
   stores, and global ops). Literal payloads, string/global indices, and branch
   labels are never treated as vregs.
4. The final `ir_ret` becomes an `ir_copy` into the original call-result vreg;
   `ir_ret_void` is dropped. The `ir_call` itself disappears.
5. After a bounded number of rounds (up to 6), callees that were actually
  inlined and now have no remaining callers are pruned from the module. Function
  indices in the module alias table are rewritten to match. Entry points and
  never-inlined functions remain.

Inlining runs before `opt_module_pass`, so the limit for the fold/DCE scratch
buffers is recomputed from the inlined module.

## Driver flags

```
diva opt [--no-opt] [--no-inline] <file.diva>
diva build [--no-inline] <file.diva> [<out>]
diva run [--no-inline] <file.diva>
```

`diva opt <file>` therefore shows the inlined IR by default: small callees are
gone and their bodies appear inline at the call sites. `--no-inline` keeps the
old call-based IR while leaving the other optimizations enabled.

## Verification

```
bash tests/lto.sh         # IR shape + runtime equivalence with/without inlining
sh tests/opt.sh           # existing optimizer gate
DIVA_TEST_FAST=1 timeout 1500 bash tests/run.sh
```

`tests/lto.sh` accepts `DIVA_PURE_DRIVER=/path/to/diva` to reuse a built driver.

## Deferred

- Profile-guided optimization / hot-cold splitting and a call-frequency cost
  model (no profiling data is collected yet).
- Cross-module (link-time) inlining: this pass is whole-*module* only.
- Inlining functions with multiple blocks, phis, or early returns.
- Inlining budget tuning beyond the fixed 24-instruction threshold, and
  deferred decisions based on register pressure or code size.

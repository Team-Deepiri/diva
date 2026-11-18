# IR control-flow graph analysis (Issue #136)

`compiler/src/cfg.diva` builds a control-flow graph from the linear Diva IR
produced by `build_ir`. `diva analyze <file.diva>` runs it after lexing,
parsing, semantic checks, and IR construction.

## Graph construction

The IR opcodes are `ir_br()` (unconditional), `ir_br_cond()` (true/false
targets in `a`/`b`), `ir_ret()`, `ir_ret_void()`, and `ir_trap()`. Each IR
instruction becomes one CFG node. Instructions are linearized in function
block order; successors are:

- `ir_br`: the single label target in operand `a`.
- `ir_br_cond`: both label targets in operands `a` and `b`.
- `ir_ret`, `ir_ret_void`, `ir_trap`: no successors.
- all other opcodes: the next linear instruction, when one exists.

Block labels are resolved to the first instruction of the block carrying that
label. A branch to a label with no block is a hard error.

Basic blocks are derived from the instruction graph. Leaders are node 0, every
branch target, and every instruction immediately following a terminator.
Blocks are maximal runs between leaders. CFG edges are emitted from a block to
the block containing each instruction-level successor; edges are counted with
multiplicity, so a conditional branch with two distinct successors contributes
two edges and a loop backedge is included.

Reachability is a worklist traversal from node 0. Unreachable instructions that
are not branch targets produce `warn: <function>: unreachable instruction <n>
(<opcode>) has no label target` diagnostics. The driver still exits zero for
warnings. Undefined labels produce `cfg: error: undefined label <n> at
instruction <m>` at the function's source location; any such error makes
`diva analyze` exit non-zero.

## Output

One summary line per function:

```text
function <name>: blocks=<n> edges=<n> unreachable=<n>
```

Warnings are written to stderr; summaries are written to stdout.

Well-formed Diva source never generates a branch to an undefined label, so the
error path is exercised with a synthetic IR probe:

```text
diva analyze --selftest-undefined-label <file.diva>
```

The probe uses the supplied file for the diagnostic location and emits a
single `ir_br` to label 99. It is only a test hook; normal analysis takes just
the source path.

## Verification

`tests/cfg.sh` covers if/else, while loops, match expressions, nested
control flow, unreachable-after-return warnings, and the undefined-label
error:

```text
sh tests/cfg.sh
```

No tokens or IR opcodes were added. The shared CI workflow, language spec, and
`tests/run.sh` are unchanged; `tests/cfg.sh` is a standalone gate.

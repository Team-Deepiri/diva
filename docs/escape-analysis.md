# Escape analysis (Issue #101)

`compiler/src/escape.diva` is a report-only analysis over the Diva IR produced
by `build_ir`. It classifies every `ir_addr_of` result (the address of a stack
slot taken with `&x`) as `Conflict` (escaping) or `Local` (stack-confined).

```text
diva analyze --escape <file.diva>
```

The existing `diva analyze <file.diva>` control-flow report is unchanged.

## Classification

For each function the pass builds two relations between virtual registers:

- aliases: `ir_store`, `ir_load`, `ir_copy`, `ir_phi`, and `ir_array_store`
  connect a slot and a value, so addresses copied through locals keep their
  provenance;
- origins: an `ir_addr_of` result is connected to the slot it addresses.

Address provenance and heap provenance (`ir_alloc` results) are propagated to a
fixed point first, then escape seeds are applied:

- `ir_global_store`: the stored value escapes.
- `ir_ptr_store`: an address used as the stored value escapes; if the
  destination is `ir_alloc`-backed, the pass reports it as a heap escape.
- `ir_atomic_store` / `ir_array_store` of an address and `ir_ret` of an address
  are treated as escapes (conservative).
- `ir_call`: all pointer arguments escape unless the callee is a **known leaf**.
  A known leaf is a function in the module whose IR contains no `ir_call`,
  `ir_global_store`, `ir_ptr_store`, `ir_addr_of`, or `ir_alloc`. Externs are
  never known leaves. Calls by callee *name* are matched because declaration
  and call-site tokens may differ.

Escape status is then propagated back through aliases and origins. This covers
indirect leaks (`p = &x; g = p;`) and struct fields: field stores are `ir_store`
into a slot derived from the struct base, so an escaped struct base makes an
address written into its field escape as well. IR does not carry struct widths,
so field slots are inferred as non-`ir_alloca` store destinations within 16
slots of an escaped base; that heuristic can over-approximate. Only the escape
bit crosses an origin link; the slot itself is not treated as an address value.

This is deliberately conservative: false positives are acceptable in a
foundation pass, false negatives are not.

## Output

One summary line per function on stdout:

```text
function <name>: escaping=<n> local=<n>
```

One count is emitted per `ir_addr_of` instruction in the function; functions
without address-taking have `escaping=0 local=0`.

An obvious escape produces a non-fatal diagnostic on stderr:

```text
warn: value escapes through global.store
warn: value escapes through ptr.store
```

Warnings never change the exit status; no source location is attached because
the classification is performed on IR, after lowering.

## Allocation policy

No codegen or allocation decision is changed. Diva already allocates locals on
the stack by default (`ir_alloca`); `ir_alloc` is used for heap-backed values.
The counts are exposed so future work can decide about heap promotion or
lifetime extension; this pass only reports.

## Verification

`tests/escape.sh` is a standalone gate (like `tests/cfg.sh`):

```text
sh tests/escape.sh
```

It covers a global store with a confined contrast case, leaf vs non-leaf call
arguments, returned addresses, struct field propagation, and an indirect leak.
No tokens or IR opcodes were added; the CI workflow, language spec, and
`tests/run.sh` are unchanged.

# Typed MIR (Issue #100)

The typed MIR layer is a verification/view layer over the existing
backend-neutral IR in `compiler/src/ir.diva`. It does not change codegen or the
IR layout.

## SSA note

Diva IR already uses virtual registers in single-assignment form: the builder
allocates each vreg once (`ib_fresh_vreg`) and later passes rewrite instructions
at the same vreg instead of reassigning it. There is therefore **no SSA renaming
pass** here. "SSA-form" in this issue means the existing single-assignment vreg
property; the type layer assigns one type tag per vreg and rejects IR that
violates that property.

## Type tags

Tags are the `ir_ty_*` constants from `ir.diva`: `void`, `int`, `bool`, `str`,
`ptr`, `text`, enum tags (`> text`), plus the fixed high tags `slice` and
`vec4`. Unknown/erased values are represented internally by `-1` and are
refined during inference; the typed dump always shows a concrete tag.

## Inference (`compiler/src/ir_types.diva`)

`ity_infer_func` allocates six vreg-indexed arrays in one memory block:

| array | purpose |
| --- | --- |
| `types` | inferred type tag |
| `strong` | 1 when the tag came from the opcode/registered signature |
| `counts` | number of value definitions seen for the vreg |
| `links` | source vreg for `ir_copy` / `ir_phi` |
| `slot_values` | value type stored into a stack slot |
| `ptr_values` | pointee type reached through `ir_addr_of` / `ir_ptr_store` |

Rules, in order:

1. Value-defining opcodes provide a strong tag: constants, arithmetic (`int`),
   comparisons (`bool`), strings/text, `alloca`/`alloc`/`addr.of`/`param`
   (slot addresses, `ptr`), atomic results, etc.
2. Calls use the registered return type of the callee when it can be resolved
   from the module (by name token or alias map). Extern calls have no registered
   return type and default to a weak `void`.
3. `global.load` uses `global_type` from the module.
4. `store`/`ptr.store` record the value type of a slot/pointer; `load` and
   `ptr.load` reuse it. Otherwise loads default to a weak `int` (the IR's
   natural word type).
5. `copy`/`phi` inherit their source type (bounded propagation rounds).
6. Any remaining untyped vreg defaults to a weak `int`.

Instructions such as `store`, `ret`, `br`, `trap` and `fence` reuse an existing
vreg as an operand; their `result` field is **not** counted as a definition.
That avoids false conflicts such as `v0 = const 41; v0 = ret v0`.

## Verification

`ity_verify_module(m, src, toks)` is the checking entry point. It returns
non-zero when a vreg has two strong definitions with different tags and prints:

```
sema: MIR type error: v0 defined as int but also as ptr by addr.of
```

The driver calls it after every `build_ir` and before optimization/codegen
(`verify_ir_module` in `compiler/src/main.diva`). Genuine type errors from source
are still caught earlier by `sema`; this layer protects hand-built/optimized IR.

Opcodes outside the known IR opcode range and allocation failures are reported
once as `warn: ir_types: ...` and verification continues with partial
information. Use-based int/pointer ambiguity is intentionally not a hard error:
the IR erases source types (slot addresses are integers, pointer arithmetic uses
`add`), so the frontend remains authoritative for source-level type checking.
Adding stronger use constraints is deferred until the IR carries explicit
operand types.

`diva ir --selftest-type-conflict` builds a synthetic two-definition module and
runs the checker; it exits non-zero with the error above when detection works.

## Dump

`diva ir <file>` output is unchanged. `diva ir --types <file>` adds `: <tag>`
after each result vreg, for example:

```
v0: int = const 41
v1: int = call forty_one argc=0
v0: ptr = alloca
v3: int = load v0, v0
```

The typed variants (`dump_*_t`) take one type block per function from
`ity_infer_module`; the original dump functions delegate with `-1`.

## Tests

`sh tests/mirtypes.sh` (or `DIVA_PURE_DRIVER=... sh tests/mirtypes.sh`) checks
typed output, unchanged plain output, the conflict selftest, and a normal
build+run. Cases live in `tests/cases/mirtypes/`.

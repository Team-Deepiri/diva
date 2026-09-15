# Negative cases (`tests/cases/fail`)

Locked failure suite for Issue [#61](https://github.com/Team-Deepiri/diva/issues/61).
Machine-readable list: `tests/negative.list`. Runner: `tests/run-negative.sh`
(also invoked from `tests/run-native-broad.sh`).

## Active (native)

| Case | Expected needle / behavior | Surface |
|------|----------------------------|---------|
| `duplicate_decl.diva` | `duplicate declaration of 'x' in the same scope` | sema |
| `unknown_ident.diva` | `unknown_ident.diva:2:` (+ `unknown identifier`) | sema + span |
| `wrong_arity.diva` | `wrong number of arguments for 'add'` | sema + span |
| `parse_bad_params.diva` | `parse_bad_params.diva:1:` | parse + span |
| `missing_trait_method.diva` | `missing trait method` | sema |
| `duplicate_func.diva` | `duplicate function 'foo'` | sema |
| `self_outside_method.diva` | `unknown identifier 'self'` | sema |
| `duplicate_import_main.diva` (+ a/b) | `duplicate function 'clash'` | multi-file sema |
| `unknown_package_dep/` | `unknown package dependency` | loader |
| `array_oob_runtime.diva` | build OK; run exits non-zero | runtime trap |

## Deferred

| Case | Why deferred |
|------|----------------|
| `package_mismatch_main.diva` | Package name mismatch not diagnosed yet (builds today) |
| `reserved_name.diva` | Historical; `double` is not reserved — replaced by `duplicate_func` / `self_outside_method` |
| Type-mismatch assign/return | Needs fuller type checker (#53 follow-up) |

## Seed vs native

All **active** rows are exercised on the **native pure-ELF** driver (`DIVA_NO_EXTERNAL=1`).
`tests/run.sh` re-checks the same needles via the installed driver after install.
Seed-only negatives that diverge from native are not listed here.

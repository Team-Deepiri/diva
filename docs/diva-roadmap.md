# Diva language surface: AST → IR → codegen checklist

This document maps AST node kinds ([compiler/src/ast.diva](compiler/src/ast.diva)) to native pipeline support: **parse**, **IR** ([compiler/src/ir_builder.diva](compiler/src/ir_builder.diva)), **x86** ([compiler/src/codegen_x86.diva](compiler/src/codegen_x86.diva)). Status: **yes** (implemented), **partial** (subset or stubs), **no** (skipped / const 0 / seed only).

| Construct | Parse | IR / lowering | Codegen | Notes |
|-----------|-------|---------------|---------|--------|
| `nd_file` | yes | yes | yes | |
| `nd_import` | yes | skip | n/a | Imports ignored in native IR; multi-file is seed |
| `nd_package_decl` | yes | skip | n/a | |
| `nd_func` | yes | yes | yes | |
| `nd_extern_func` | yes | yes | yes | Calls → `di_runtime_*` |
| `nd_param` | yes | yes | yes | |
| `nd_var_decl` | yes | partial | partial | Scalars + fixed `int[]` with array literal init |
| `nd_if` | yes | yes | yes | |
| `nd_while` | yes | yes | yes | |
| `nd_return` | yes | yes | yes | |
| `nd_block` | yes | yes | yes | |
| `nd_call` | yes | yes | yes | |
| `nd_binop` / `nd_unary` | yes | yes | yes | |
| `nd_int_lit` / `nd_bool_lit` / `nd_str_lit` | yes | yes | yes | |
| `nd_ident` | yes | partial | partial | Locals + params; globals → stub |
| `nd_assign` | yes | partial | partial | Ident and `nd_index` (const index) |
| `nd_field` | yes | no | no | |
| `nd_index` | yes | partial | partial | Constant index into stack `int[]` |
| `nd_class` / `nd_trait` / `nd_impl` | yes | no | no | Seed / future IR |
| `nd_type_name` / `nd_type_array` | yes | partial | partial | Arrays for locals only |
| `nd_array_lit` | yes | partial | partial | Only as `int[]` initializer |
| `nd_flux` | yes | no | no | |
| `nd_range` | yes | no | no | |
| `nd_method_call` | yes | yes | yes | Lowers to free fn `method(recv, args...)` |
| `nd_obj_lit` / `nd_field_init` | yes | no | no | |
| `nd_expr_stmt` | yes | yes | yes | |
| `nd_generic_call` | yes | yes | yes | Type args kept in AST; lowers like `nd_call` |

**Examples / tests:** Full `examples/` and `tests/cases` rely on the **seed** compiler for packages, traits, kernels, `diva check`, etc. Native `diva build` / `diva run` apply to single-file programs that fit the supported subset (see `compiler-version` output).

**Bootstrap:** Stage 0 = seed builds compiler; stage 1+ = Diva-built driver compiles `compiler/` (pure ELF by default; optional **`cc` + `DI_RUNTIME_O`** only with **`DIVA_ALLOW_HOSTED_LINK=1`**).

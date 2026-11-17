# Ownership and move checking (Issue #88)

Phase 1 value types (Issue #87) made `struct` values live in local storage and
copied their fields on assignment. Issue #88 adds a semantic ownership rule on
top of that representation: a `struct` local is a **value with a single owner**.
Once it is transferred, the old binding is dead until it is re-initialised.

This is a sema-level foundation. Code generation is unchanged and still copies
the underlying fields; the checker exists to make Diva source reject
use-after-move regardless of how the backend materialises the value.

## Rules implemented

1. **Moving.** Assigning or passing a `struct` local transfers ownership:
   - `let q: Point = p`
   - `let q = p`
   - `q = p`
   - `f(p)` / `obj.method(p)` argument
   - `Point { x: p, y: q }` field initialiser
   - `[p, q]` array element
2. **Use after move.** Reading a moved binding is an error. This includes a
   plain identifier read, field access (`p.x`), and moving it a second time.
   The diagnostic is:
   ```
   sema: use of moved value 'p'
   ```
3. **Re-assignment revives.** `p = Point { ... }` re-initialises `p`, and later
   reads are legal again. This also applies when the right-hand side itself is
   a move (`q = p`), because the target is written after the source is read.
4. **Copy types stay copyable.** `int`, `bool`, `str`, and `text` are never
   tracked. Assigning them does not invalidate the source.
5. **Scopes and shadowing.** Ownership state is stored per local binding and is
   truncated when a lexical scope exits. A shadowing declaration starts
   unmoved; lookups use the innermost declaration.

Struct field reads (`let q = Point { x: p.x, y: p.y }`) and field writes
(`p.x = 1`) do **not** move `p`; only whole-value transfers do. This keeps the
checker conservative and avoids partial-move complexity.

## Not covered (deferred)

The checker is intentionally narrow. The following are explicitly out of scope
for this foundation:

- **Globals.** Only locals (including function parameters) carry ownership
  state.
- **Returns.** Returning a struct local is treated as a read; it is not
  modelled as a move out of the function.
- **Method receivers.** `obj.method()` reads the receiver; receivers are not
  moved even when the receiver is a struct.
- **Partial moves.** Moving a field (`let x = p.x`) is not tracked; only whole
  struct values participate.
- **Arrays, slices, and enums.** These types are not moved or tracked. Struct
  values stored into an array literal are moved out of their source local, but
  later array element reads are not checked for ownership.
- **Control-flow sensitivity.** Ownership state is updated in source order. A
  move inside an `if` branch remains visible after the branch even when the
  branch is not taken (conservative false positive); moves on different paths
  are not joined. Loops are not re-analysed for later iterations.
- **Borrow checking.** References (`&T` / `&mut T`) may still point at a moved
  local; there is no borrow checker, aliasing analysis, or drop insertion.
- **Copy/drop traits.** There is no user-defined `Copy`/`Drop`; the Copy set is
  fixed to `int`, `bool`, `str`, and `text`.
- **Destructors / cleanup.** Moving does not free or zero storage; the backend
  continues to copy fields as before.

Removing any of these limits should be a separate, individually tested change.

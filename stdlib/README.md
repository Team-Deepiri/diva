# Di Standard Library

The standard library starts tiny on purpose.

Early surface area:

- printing
- basic math helpers
- memory/runtime hooks

The first implementations may be backed by C runtime shims before moving into native `Di` code.

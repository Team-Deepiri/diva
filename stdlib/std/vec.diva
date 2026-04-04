// Growable int vector and string builder backed by the C runtime (opaque handles as int).
// See docs/selfhost-bootstrap.md.

extern func int_vec_new(): int
extern func int_vec_push(handle: int, value: int): int
extern func int_vec_len(handle: int): int
extern func int_vec_get(handle: int, index: int): int
extern func int_vec_free(handle: int): void

extern func str_builder_new(): int
extern func str_builder_append(handle: int, chunk: str): void
extern func str_builder_len(handle: int): int
extern func str_builder_to_str(handle: int): str
extern func str_builder_free(handle: int): void

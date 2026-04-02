// Hosted-process hooks: runtime/runtime.ll (linked as .o) — argv, file input, string scanning.

extern func host_argc(): int
extern func host_argv(index: int): str

extern func file_size(path: str): int
extern func read_file(path: str): str

extern func str_len(s: str): int
extern func str_byte(s: str, index: int): int

extern func str_slice(s: str, start: int, len: int): str
extern func str_eq(a: str, b: str): int
extern func int_to_str(n: int): str

// Process / bootstrap: libc wrappers (runtime/runtime.ll or merged runtime object).
extern func host_getenv(name: str): str
extern func host_system(cmd: str): int

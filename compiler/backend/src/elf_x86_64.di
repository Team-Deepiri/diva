// Linux x86_64 ELF64 relocatable object emitter — skeleton constants and hooks.
// Primary path: emit ET_REL .o bytes from MIR; fallback lane: assembler text + `as` (no clang).

func elf_magic_0(): int {
    return 127
}

func elf_class_64(): int {
    return 2
}

func e_machine_x86_64(): int {
    return 62
}

func et_rel(): int {
    return 1
}

func backend_elf_stub_version(): int {
    return 1
}

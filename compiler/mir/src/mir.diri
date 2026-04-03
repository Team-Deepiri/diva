// Backend-neutral MIR/LIR scaffolding (expanded as the Di compiler grows).
// Lowering targets: Di MIR text dump, then ELF/x86_64 in ../backend.

class MirBlock {
    var id :: int
}

class MirFn {
    var name :: str
    var entry_block :: int
}

func mir_layer_version(): int {
    return 1
}

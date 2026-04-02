// Bootstrap driver: forwards CLI to the seed compiler (DI_BOOTSTRAP or bootstrap/di-linux-amd64).
// Full self-hosting replaces this with the compiler implemented in Di (see docs/selfhost-bootstrap.md).
import "std/host.di"
import "std/vec.di"

func bootstrap_path(): str {
    var p = host_getenv("DI_BOOTSTRAP")
    if str_len(p) > 0 {
        return p
    }
    return "bootstrap/di-linux-amd64"
}

func main(): int {
    var b = str_builder_new()
    if b == 0 {
        return 1
    }
    str_builder_append(b, bootstrap_path())
    var i = 1
    while i < host_argc() {
        str_builder_append(b, " ")
        str_builder_append(b, host_argv(i))
        i = i + 1
    }
    var cmd = str_builder_to_str(b)
    str_builder_free(b)
    // libc system() returns wait status: exit code c is typically (c << 8) on Linux.
    var r = host_system(cmd)
    if r < 0 {
        return 1
    }
    if r == 0 {
        return 0
    }
    if r < 256 {
        return r
    }
    return r / 256
}

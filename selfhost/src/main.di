import "lexer.di"
import "std/host.di"

extern func print_int(x: int): void

// Tokenize argv[1]; compare to reference: di build <same-file> --tokens
func main(): int {
    if host_argc() < 2 {
        print_int(0)
        return 1
    }

    var path = host_argv(1)
    var text = read_file(path)
    run_lexer_on_source(text)
    return 0
}

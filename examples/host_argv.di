import "std/host.di"

extern func print_int(x: int): void

func main(): int {
    print_int(host_argc())
    return 0
}

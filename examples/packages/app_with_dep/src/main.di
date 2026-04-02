import "pkg/math_lib"

extern func print_int(x: int): void

func main(): int {
    print_int(triple(14))
    return 0
}

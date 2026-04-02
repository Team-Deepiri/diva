import "math.di"

extern func print_int(x: int): void

func main(): int {
    var result = twice(21)
    print_int(result)
    return 0
}

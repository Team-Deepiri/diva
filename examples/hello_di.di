extern func print_str(x: str): void
extern func print_int(x: int): void

func main(): int {
    var value = 42
    print_str("hello from Di")
    print_int(value)
    return 0
}

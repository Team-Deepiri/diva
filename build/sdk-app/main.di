extern func print_str(x: str): void;
extern func print_int(x: int): void;

func square(x: int): int {
    return x * x;
}

func main(): int {
    print_str("hello from diri");
    print_int(square(12));
    return 0;
}

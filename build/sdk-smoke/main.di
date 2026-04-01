extern func print_str(x: str): void;
extern func print_int(x: int): void;

func banner(title: str): int {
    print_str(title);
    return 0;
}

func main(): int {
    let i: int = 0;
    let total: int = 0;

    banner("hello from diri");

    while i < 5 {
        total = total + i;
        i = i + 1;
    }

    print_int(total);
    return 0;
}

extern func print_int(x: int): void;

func main(): int {
    let i: int = 0;
    let total: int = 0;

    while i < 5 {
        total = total + i;
        i = i + 1;
    }

    print_int(total);
    return 0;
}

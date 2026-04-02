extern func print_int(x: int): void

func main(): int {
    let x: int = 5

    if x > 0 {
        let x: int = 99
        print_int(x)
    }

    print_int(x)
    return 0
}

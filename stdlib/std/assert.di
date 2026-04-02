extern func print_str(x: str): void
extern func abort(): void

func assert_true(condition: bool, message: str): int {
    if condition {
        return 1
    }
    print_str(message)
    abort()
    return 0
}

func assert_eq_int(left: int, right: int, message: str): int {
    if left == right {
        return 1
    }
    print_str(message)
    abort()
    return 0
}

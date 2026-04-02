import "std/math.di"
import "std/logic.di"
import "std/range.di"

extern func print_int(x: int): void

func main(): int {
    print_int(abs(0 - 12))
    print_int(clamp(42, 0, 10))
    print_int(sum_range(0, 5))
    print_int(count_range(3, 8))
    print_int(bool_to_int(contains_range(10, 15, 12)))
    print_int(bool_to_int(any(false, true)))

    return 0
}

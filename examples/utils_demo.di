import "std/io.di"
import "std/int.di"
import "std/assert.di"

func main(): int {
    print_int(sign(0 - 9))
    print_int(gcd(54, 24))
    print_bool(is_even(8))
    print_bool(is_odd(7))
    print_hex(stdout("util"))
    print_int(assert_true(true, "should not fail"))
    print_int(assert_eq_int(4, 4, "int equality failed"))
    return 0
}

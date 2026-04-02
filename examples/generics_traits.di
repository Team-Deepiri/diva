extern func print_int(x: int): void

class Counter {
    value: int

    func measure(): int {
        return self.value
    }
}

trait Measure {
    func measure(): int
}

impl Measure for Counter

func identity[T](x: T): T {
    return x
}

func main(): int {
    var counter :: Counter = Counter { value: identity[int](7) }
    print_int(counter.measure())
    return 0
}

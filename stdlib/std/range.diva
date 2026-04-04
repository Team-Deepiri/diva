func sum_range(start: int, end: int): int {
    var total = 0

    flux value in start..end {
        total = total + value
    }

    return total
}

func count_range(start: int, end: int): int {
    var total = 0

    flux value in start..end {
        total = total + 1
    }

    return total
}

func contains_range(start: int, end: int, needle: int): bool {
    flux value in start..end {
        if value == needle {
            return true
        }
    }

    return false
}
